import os
import shutil
from contextlib import asynccontextmanager

from fastapi import BackgroundTasks, FastAPI, File, UploadFile
from typing import List

from src import insights as insights_module
from src.prediction import get_model, predict_image

UPLOAD_DIR = "uploads"
NEW_DATA_DIR = "data/new_data"
TRAIN_DIR = "data/train"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(NEW_DATA_DIR, exist_ok=True)
os.makedirs(TRAIN_DIR, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the Keras model once per worker when the app starts (fail fast if missing)."""
    get_model()
    yield


app = FastAPI(
    title="Cassava Binary Cassava Leaf API",
    lifespan=lifespan,
)


@app.get("/")
def home():
    return {"message": "Cassava Binary Cassava Leaf API is running"}


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": "cassava_binary_final.keras",
        "message": "API is healthy",
    }


@app.get("/metrics")
def metrics():
    class_distribution = insights_module.get_class_distribution_for_metrics()
    validation_accuracy = insights_module.get_validation_accuracy_for_metrics()
    return {
        "class_distribution": class_distribution,
        "validation_accuracy": validation_accuracy,
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
        "confidence": result["confidence"],
        "probabilities": result["probabilities"],
    }


@app.post("/upload-data")
async def upload_data(
    label: str,
    files: List[UploadFile] = File(...),
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
        "files": saved_files,
    }


@app.post("/retrain")
def retrain(background_tasks: BackgroundTasks):
    # Import only when retrain is invoked — avoids loading the full training graph at worker startup.
    from src.retrain import retrain_model

    background_tasks.add_task(retrain_model, new_data_dir=NEW_DATA_DIR, train_dir=TRAIN_DIR)
    return {
        "message": "Retraining started in background. Check /metrics for updated accuracy when done.",
    }
