CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
GSTIN_LENGTH = 15


def check_digit(first_fourteen: str) -> str:
    total = 0
    for index, char in enumerate(first_fourteen.upper()):
        value = CHARS.index(char)
        factor = 1 if index % 2 == 0 else 2
        product = value * factor
        total += product // 36 + product % 36
    return CHARS[(36 - (total % 36)) % 36]


def validate(value: str) -> bool:
    text = str(value).strip().upper()
    if len(text) != GSTIN_LENGTH:
        return False
    if any(char not in CHARS for char in text):
        return False
    return check_digit(text[:14]) == text[14]


def generate(state_code: str, pan: str, entity: str = "1") -> str:
    first_fourteen = f"{state_code}{pan}{entity}Z"
    return first_fourteen + check_digit(first_fourteen)


def checksum_char(first_fourteen: str) -> str:
    return check_digit(first_fourteen)


def is_valid_gstin(value) -> bool:
    return validate(value)
