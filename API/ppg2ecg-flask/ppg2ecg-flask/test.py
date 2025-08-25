import requests
import numpy as np
import io
import os

# Use raw string or escape backslashes in Windows paths
ppg_file_path = r'C:\ppg_dummy_data.csv'  # <-- raw string to avoid backslash issues

# Send the POST request with the file
with open(ppg_file_path, 'rb') as f:
    files = {'file': ('ppg_data.csv', f, 'text/plain')}
    response = requests.post('http://192.168.0.122:8000/upload', files=files)

# Check the response
if response.status_code == 200:
    try:
        # Read CSV as 2 columns: Time and ECG
        ecg_data = np.loadtxt(io.StringIO(response.text), delimiter=',', skiprows=1)  # skip header row

        print(f"ECG data shape: {ecg_data.shape}")  # Should be (512, 2)

        if ecg_data.shape[0] == 512 and ecg_data.shape[1] == 2:
            print("✅ Test passed: ECG data has 512 samples and 2 columns (Time, ECG).")
        else:
            print("❌ Test failed: Unexpected data shape.")

        # Optional: print first few rows
        print("First 5 rows:\n", ecg_data[:5])

    except Exception as e:
        print(f"Error reading ECG CSV: {e}")

else:
    print(f"❌ API error: {response.status_code} - {response.text}")
