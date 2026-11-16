import io
import logging
import os
import re
import zipfile

import pandas as pd
from django.conf import settings
from django.core.files.uploadedfile import UploadedFile
from openpyxl import load_workbook

from common.text import is_empty

logger = logging.getLogger(__name__)

ALLOWED_EXTENSIONS = {".csv", ".xlsx", ".xlsm"}
CONTROL_CHARS_RE = re.compile(r"[\x00-\x1f\x7f]")


class FileParseError(ValueError):
    pass


def _max_bytes():
    return int(getattr(settings, "SALUS_MAX_UPLOAD_BYTES", 15 * 1024 * 1024))


def _max_rows():
    return int(getattr(settings, "SALUS_MAX_UPLOAD_ROWS", 50000))


def _max_columns():
    return int(getattr(settings, "SALUS_MAX_UPLOAD_COLUMNS", 200))


def _max_xlsx_uncompressed():
    return int(getattr(settings, "SALUS_MAX_XLSX_UNCOMPRESSED_BYTES", 100 * 1024 * 1024))


def _max_xlsx_entries():
    return int(getattr(settings, "SALUS_MAX_XLSX_ENTRIES", 5000))


def _safe_filename(raw_name) -> str:
    name = str(raw_name or "upload").replace("\\", "/")
    name = os.path.basename(name)
    name = CONTROL_CHARS_RE.sub("", name).strip()
    return name[:255] or "upload"


def _extension(filename: str) -> str:
    return ("." + filename.rsplit(".", 1)[-1].lower()) if "." in filename else ""


def _guard_xlsx(data: bytes):
    if not zipfile.is_zipfile(io.BytesIO(data)):
        raise FileParseError("The file is not a valid XLSX workbook.")
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            entries = archive.infolist()
            if len(entries) > _max_xlsx_entries():
                raise FileParseError("The workbook contains too many parts.")
            total = sum(entry.file_size for entry in entries)
            if total > _max_xlsx_uncompressed():
                raise FileParseError("The workbook is too large when uncompressed.")
    except zipfile.BadZipFile as exc:
        raise FileParseError("The file is not a valid XLSX workbook.") from exc


def _read_csv(buffer):
    try:
        return pd.read_csv(
            buffer,
            dtype=str,
            keep_default_na=False,
            encoding="utf-8-sig",
            nrows=_max_rows() + 1,
        )
    except UnicodeDecodeError:
        buffer.seek(0)
        return pd.read_csv(
            buffer,
            dtype=str,
            keep_default_na=False,
            encoding="cp1252",
            nrows=_max_rows() + 1,
        )


def _read_excel(buffer):
    return pd.read_excel(
        buffer, dtype=str, keep_default_na=False, engine="openpyxl"
    )


def _read_bytes(data: bytes, extension: str):
    buffer = io.BytesIO(data)
    if extension == ".csv":
        return _read_csv(buffer)
    _guard_xlsx(data)
    return _read_excel(buffer)


def _read_uploaded(uploaded: UploadedFile):
    filename = _safe_filename(uploaded.name)
    extension = _extension(filename)
    if extension not in ALLOWED_EXTENSIONS:
        raise FileParseError("Only CSV and XLSX files are supported.")

    limit = _max_bytes()
    declared = getattr(uploaded, "size", None)
    if declared and declared > limit:
        raise FileParseError(f"Files above {limit // (1024 * 1024)} MB are not supported.")
    data = uploaded.read(limit + 1)
    uploaded.seek(0)
    if len(data) > limit:
        raise FileParseError(f"Files above {limit // (1024 * 1024)} MB are not supported.")
    if not data:
        raise FileParseError("The uploaded file is empty.")

    try:
        df = _read_bytes(data, extension)
    except FileParseError:
        raise
    except Exception as exc:
        logger.warning("Upload parse failed for %s: %s", filename, exc)
        raise FileParseError(
            "Could not parse the file. Check that it is a valid CSV or XLSX file."
        ) from exc
    return _clean_dataframe(df), data, filename


def _clean_columns(df: pd.DataFrame) -> pd.DataFrame:
    seen = {}
    columns = []
    for raw in df.columns:
        name = CONTROL_CHARS_RE.sub("", str(raw)).strip() or "column"
        name = name[:255]
        if name in seen:
            seen[name] += 1
            name = f"{name}_{seen[name]}"[:255]
        else:
            seen[name] = 1
        columns.append(name)
    df.columns = columns
    return df


def _clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    if df is None or len(df.columns) == 0:
        raise FileParseError("No table found in the file.")
    if len(df.columns) > _max_columns():
        raise FileParseError(f"Files above {_max_columns()} columns are not supported.")
    if len(df) > _max_rows():
        raise FileParseError(
            f"Files above {_max_rows()} rows are not supported in this build."
        )

    df = df.fillna("")
    df = _clean_columns(df)
    empty = df.map(is_empty)
    df = df[~empty.all(axis=1)]
    df = df.loc[:, ~df.map(is_empty).all(axis=0)]

    if len(df) == 0:
        raise FileParseError("The file has no data rows.")
    if len(df) > _max_rows():
        raise FileParseError(
            f"Files above {_max_rows()} rows are not supported in this build."
        )
    if len(df.columns) == 0:
        raise FileParseError("The file has no usable columns.")
    return df.reset_index(drop=True)


def parse_uploaded_file(uploaded: UploadedFile):
    """Read a CSV or XLSX upload into a string dataframe.

    The raw bytes are held in memory and never written to the database
    or to permanent storage. Size, row and column limits are enforced
    before any expensive parsing.
    """
    return _read_uploaded(uploaded)


def extract_watermark(data: bytes, filename: str) -> str:
    """Read a weak export watermark from XLSX document properties.

    This signal is easy to strip, so it is never used as the only
    evidence. A CSV conversion removes it, which the demo shows.
    """
    filename = _safe_filename(filename)
    if _extension(filename) not in {".xlsx", ".xlsm"}:
        return ""
    try:
        _guard_xlsx(data)
        workbook = load_workbook(io.BytesIO(data), read_only=True)
        properties = workbook.properties
        text = " ".join(
            [
                str(properties.description or ""),
                str(properties.keywords or ""),
                str(properties.title or ""),
            ]
        )
        workbook.close()
    except Exception:
        return ""
    match = re.search(r"SALUS-WM-[A-Z0-9\-]+", text)
    return match.group(0) if match else ""


def parse_dataframe_bytes(data: bytes, filename: str):
    filename = _safe_filename(filename)
    extension = _extension(filename)
    if extension not in ALLOWED_EXTENSIONS:
        raise FileParseError("Only CSV and XLSX files are supported.")
    if len(data) > _max_bytes():
        raise FileParseError(f"Files above {_max_bytes() // (1024 * 1024)} MB are not supported.")
    try:
        df = _read_bytes(data, extension)
    except FileParseError:
        raise
    except Exception as exc:
        logger.warning("Dataframe parse failed for %s: %s", filename, exc)
        raise FileParseError(
            "Could not parse the file. Check that it is a valid CSV or XLSX file."
        ) from exc
    return _clean_dataframe(df)


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    return _clean_dataframe(df)
