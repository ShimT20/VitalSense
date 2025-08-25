import pandas as pd

# Load your original data
original_data = pd.read_csv(r"C:\Users\saadm\Downloads\ecg_data (5).csv")

# Repeat ECG values to fill 120 seconds
ecg_cycle = original_data["ECG"].tolist()
time_step = 0.01
total_time = 3600.0
n_cycles = int(total_time / 15.35) + 1  # Number of cycles needed
full_ecg = ecg_cycle * n_cycles

# Trim to match 120 seconds (12,001 rows)
full_ecg = full_ecg[:360001]

# Generate time column
time = [round(i * time_step, 2) for i in range(360001)]

# Create DataFrame and save
df = pd.DataFrame({"Time (s)": time, "ECG": full_ecg})
df.to_csv("extended_ecg_120s.csv", index=False)