import requests
import streamlit as st

API_BASE = "https://mlop-summative-production.up.railway.app"

st.set_page_config(page_title="Cassava ML App", layout="centered")

st.title("Cassava Leaf Disease Classifier")
st.write("This is a simple web UI connected to the deployed FastAPI backend.")

# Health
st.subheader("System Status")
if st.button("Check API Status"):
    try:
        r = requests.get(f"{API_BASE}/health", timeout=20)
        r.raise_for_status()
        data = r.json()
        st.success(f"API Status: {data.get('status', 'unknown')}")
        st.write(data)
    except Exception as e:
        st.error(f"API check failed: {e}")

# Metrics
st.subheader("Model Metrics")
if st.button("Load Metrics"):
    try:
        r = requests.get(f"{API_BASE}/metrics", timeout=20)
        r.raise_for_status()
        data = r.json()
        st.json(data)
    except Exception as e:
        st.error(f"Failed to load metrics: {e}")

# Predict
st.subheader("Predict from Image")
uploaded_file = st.file_uploader("Upload a cassava leaf image", type=["jpg", "jpeg", "png"])

if uploaded_file is not None:
    st.image(uploaded_file, caption="Selected image", use_container_width=True)

    if st.button("Predict"):
        try:
            files = {
                "file": (uploaded_file.name, uploaded_file.getvalue(), uploaded_file.type or "image/jpeg")
            }
            r = requests.post(f"{API_BASE}/predict", files=files, timeout=60)
            r.raise_for_status()
            data = r.json()
            st.success("Prediction completed")
            st.write(f"**Prediction:** {data.get('prediction')}")
            st.write(f"**Confidence:** {round(float(data.get('confidence', 0)) * 100, 2)}%")
            if "probabilities" in data:
                st.write("**Probabilities:**")
                st.json(data["probabilities"])
        except Exception as e:
            st.error(f"Prediction failed: {e}")

# Retrain
st.subheader("Retrain Model")
if st.button("Retrain Model"):
    try:
        r = requests.post(f"{API_BASE}/retrain", timeout=120)
        r.raise_for_status()
        data = r.json()
        st.success(data.get("message", "Retraining completed"))
        st.write(f"**Validation Accuracy:** {round(float(data.get('validation_accuracy', 0)) * 100, 2)}%")
        st.write(f"**Validation Loss:** {round(float(data.get('validation_loss', 0)), 4)}")
        if "confusion_matrix" in data:
            st.write("**Confusion Matrix:**")
            st.json(data["confusion_matrix"])
    except Exception as e:
        st.error(f"Retraining failed: {e}")