"""Binary cassava disease classifier — single model load per process for FastAPI."""

from __future__ import annotations

import os
from pathlib import Path

import numpy as np
from PIL import Image

# Less TF log noise and slightly leaner runtime on small containers.
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
os.environ.setdefault("TF_ENABLE_ONEDNN_OPTS", "0")

from tensorflow.keras.models import load_model  # noqa: E402  (after env)

_BASE = Path(__file__).resolve().parent.parent
MODEL_PATH = _BASE / "models" / "cassava_binary_final.keras"

CLASS_NAMES = [
    "bacterial_blight",
    "healthy",
]

_model = None


def get_model():
    """Load Keras model once per worker process (not per request)."""
    global _model
    if _model is None:
        if not MODEL_PATH.is_file():
            raise FileNotFoundError(
                f"Model not found at {MODEL_PATH}. Deploy the .keras file with the API.",
            )
        # compile=False drops optimizer/training state — lower memory for inference only.
        _model = load_model(MODEL_PATH, compile=False)
    return _model


def preprocess_image(image_path: str) -> np.ndarray:
    img = Image.open(image_path).convert("RGB")
    img = img.resize((224, 224))
    img_array = np.array(img) / 255.0
    img_array = np.expand_dims(img_array, axis=0)
    return img_array


def predict_image(image_path: str) -> dict:
    model = get_model()
    img_array = preprocess_image(image_path)
    prediction = model.predict(img_array, verbose=0)[0]

    predicted_index = int(np.argmax(prediction))
    predicted_class = CLASS_NAMES[predicted_index]
    confidence = float(prediction[predicted_index])

    return {
        "predicted_class": predicted_class,
        "confidence": confidence,
        "probabilities": {
            CLASS_NAMES[i]: float(prediction[i]) for i in range(len(CLASS_NAMES))
        },
    }
