'''import requests

url = "http://127.0.0.1:8000/predict"
file_path = "ECGDATA/a01.csv"

with open(file_path, "rb") as f:
    files = {"file": f}
    response = requests.post(url, files=files)

print(response.json())  # Print response (download URL)
'''
import requests

# Your file path and API URL
file_path = r"C:\Users\Omar\Downloads\DatabaseApnea\ecg_w_time_all_windows.csv"
url = "http://172.29.38.191:8080/predict"

# Send the file
with open(file_path, "rb") as f:
    response = requests.post(url, files={"file": f})

# Save the response as a file
if response.status_code == 200:
    # Get filename from headers or just set your own
    with open("AHI.csv", "wb") as out_file:
        out_file.write(response.content)
    print("File downloaded successfully!")
else:
    print("Error:", response.status_code)
    print("Response:", response.text)
