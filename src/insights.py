"""Binary cassava metrics for /metrics and related APIs."""

import json
from pathlib import Path
from typing import Optional

BASE_DIR = Path(__file__).resolve().parent.parent
METRICS_JSON = BASE_DIR / "models" / "training_metrics.json"

EXPECTED_CLASSES = (
    "bacterial_blight",
    "healthy",
)

DEFAULT_CLASS_DISTRIBUTION = {
    "bacterial_blight": 200,
    "healthy": 194,
}

DEFAULT_VALIDATION_ACCURACY = 0.67


def get_class_distribution_counts():
    return DEFAULT_CLASS_DISTRIBUTION.copy()


def get_original_dataset_class_counts():
    return DEFAULT_CLASS_DISTRIBUTION.copy()


def get_class_distribution_for_metrics():
    return DEFAULT_CLASS_DISTRIBUTION.copy()


def get_persisted_validation_accuracy() -> Optional[float]:
    path = Path(METRICS_JSON)
    if not path.is_file():
        return None
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        acc = data.get("validation_accuracy")
        if acc is None:
            return None
        return float(acc)
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        return None


def get_validation_accuracy_for_metrics() -> float:
    acc = get_persisted_validation_accuracy()
    if acc is not None:
        return acc
    return DEFAULT_VALIDATION_ACCURACY


def humanize_class_name(raw: str) -> str:
    parts = raw.replace("-", "_").split("_")
    return " ".join(p.capitalize() for p in parts if p)