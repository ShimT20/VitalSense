# VitalSense: Real-Time Sleep Apnea Detection Smart Band
VitalSense is a wearable smart band designed for the detection of sleep apnea using multi-sensor data fusion and machine learning. It monitors physiological signals such as PPG and SpO₂ to identify apnea events during sleep.

## Features
- **Health monitoring:** PPG, HR, SpO₂ and temperature
- **PPG-to-ECG conversion** using CardioGAN
- **Machine learning-based apnea detection** (Random Forest: 90% accuracy)
- **Bluetooth Low Energy** (BLE) data transmission
- **Mobile app** for real-time feedback and historical data
- **Low-power design:** ~10 hours of continuous operation

## Hardware
- Arduino Nano 33 BLE Sense Rev2
- MAX30102 PPG sensor
- 3.7V Li-Po battery (1100 mAh)

## Application 
- Flutter framework  
- fastAPI and flask (For AI model calls)

## Performance 
- Accuracy: 90% (Random Forest)
- Battery Life: ~10 hours
- BLE Latency: ~10 ms

## Awards
**First Place** — Made in CCI (Best Project from the Department)  
_Sponsored_ by Binance  
This project was awarded top honors in the College of Computing & Informatics competition for its innovation, technical excellence, and real-world impact.

## Contributors
- Dr. Kais Belwafi
- Omar Naqaweh
- Saad Mahfood
- Ali Johar

## References
- Apnea-ECG Database
  * https://www.physionet.org/content/apnea-ecg/1.0.0/
- CardioGAN
  * https://github.com/pritamqu/ppg2ecg-cardiogan?tab=readme-ov-file
