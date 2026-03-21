import os
import shutil
from fastapi import FastAPI, File, UploadFile
from typing import List

from src.prediction import predict_image
from src.retrain import retrain_model

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