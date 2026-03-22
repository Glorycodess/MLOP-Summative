import os
import shutil
from fastapi import FastAPI, File, UploadFile
from typing import List

from src.prediction import predict_image
from src.retrain import retrain_model
from src import insights as insights_module

app = FastAPI(title="Cassava Leaf Disease API")

UPLOAD_DIR = "uploads"
NEW_DATA_DIR = "data/new_data"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(NEW_DATA_DIR, exist_ok=True)


@app.get("/")
def home():
    return {"message": "Cassava Leaf Disease API is running"}


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": "cassava_model.keras",
        "message": "API is healthy"
    }


@app.get("/metrics")
def metrics():
    """
    Real model insight data for the Flutter Predict screen.

    * class_distribution: image counts per class from the original cassava dataset
      folder (Notebook/cassava_small). All five model classes are listed; counts
      are 0 if that folder is absent or empty.
    * validation_accuracy: from models/training_metrics.json after retrain, else a
      default placeholder until the first retrain run.
    """
    class_distribution = insights_module.get_class_distribution_for_metrics()
    validation_accuracy = insights_module.get_validation_accuracy_for_metrics()
    return {
        "class_distribution": class_distribution,
        "validation_accuracy": validation_accuracy,
    }


@app.get("/model-insights")
def model_insights():
    """
    Same data as /metrics but with human-readable class labels in class_distribution.
    Kept for backward compatibility.
    """
    raw = insights_module.get_class_distribution_counts()
    distribution = {
        insights_module.humanize_class_name(k): int(v) for k, v in raw.items()
    }
    acc = insights_module.get_persisted_validation_accuracy()
    return {
        "class_distribution": distribution,
        "validation_accuracy": acc,
    }


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    file_path = os.path.join(UPLOAD_DIR, file.filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    result = predict_image(file_path)

    return {
        "filename": file.filename,
        "prediction": result["predicted_class"],
        "confidence": result["confidence"]
    }


@app.post("/upload-data")
async def upload_data(
    label: str,
    files: List[UploadFile] = File(...)
):
    label_dir = os.path.join(NEW_DATA_DIR, label)
    os.makedirs(label_dir, exist_ok=True)

    saved_files = []

    for file in files:
        file_path = os.path.join(label_dir, file.filename)
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        saved_files.append(file.filename)

    return {
        "message": f"{len(saved_files)} files uploaded successfully",
        "label": label,
        "files": saved_files
    }


@app.post("/retrain")
def retrain():
    result = retrain_model()
    return result