"""Binary cassava metrics for /metrics and related APIs."""

import json
from pathlib import Path
from typing import Dict, Optional

BASE_DIR = Path(__file__).resolve().parent.parent
METRICS_JSON = BASE_DIR / "models" / "training_metrics.json"
TRAIN_DATA_DIR = BASE_DIR / "data" / "train"
NEW_DATA_DIR = BASE_DIR / "data" / "new_data"

EXPECTED_CLASSES = ("healthy", "bacterial_blight")
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"}
DEFAULT_VALIDATION_ACCURACY = 0.0


def _count_images_in_dir(folder: Path) -> int:
    if not folder.is_dir():
        return 0
    return sum(
        1
        for f in folder.iterdir()
        if f.is_file() and f.suffix.lower() in IMAGE_EXTS
    )


def _counts_under_root(root: Path) -> Dict[str, int]:
    out: Dict[str, int] = {k: 0 for k in EXPECTED_CLASSES}
    if not root.is_dir():
        return out
    for class_name in EXPECTED_CLASSES:
        out[class_name] = _count_images_in_dir(root / class_name)
    return out


def get_class_distribution_counts() -> Dict[str, int]:
    """Counts merged from base train data and saved predicted images."""
    train = _counts_under_root(TRAIN_DATA_DIR)
    new = _counts_under_root(NEW_DATA_DIR)
    return {k: int(train.get(k, 0) + new.get(k, 0)) for k in EXPECTED_CLASSES}


def get_original_dataset_class_counts() -> Dict[str, int]:
    return _counts_under_root(TRAIN_DATA_DIR)


def get_class_distribution_for_metrics() -> Dict[str, int]:
    return get_class_distribution_counts()


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


def get_persisted_confusion_matrix() -> Optional[list[list[int]]]:
    path = Path(METRICS_JSON)
    if not path.is_file():
        return None
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        raw = data.get("confusion_matrix")
        if not isinstance(raw, list):
            return None
        out: list[list[int]] = []
        for row in raw:
            if not isinstance(row, list):
                return None
            out.append([int(v) for v in row])
        return out
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        return None


def humanize_class_name(raw: str) -> str:
    parts = raw.replace("-", "_").split("_")
    return " ".join(p.capitalize() for p in parts if p)