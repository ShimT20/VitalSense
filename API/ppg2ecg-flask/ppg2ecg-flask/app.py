import os
import io
import numpy as np
import tensorflow as tf
import cv2
import sklearn.preprocessing as skp
from flask import Flask, request, render_template, send_file
import matplotlib.pyplot as plt
import tflib
import module
import preprocessing
import pandas as pd

# Set TensorFlow configurations
tf.keras.backend.set_floatx('float64')
tf.autograph.set_verbosity(0)

# Define the inference function for ECG generation
@tf.function
def sample_P2E(P, model):
    fake_ecg = model(P, training=False)
    return fake_ecg

# Define signal processing parameters
ecg_sampling_freq = 100
ppg_sampling_freq = 128
window_size = 4
ppg_segment_size = ppg_sampling_freq * window_size  # 512 samples
Ts = 128
Nxx = window_size*Ts
ppg_sampling_rate = 150 #200 #400
ecg_segment_size = ecg_sampling_freq*window_size
ppg_segment_size = ppg_sampling_freq*window_size
model_dir = 'weights'

""" model """
Gen_PPG2ECG = module.generator_attention()
""" resotre """
tflib.Checkpoint(dict(Gen_PPG2ECG=Gen_PPG2ECG), model_dir).restore()
print("model loaded successfully")

# Load the pre-trained model
#model_dir = 'saved_model.pb'  # Replace with the actual path to your model checkpoint
Gen_PPG2ECG = module.generator_attention()
tflib.Checkpoint(dict(Gen_PPG2ECG=Gen_PPG2ECG), model_dir).restore()
print("Model loaded successfully")

# Initialize Flask application
app = Flask(__name__)

# Route for the main page
@app.route('/')
def index():
    return render_template('index.html')

# @tf.function speeds things up (optional)
@tf.function
def sample_P2E(ppg_batch, model):
    return model(ppg_batch, training=False)

# Route to handle file upload and ECG generation
@app.route('/upload', methods=['POST'])
def upload_file():
    # Check if a file was uploaded
    if 'file' not in request.files:
        return 'No file uploaded', 400
    
    file = request.files['file']
    
    try:
        # Load the PPG signal from the uploaded file
        x_ppg = pd.read_csv(file, header=None)
        x_ppg = x_ppg.iloc[:len(x_ppg) - len(x_ppg)%(ppg_sampling_rate*window_size)] # 400 sps * 4 s = 1600, clip at 1600 multipl
        number_of_windows = int(len(x_ppg)//ppg_segment_size)
        x_ppg = np.array(x_ppg)
        
        
        # Resample the PPG signal to 512 samples
        x_ppg = cv2.resize(x_ppg, (number_of_windows, ppg_segment_size), interpolation=cv2.INTER_LINEAR)
        # Note: cv2.resize outputs (height, width), so (1, 512) here means shape (1, 512)
        x_ppg = np.hstack(x_ppg)
        
        # Filter the PPG signal
        x_ppg_prep = preprocessing.filter_ppg(x_ppg, 128)
        x_ppg_prep = x_ppg_prep.reshape((int(len(x_ppg_prep)/Nxx) , Nxx))
        x_ppg_prep = skp.minmax_scale(x_ppg_prep, (-1, 1), axis=1)
        
        # Generate the ECG signal using the model
        x_ecg_predicted = sample_P2E(x_ppg_prep, Gen_PPG2ECG)
        
        new_ecg_segment_size = 400 # 100 Hz x 4 seconds
        x_ecg_predicted_nd = np.hstack(x_ecg_predicted)
        #x_ecg_predicted_nd = cv2.resize(x_ecg_predicted_nd, (number_of_windows, new_ecg_segment_size), interpolation = cv2.INTER_LINEAR)
        
        x_ecg_predicted_nd = np.array(x_ecg_predicted_nd)  # shape (num_windows, 400)
        ecg_flat = x_ecg_predicted_nd.flatten()         # 1D ECG signal

        # Generate time axis at 100 Hz
        time_axis = np.arange(len(ecg_flat)) / 100  # 100 Hz sampling rate

        #### adding time column to the ecg data ####
        #x_ecg_predicted_nd = np.hstack(x_ecg_predicted_nd) # needed
        #time_steps = np.arange(number_of_windows * new_ecg_segment_size) * 0.01
        #x_ecg_predicted_nd_w_time = np.column_stack((time_steps, x_ecg_predicted_nd))


        #df = pd.DataFrame(x_ecg_predicted_nd_w_time, columns=['Time (s)', 'ECG'])
        df = pd.DataFrame({'Time (s)': time_axis, 'ECG': ecg_flat})
        df.to_csv('x_ecg_predicted_w_time.csv',index=False)

        # Write to CSV with header
        with open('x_ecg_predicted_w_time.csv', 'rb') as f:
            binary_buffer = io.BytesIO(f.read())
        
        # Save the ECG data as a single column in the CSV file
        # Assuming x_ecg has shape (1, 512), we take the first row and reshape it to (512, 1)
        return send_file(
            binary_buffer,
            mimetype='text/txt',
            as_attachment=True,
            download_name='ecg_data.csv'
        )
        
    except Exception as e:
        return f"Error processing file: {str(e)}", 500

# Run the Flask app
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)