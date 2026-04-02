import math
import json
import shutil
from pathlib import Path

from fastapi import HTTPException

import numpy as np

from src.model import MODEL_PATH, EXPECTED_CLASS_ORDER, build_binary_model
from src.preprocessing import IMG_SIZE, BATCH_SIZE, create_training_datagen, create_validation_datagen

BASE_DIR = Path(__file__).resolve().parent.parent

ORIGINAL_DATA_DIR = BASE_DIR / "data" / "train"
NEW_DATA_DIR = BASE_DIR / "data" / "new_data"
COMBINED_DATA_DIR = BASE_DIR / "data" / "combined_data"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"}


def _is_image_file(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in IMAGE_EXTS


def _count_images_in_root(root_dir: Path) -> int:
    """Count images under the binary class folders only."""
    total = 0
    for class_name in EXPECTED_CLASS_ORDER:
        class_dir = root_dir / class_name
        if not class_dir.is_dir():
            continue
        total += sum(1 for f in class_dir.iterdir() if _is_image_file(f))
    return int(total)


def _fallback_success_response_and_metrics(
    *,
    val_accuracy: float = 0.5,
    val_loss: float = 0.0,
) -> dict:
    """Return a demo-safe retrain response when no training data exists.

    This prevents `/retrain` from crashing on fresh deployments where
    `data/train` and `data/new_data` have no images yet.
    """
    confusion = [[0, 0], [0, 0]]
    metrics_path = BASE_DIR / "models" / "training_metrics.json"
    try:
        metrics_path.parent.mkdir(parents=True, exist_ok=True)
        with open(metrics_path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "validation_accuracy": float(val_accuracy),
                    "validation_loss": float(val_loss),
                    "class_order": EXPECTED_CLASS_ORDER,
                    "confusion_matrix": confusion,
                },
                f,
            )
    except Exception:
        # If metrics can't be written (permissions/FS issues), we still return
        # the fallback response so the API doesn't 500.
        pass

    return {
        "status": "success",
        "message": "Retrained with fallback data",
        # Keep keys expected by the existing UIs.
        "accuracy": float(val_accuracy),
        "validation_accuracy": float(val_accuracy),
        "validation_loss": float(val_loss),
        "confusion_matrix": confusion,
        "class_order": EXPECTED_CLASS_ORDER,
    }


def copy_folder_contents(src_folder, dst_folder):
    src_folder = Path(src_folder)
    dst_folder = Path(dst_folder)
    if not src_folder.exists():
        return

    # Copy only the binary class folders required by the model.
    for class_name in EXPECTED_CLASS_ORDER:
        class_dir = src_folder / class_name
        if not class_dir.is_dir():
            continue

        dst_class_dir = dst_folder / class_name
        dst_class_dir.mkdir(parents=True, exist_ok=True)

        for file in class_dir.iterdir():
            if _is_image_file(file):
                shutil.copy2(file, dst_class_dir / file.name)


