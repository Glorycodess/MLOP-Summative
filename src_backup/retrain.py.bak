import json
import os
import shutil
from pathlib import Path
import tensorflow as tf
import numpy as np
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import GlobalAveragePooling2D, Dense, Dropout
from tensorflow.keras.models import Model

BASE_DIR = Path(__file__).resolve().parent.parent

MODEL_PATH = BASE_DIR / "models" / "cassava_binary_final.keras"
ORIGINAL_DATA_DIR = BASE_DIR / "data" / "train"
NEW_DATA_DIR = BASE_DIR / "data" / "new_data"
COMBINED_DATA_DIR = BASE_DIR / "data" / "combined_data"

IMG_SIZE = (224, 224)
BATCH_SIZE = 32
EXPECTED_CLASS_ORDER = ["bacterial_blight", "healthy"]


def copy_folder_contents(src_folder, dst_folder):
    src_folder = Path(src_folder)
    dst_folder = Path(dst_folder)
    if not src_folder.exists():
        return

    for class_dir in src_folder.iterdir():
        if not class_dir.is_dir():
            continue
        dst_class_dir = dst_folder / class_dir.name
        dst_class_dir.mkdir(parents=True, exist_ok=True)

        for file in class_dir.iterdir():
            if file.is_file():
                shutil.copy2(file, dst_class_dir / file.name)


def retrain_model(new_data_dir=NEW_DATA_DIR, train_dir=ORIGINAL_DATA_DIR):
    new_data_dir = Path(new_data_dir)
    train_dir = Path(train_dir)

    if COMBINED_DATA_DIR.exists():
        shutil.rmtree(COMBINED_DATA_DIR)
    COMBINED_DATA_DIR.mkdir(parents=True, exist_ok=True)

    copy_folder_contents(train_dir, COMBINED_DATA_DIR)
    copy_folder_contents(new_data_dir, COMBINED_DATA_DIR)

    datagen = ImageDataGenerator(
        rescale=1./255,
        validation_split=0.2,
        rotation_range=20,
        zoom_range=0.2,
        horizontal_flip=True
    )

    train_data = datagen.flow_from_directory(
        str(COMBINED_DATA_DIR),
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode="categorical",
        subset="training",
        shuffle=True
    )

    val_data = datagen.flow_from_directory(
        str(COMBINED_DATA_DIR),
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode="categorical",
        subset="validation",
        shuffle=False
    )

    num_classes = train_data.num_classes

    base_model = MobileNetV2(
        weights="imagenet",
        include_top=False,
        input_shape=(224, 224, 3)
    )
    base_model.trainable = False

    x = base_model.output
    x = GlobalAveragePooling2D()(x)
    x = Dense(128, activation="relu")(x)
    x = Dropout(0.5)(x)
    outputs = Dense(num_classes, activation="softmax")(x)

    model = Model(inputs=base_model.input, outputs=outputs)

    model.compile(
        optimizer="adam",
        loss="categorical_crossentropy",
        metrics=["accuracy"]
    )

    model.fit(
        train_data,
        validation_data=val_data,
        epochs=3,
        verbose=1
    )

    val_loss, val_accuracy = model.evaluate(val_data, verbose=0)
    val_data.reset()
    y_true = val_data.classes.astype(int)
    y_probs = model.predict(val_data, verbose=0)
    y_pred = np.argmax(y_probs, axis=1).astype(int)
    class_by_index = {
        idx: name for name, idx in val_data.class_indices.items()
    }
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

    # Do NOT delete uploaded images after training.
    # Product flow expects the server to retain uploaded data so users can retrain later
    # without re-uploading.

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

    return {
        "message": "Model retrained successfully",
        "validation_accuracy": float(val_accuracy),
        "validation_loss": float(val_loss),
        "confusion_matrix": confusion,
        "class_order": EXPECTED_CLASS_ORDER,
    }