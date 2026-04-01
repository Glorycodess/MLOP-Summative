import numpy as np
from PIL import Image, UnidentifiedImageError
from tensorflow.keras.preprocessing.image import ImageDataGenerator

IMG_SIZE = (224, 224)
BATCH_SIZE = 32


def preprocess_image(image_path: str) -> np.ndarray:
    try:
        with Image.open(image_path) as img:
            img = img.convert("RGB")
            img = img.resize(IMG_SIZE)
            img_array = np.array(img, dtype=np.float32) / 255.0
    except UnidentifiedImageError as e:
        raise ValueError(f"Unsupported or corrupted image file: {image_path}") from e
    except OSError as e:
        raise ValueError(f"Failed to read image file: {image_path}") from e

    img_array = np.expand_dims(img_array, axis=0)
    return img_array


def create_training_datagen():
    return ImageDataGenerator(
        rescale=1.0 / 255,
        validation_split=0.2,
        rotation_range=20,
        zoom_range=0.2,
        horizontal_flip=True,
    )


def create_validation_datagen():
    return ImageDataGenerator(
        rescale=1.0 / 255,
        validation_split=0.2,
    )
