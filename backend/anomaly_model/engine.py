import pickle

import numpy as np
from django.utils import timezone
from sklearn.neural_network import MLPRegressor

from anomaly_model.models import BehaviourModel
from common.timeutil import destination_risk, ist_parts
from events.models import Event

ACTIONS = ["FILE_VIEWED", "FILE_DOWNLOADED", "FILE_COPIED", "EXTERNAL_SHARE"]
FEATURE_NAMES = [
    "hour_sin",
    "hour_cos",
    "is_weekend",
    "viewed",
    "downloaded",
    "copied",
    "shared",
    "log_volume",
    "destination_trust",
    "file_sensitivity",
]
MODEL_VERSION = "ae-v1"


def event_features(event, sensitivity=0):
    _local, hour, weekday = ist_parts(event.timestamp)
    angle = 2 * np.pi * hour / 24.0
    rows = event.evidence.get("rows") if isinstance(event.evidence, dict) else None
    try:
        volume = float(rows or 0)
    except (TypeError, ValueError):
        volume = 0.0
    if volume <= 0 and isinstance(event.evidence, dict):
        bytes_value = event.evidence.get("bytes") or 0
        try:
            volume = float(bytes_value) / 1000.0
        except (TypeError, ValueError):
            volume = 0.0
    features = [
        np.sin(angle),
        np.cos(angle),
        1.0 if weekday >= 5 else 0.0,
        1.0 if event.action == "FILE_VIEWED" else 0.0,
        1.0 if event.action == "FILE_DOWNLOADED" else 0.0,
        1.0 if event.action == "FILE_COPIED" else 0.0,
        1.0 if event.action == "EXTERNAL_SHARE" else 0.0,
        np.log1p(max(volume, 0.0)),
        destination_risk(event.destination) / 100.0,
        (sensitivity or 0) / 100.0,
    ]
    return np.array(features, dtype=float)


def _asset_sensitivity_map(organization):
    from assets.models import Asset

    return dict(
        Asset.objects.filter(organization=organization).values_list("public_id", "sensitivity_score")
    )


def train_models(organization, min_events=25):
    sensitivity = _asset_sensitivity_map(organization)
    results = []
    for actor_id in (
        Event.objects.filter(organization=organization)
        .exclude(action="SUSPECT_UPLOAD")
        .values_list("actor_id", flat=True)
        .distinct()
    ):
        events = list(
            Event.objects.filter(organization=organization, actor_id=actor_id)
            .exclude(action="SUSPECT_UPLOAD")
            .order_by("timestamp")
        )
        if len(events) < min_events:
            continue
        matrix = np.array(
            [event_features(event, sensitivity.get(event.asset_id, 0)) for event in events]
        )
        model = MLPRegressor(
            hidden_layer_sizes=(8, 4),
            activation="relu",
            solver="adam",
            max_iter=1500,
            random_state=42,
            learning_rate_init=0.01,
        )
        model.fit(matrix, matrix)
        predictions = model.predict(matrix)
        errors = np.mean((matrix - predictions) ** 2, axis=1)
        baseline = {
            "mean": float(np.mean(errors)),
            "p95": float(np.percentile(errors, 95)),
            "errors": [float(value) for value in errors],
            "features": FEATURE_NAMES,
            "built_at": timezone.now().isoformat(),
        }
        BehaviourModel.objects.filter(
            organization=organization, actor_id=actor_id, version=MODEL_VERSION
        ).delete()
        BehaviourModel.objects.create(
            organization=organization,
            actor_id=actor_id,
            version=MODEL_VERSION,
            model_blob=pickle.dumps(model),
            baseline=baseline,
            sample_count=len(events),
        )
        results.append({"actor_id": actor_id, "samples": len(events)})
    return results


def score_event(organization, event):
    model_row = (
        BehaviourModel.objects.filter(
            organization=organization, actor_id=event.actor_id, version=MODEL_VERSION
        )
        .order_by("-trained_at")
        .first()
    )
    if model_row is None:
        return {
            "score": 50,
            "percentile": 50,
            "top_features": [],
            "basis": "No behaviour baseline exists for this user, so a neutral value was used.",
            "samples": 0,
        }

    model = pickle.loads(bytes(model_row.model_blob))
    sensitivity = _asset_sensitivity_map(organization).get(event.asset_id, 0)
    vector = event_features(event, sensitivity)
    prediction = model.predict([vector])[0]
    squared = (vector - prediction) ** 2
    error = float(np.mean(squared))

    baseline = model_row.baseline or {}
    p95 = float(baseline.get("p95") or baseline.get("mean") or 1e-9)
    errors = baseline.get("errors") or []
    score = int(round(min(100.0, 100.0 * (error / max(p95, 1e-9)) ** 0.7)))
    percentile = 50
    if errors:
        percentile = int(round(100.0 * sum(1 for value in errors if value <= error) / len(errors)))

    total = float(np.sum(squared)) or 1.0
    order = np.argsort(squared)[::-1][:3]
    top_features = [
        {
            "feature": FEATURE_NAMES[index],
            "contribution": round(float(squared[index] / total), 3),
            "value": round(float(vector[index]), 3),
        }
        for index in order
        if squared[index] > 0
    ]

    return {
        "score": score,
        "percentile": percentile,
        "top_features": top_features,
        "basis": f"Reconstruction error {error:.5f} against a baseline of {model_row.sample_count} events.",
        "samples": model_row.sample_count,
        "error": round(error, 6),
        "baseline_p95": round(p95, 6),
    }
