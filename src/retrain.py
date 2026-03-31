import json
import os
import shutil
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import GlobalAveragePooling2D, Dense, Dropout
from tensorflow.keras.models import Model

MODEL_PATH = "models/best_cassava_binary_finals.keras"
ORIGINAL_DATA_DIR = "data/train"
NEW_DATA_DIR = "data/new_data"
COMBINED_DATA_DIR = "data/combined_data"

IMG_SIZE = (224, 224)
BATCH_SIZE = 32


def copy_folder_contents(src_folder: str, dst_folder: str):
    if not os.path.exists(src_folder):
        return

    for class_name in os.listdir(src_folder):
        src_class_dir = os.path.join(src_folder, class_name)
        dst_class_dir = os.path.join(dst_folder, class_name)

        if os.path.isdir(src_class_dir):
            os.makedirs(dst_class_dir, exist_ok=True)

            for filename in os.listdir(src_class_dir):
                src_file = os.path.join(src_class_dir, filename)
                dst_file = os.path.join(dst_class_dir, filename)

                if os.path.isfile(src_file):
                    shutil.copy2(src_file, dst_file)


def retrain_model(new_data_dir: str = NEW_DATA_DIR, train_dir: str = ORIGINAL_DATA_DIR):
    if os.path.exists(COMBINED_DATA_DIR):
        shutil.rmtree(COMBINED_DATA_DIR)

    os.makedirs(COMBINED_DATA_DIR, exist_ok=True)

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
        COMBINED_DATA_DIR,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode="categorical",
        subset="training",
        shuffle=True
    )

    val_data = datagen.flow_from_directory(
        COMBINED_DATA_DIR,
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

    history = model.fit(
        train_data,
        validation_data=val_data,
        epochs=3,
        verbose=1
    )

    val_loss, val_accuracy = model.evaluate(val_data, verbose=0)
    model.save(MODEL_PATH)

    if os.path.exists(new_data_dir):
        shutil.rmtree(new_data_dir)
        os.makedirs(new_data_dir, exist_ok=True)

    metrics_path = os.path.join("models", "training_metrics.json")
    os.makedirs(os.path.dirname(metrics_path), exist_ok=True)
    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "validation_accuracy": float(val_accuracy),
                "validation_loss": float(val_loss),
            },
            f,
        )

    return {
        "message": "Model retrained successfully",
        "validation_accuracy": float(val_accuracy),
        "validation_loss": float(val_loss)
    }