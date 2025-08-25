import pandas as pd
import matplotlib.pyplot as plt

# Load your CSV file
file_path = r"C:\Users\saadm\ppg_with_apnea1.csv"
df = pd.read_csv(file_path)

# Display the first few rows to understand the structure
print(df.head())

# Replace 'ECG' andt'Time (s)' with the actual column names if different
time_col = 'time'  # or 'time' or whatever is in the file
signal_col = 'ppg'     # or 'PPG' or another name

duration = 20  # Change this to the number of seconds you want to show

# Filter the DataFrame to only include rows within the desired time window
df_filtered = df[df[time_col] <= duration]

# Plotting
plt.figure(figsize=(15, 5))
plt.plot(df_filtered[time_col], df_filtered[signal_col], color='blue')
plt.title(f"Signal Plot (First {duration} seconds)")
plt.xlabel("Time (s)")
plt.ylabel(signal_col)
plt.grid(True)
plt.tight_layout()
plt.show()