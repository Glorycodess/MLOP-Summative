import os
import shutil
from contextlib import asynccontextmanager
from pathlib import Path
from uuid import uuid4

from fastapi import FastAPI, File, UploadFile
from typing import List

from src import insights as insights_module
from src.prediction import get_model, predict_image

BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"
NEW_DATA_DIR = BASE_DIR / "data" / "new_data"
TRAIN_DIR = BASE_DIR / "data" / "train"
ALLOWED_BINARY_LABELS = {"healthy", "bacterial_blight"}

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
    file_path = str(Path(UPLOAD_DIR) / file.filename)

    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    result = predict_image(file_path)
    predicted_label = result["predicted_class"]

    # Save predicted image into binary retrain pool so retrain can run later
    # without requiring users to upload again.
    if predicted_label in ALLOWED_BINARY_LABELS:
        dst_dir = Path(NEW_DATA_DIR) / predicted_label
        dst_dir.mkdir(parents=True, exist_ok=True)
        suffix = Path(file.filename).suffix.lower() or ".jpg"
        dst_name = f"{Path(file.filename).stem}_{uuid4().hex[:10]}{suffix}"
        shutil.copy2(file_path, dst_dir / dst_name)

    return {
        "filename": file.filename,
        "prediction": predicted_label,
        "confidence": result["confidence"],
        "probabilities": result["probabilities"],
    }


@app.post("/upload-data")
async def upload_data(
    label: str,
    files: List[UploadFile] = File(...),
):
    label = label.strip().lower()
    if label not in ALLOWED_BINARY_LABELS:
        return {
            "message": "Only binary labels are allowed",
            "label": label,
            "files": [],
        }
    label_dir = str(Path(NEW_DATA_DIR) / label)
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
def retrain():
    """
    Retrain immediately and return metrics.

    Flutter expects `validation_accuracy` and `validation_loss` in the response.
    """
    # Import only when retrain is invoked — avoids loading the full training graph at worker startup.
    from src.retrain import retrain_model

    return retrain_model(new_data_dir=NEW_DATA_DIR, train_dir=TRAIN_DIR)
