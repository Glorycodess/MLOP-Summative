"""Dataset counts and persisted training metrics for /metrics and related APIs."""

import json
import os
from pathlib import Path
from typing import Dict, Optional

METRICS_JSON = os.path.join("models", "training_metrics.json")
ORIGINAL_DATA_DIR = "Notebook/cassava_small"
NEW_DATA_DIR = "data/new_data"

EXPECTED_CLASSES = (
    "bacterial_blight",
    "healthy",
)

DEFAULT_VALIDATION_ACCURACY = 0.67 #initial binary model accuracy

_IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"}


def _count_images_in_dir(folder: Path) -> int:
    if not folder.is_dir():
        return 0
    n = 0
    for f in folder.iterdir():
        if f.is_file() and f.suffix.lower() in _IMAGE_EXTS:
            n += 1
    return n


def _counts_under_root(root: Path) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    if not root.is_dir():
        return counts
    for class_dir in root.iterdir():
        if not class_dir.is_dir():
            continue
        name = class_dir.name
        counts[name] = counts.get(name, 0) + _count_images_in_dir(class_dir)
    return {k: v for k, v in counts.items() if v > 0}


def get_class_distribution_counts() -> Dict[str, int]:
    """Merge image counts from original dataset + uploaded data folders."""
    merged: Dict[str, int] = {}
    for base in (ORIGINAL_DATA_DIR, NEW_DATA_DIR):
        for k, v in _counts_under_root(Path(base)).items():
            merged[k] = merged.get(k, 0) + v
    return merged


def get_original_dataset_class_counts() -> Dict[str, int]:
    """Counts from the project cassava dataset only (Notebook/cassava_small)."""
    return _counts_under_root(Path(ORIGINAL_DATA_DIR))


def get_class_distribution_for_metrics() -> Dict[str, int]:
    """
    Class counts for GET /metrics: original dataset folders, all model classes present.
    Missing folders report 0.
    """
    raw = get_original_dataset_class_counts()
    return {name: int(raw.get(name, 0)) for name in EXPECTED_CLASSES}


def get_persisted_validation_accuracy() -> Optional[float]:
    """Last validation accuracy from retrain (0–1), or None if not saved."""
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
    """Best known val accuracy, or DEFAULT_VALIDATION_ACCURACY if never persisted."""
    acc = get_persisted_validation_accuracy()
    if acc is not None:
        return acc
    return DEFAULT_VALIDATION_ACCURACY


def humanize_class_name(raw: str) -> str:
    """bacterial_blight -> Bacterial blight"""
    parts = raw.replace("-", "_").split("_")
    return " ".join(p.capitalize() for p in parts if p)