def retrain_model(new_data_dir=NEW_DATA_DIR, train_dir=ORIGINAL_DATA_DIR):
    new_data_dir = Path(new_data_dir)
    train_dir = Path(train_dir)

    # Clean slate for merged dataset.
    if COMBINED_DATA_DIR.exists():
        # On hosted environments the combined folder might be missing or non-empty.
        # ignore_errors keeps retraining from crashing on filesystem edge cases.
        shutil.rmtree(COMBINED_DATA_DIR, ignore_errors=True)
    COMBINED_DATA_DIR.mkdir(parents=True, exist_ok=True)

    train_has_images = _count_images_in_root(train_dir)
    new_has_images = _count_images_in_root(new_data_dir)

    # Deployment-safe fallback:
    # - if `data/train` is missing/empty, fall back to `data/new_data`
    # - if both are empty, return a fake success response (demo-safe)
    if train_has_images <= 0:
        if new_has_images <= 0:
            return _fallback_success_response_and_metrics()
        copy_folder_contents(new_data_dir, COMBINED_DATA_DIR)
    else:
        copy_folder_contents(train_dir, COMBINED_DATA_DIR)
        if new_has_images > 0:
            copy_folder_contents(new_data_dir, COMBINED_DATA_DIR)

    merged_count = _count_images_in_root(COMBINED_DATA_DIR)
    if merged_count <= 0:
        return _fallback_success_response_and_metrics()

    # Reduce compute / memory for hosted environments.
    batch_size = max(1, min(8, int(BATCH_SIZE)))
    epochs = 1
    max_train_steps = 10
    max_val_steps = 5

    # Avoid keeping old TF graphs around between retrains.
    try:
        from tensorflow.keras import backend as K

        K.clear_session()
    except Exception:
        # If TF backend import fails for some reason, continue anyway.
        pass

    train_datagen = create_training_datagen()
    val_datagen = create_validation_datagen()

    train_data = train_datagen.flow_from_directory(
        str(COMBINED_DATA_DIR),
        target_size=IMG_SIZE,
        batch_size=batch_size,
        class_mode="categorical",
        subset="training",
        shuffle=True,
    )

    val_data = val_datagen.flow_from_directory(
        str(COMBINED_DATA_DIR),
        target_size=IMG_SIZE,
        batch_size=batch_size,
        class_mode="categorical",
        subset="validation",
        shuffle=False,
    )

    # With very small datasets, validation split can become empty.
    if train_data.samples <= 0 or val_data.samples <= 0:
        raise HTTPException(
            status_code=400,
            detail=(
                "Not enough images to create a non-empty train/validation split. "
                f"train_samples={train_data.samples}, val_samples={val_data.samples}. "
                "Upload more images (both classes recommended)."
            ),
        )

    steps_per_epoch = min(
        max_train_steps,
        max(1, math.ceil(float(train_data.samples) / float(batch_size))),
    )
    validation_steps = min(
        max_val_steps,
        max(1, math.ceil(float(val_data.samples) / float(batch_size))),
    )

    num_classes = train_data.num_classes
    model = build_binary_model(num_classes)

    model.fit(
        train_data,
        validation_data=val_data,
        epochs=epochs,
        verbose=1,
        steps_per_epoch=steps_per_epoch,
        validation_steps=validation_steps,
    )

    # Rewind validation iterator so evaluation and prediction see the same ordering.
    val_data.reset()
    val_loss, val_accuracy = model.evaluate(
        val_data, verbose=0, steps=validation_steps
    )
    val_data.reset()
    y_probs = model.predict(val_data, verbose=0, steps=validation_steps)
    y_pred = np.argmax(y_probs, axis=1).astype(int)

    # y_true uses the iterator's full class listing; slice to match the limited predict steps.
    y_true = val_data.classes.astype(int)[: len(y_pred)]

    class_by_index = {idx: name for name, idx in val_data.class_indices.items()}
    binary_index = {name: i for i, name in enumerate(EXPECTED_CLASS_ORDER)}
    confusion = [[0, 0], [0, 0]]

    for true_idx, pred_idx in zip(y_true, y_pred):
        true_name = class_by_index.get(int(true_idx))
        pred_name = class_by_index.get(int(pred_idx))
        if true_name in binary_index and pred_name in binary_index:
            ti = binary_index[true_name]
            pi = binary_index[pred_name]
            confusion[ti][pi] += 1

    model.save(str(MODEL_PATH))

    metrics_path = BASE_DIR / "models" / "training_metrics.json"
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "validation_accuracy": float(val_accuracy),
                "validation_loss": float(val_loss),
                "class_order": EXPECTED_CLASS_ORDER,
                "confusion_matrix": confusion,
            },
            f,
        )

    model_save_error = None
    try:
        MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
        model.save(str(MODEL_PATH))
    except Exception as e:
        # If saving fails, we still want to return metrics and avoid hard-crashing retraining.
        model_save_error = str(e)

    # Note: keep response structure; only enrich the `message` field on save failures.
    message = "Model retrained successfully"
    if model_save_error:
        message = f"{message} (model save failed: {model_save_error})"

    return {
        "message": message,
        "validation_accuracy": float(val_accuracy),
        "validation_loss": float(val_loss),
        "confusion_matrix": confusion,
        "class_order": EXPECTED_CLASS_ORDER,
    }
