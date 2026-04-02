import os
import shutil
from contextlib import asynccontextmanager
from typing import List

from fastapi import FastAPI, File, HTTPException, UploadFile

from src import insights as insights_module
from src.model import get_model
from src.prediction import predict_image

UPLOAD_DIR = "uploads"
NEW_DATA_DIR = "data/new_data"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(NEW_DATA_DIR, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Fail fast on startup if the model cannot be loaded.
    get_model()
    yield


app = FastAPI(title="Cassava Binary Cassava Leaf API", lifespan=lifespan)


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

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        result = predict_image(file_path)

        return {
            "filename": file.filename,
            "prediction": result["predicted_class"],
            "confidence": result["confidence"],
            "probabilities": result["probabilities"],
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except FileNotFoundError as e:
        raise HTTPException(status_code=500, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {e}") from e


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
def retrain():
    from src.retrain import retrain_model

    try:
        result = retrain_model()
        return result
    except HTTPException:
        # Preserve explicit HTTP errors from the retraining logic.
        raise
    except Exception as e:
        # Railway will surface this detail to the caller as JSON `{ "detail": ... }`.
        raise HTTPException(
            status_code=500,
            detail=f"Retraining failed ({type(e).__name__}): {e}",
        ) from e
