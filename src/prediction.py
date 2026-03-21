import numpy as np
from tensorflow.keras.models import load_model
from tensorflow.keras.utils import load_img, img_to_array

MODEL_PATH = "models/cassava_model.keras"

CLASS_NAMES = [
    "bacterial_blight",
    "brown_streak",
    "green_mottle",
    "healthy",
    "mosaic"
]

model = load_model(MODEL_PATH)


def predict_image(image_path: str) -> dict:
    img = load_img(image_path, target_size=(224, 224))
    img_array = img_to_array(img) / 255.0
    img_array = np.expand_dims(img_array, axis=0)

    prediction = model.predict(img_array, verbose=0)[0]
    predicted_index = int(np.argmax(prediction))
    predicted_class = CLASS_NAMES[predicted_index]
    confidence = float(np.max(prediction))

    return {
        "predicted_class": predicted_class,
        "confidence": confidence
    }