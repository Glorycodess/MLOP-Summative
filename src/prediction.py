import numpy as np
from PIL import Image
from tensorflow.keras.models import load_model

MODEL_PATH = "models/cassava_binary_final.keras"

CLASS_NAMES = [
    "bacterial_blight",
    "healthy",
]

model = load_model(MODEL_PATH)


def preprocess_image(image_path: str) -> np.ndarray:
    img = Image.open(image_path).convert("RGB")
    img = img.resize((224, 224))
    img_array = np.array(img) / 255.0
    img_array = np.expand_dims(img_array, axis=0)
    return img_array


def predict_image(image_path: str) -> dict:
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
        }
    }