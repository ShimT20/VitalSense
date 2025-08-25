import os
import joblib
import shutil
import numpy as np
import pandas as pd
from pyentrp import entropy as ent
from scipy.stats import skew, kurtosis
from fastapi.responses import FileResponse, JSONResponse
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Directories for file storage
RESULT_FOLDER = "results"
os.makedirs(RESULT_FOLDER, exist_ok=True)

# Load the trained Random Forest model
MODEL_PATH = "random_forest3.pkl"
model = joblib.load(MODEL_PATH)

# Feature extraction function
def extract_features(ecg_signal, fs=100):
    features = {
        'min': np.min(ecg_signal),
        'max': np.max(ecg_signal),
        'range': np.ptp(ecg_signal),
        'median': np.median(ecg_signal),
        'mean': np.mean(ecg_signal),
        'std_dev': np.std(ecg_signal),
        'skewness': skew(ecg_signal) if np.std(ecg_signal) > 1e-6 else 0,
        'kurtosis': kurtosis(ecg_signal) if np.std(ecg_signal) > 1e-6 else 0,
    }

    # Frequency-domain features
    n = len(ecg_signal)
    fft_values = np.fft.fft(ecg_signal)
    freqs = np.fft.fftfreq(n, d=1/fs)
    power_spectrum = np.abs(fft_values) ** 2

    vlf_power = np.sum(power_spectrum[(freqs >= 0.0033) & (freqs < 0.04)])
    lf_power = np.sum(power_spectrum[(freqs >= 0.04) & (freqs < 0.15)])
    hf_power = np.sum(power_spectrum[(freqs >= 0.15) & (freqs < 0.4)])
    total_power = vlf_power + lf_power + hf_power

    features.update({
        'vlf_power': vlf_power,
        'lf_power': lf_power,
        'hf_power': hf_power,
        'total_power': total_power,
        'lf_hf_ratio': lf_power / hf_power if hf_power != 0 else 0,
        'lfnu': (lf_power / total_power) * 100 if total_power != 0 else 0,
        'hfnu': (hf_power / total_power) * 100 if total_power != 0 else 0,
        'Permutation_Entropy': ent.permutation_entropy(ecg_signal, order=3, delay=1, normalize=True)
    })
    return features

@app.post("/predict")
async def predict(file: UploadFile):
    input_file_path = f"temp_{file.filename}"
    with open(input_file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    df = pd.read_csv(input_file_path)
    if "ECG" not in df.columns:
        return {"error": "Missing 'ECG' column in the input CSV"}

    window_size = 6000  # 60 seconds at 100 Hz
    feature_list = []
    for i in range(0, len(df), window_size):
        ecg_segment = df["ECG"].iloc[i:i + window_size].values
        if len(ecg_segment) == window_size:
            features = extract_features(ecg_segment)
            feature_list.append(features)
        else:
            print(f"Skipped segment at index {i}, length={len(ecg_segment)}")

    print("Number of feature vectors:", len(feature_list))

    # Save extracted features separately
    df_features = pd.DataFrame(feature_list)
    df_features.fillna(0, inplace=True)
    features_file_path = os.path.join(RESULT_FOLDER, "features_" + file.filename)
    df_features.to_csv(features_file_path, index=False)
    print("df_features:", df_features)
    print("df_features shape:", getattr(df_features, "shape", None))

    # Make predictions
    predictions = model.predict(df_features)
    predictions_df = pd.DataFrame(predictions, columns=["Prediction"])
    print(predictions_df)
    predictions_file_path = os.path.join(RESULT_FOLDER, "predictions_" + file.filename)
    predictions_df.to_csv(predictions_file_path, index=False)

    # Calculate AHI (count only "A" which represents apnea)
    apnea_count = np.sum(predictions == "A")
    total_windows = len(predictions)
    ahi = apnea_count / (total_windows / 60) if total_windows > 0 else 0
    print(ahi)
    # Save AHI to file
    ahi_file_path = os.path.join(RESULT_FOLDER, "ahi_" + file.filename)
    with open(ahi_file_path, "w") as f:
        f.write(f"{ahi}\n")

    return JSONResponse(content=ahi)

@app.get("/download/{filename}")
async def download_file(filename: str):
    file_path = os.path.join(RESULT_FOLDER, filename)
    if not os.path.exists(file_path):
        return {"error": "File not found"}
    return FileResponse(file_path, filename=filename)

@app.get("/")
async def read_root():
    return {"message": "Welcome to the Sleep Apnea Prediction API!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=True)