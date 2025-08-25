#include <MAX3010x.h>
#include "filters.h"
#include "Arduino_BMI270_BMM150.h"
#include <Arduino_HS300x.h>
#include <Arduino_LPS22HB.h>
#include <ArduinoBLE.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels

// Declaration for an SSD1306 display connected to I2C (SDA, SCL pins)
// The pins for I2C are defined by the Wire-library. 
// On an arduino UNO:       A4(SDA), A5(SCL)
// On an arduino MEGA 2560: 20(SDA), 21(SCL)
// On an arduino LEONARDO:   2(SDA),  3(SCL), ...
#define OLED_RESET     -1 // Reset pin # (or -1 if sharing Arduino reset pin)
#define SCREEN_ADDRESS 0x3C /// for my screen the I2C address is 0x3C, don't know why
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);


/*
  -60000 --> Accelerometer
  -50000 --> PPG
  -30000 --> Bpm
  -20000 --> SpO2
  -15000 --> Humidity
  -10000 --> Temperature
  -70000 --> Pressure
*/

// Add these constants at the top with other defines
const int BLE_PACKET_SIZE = 240; // Reduced packet size for reliable transmission
const int HEADER_SIZE = 4; // 4 bytes for identifier, 4 bytes for sequence number

// Add these global variables
int current_transmission_type = 0; // 0=none, 1=accel, 2=ppg
int current_sequence_number = 0;
int transmission_in_progress = false;


// (DID NOT WORK) set to true if you want to see the PPG on the Serial Plotter
const bool plot = false;

// Sensor (adjust to your sensor type)
MAX30102 sensor;
const auto kSamplingRate = sensor.SAMPLING_RATE_400SPS;
const float kSamplingFrequency = 400.0;

// Finger Detection Threshold and Cooldown
const unsigned long kFingerThreshold = 10000;
const unsigned int kFingerCooldownMs = 500;

// Edge Detection Threshold (decrease for MAX30100)
const float kEdgeThreshold = -2000.0;

// Filters
const float kLowPassCutoff = 5.0;
const float kHighPassCutoff = 0.5;

// rate of reading data (accel)
const float kIMU_rate = 100.0;


// Averaging
const bool kEnableAveraging = true;
const int kAveragingSamples = 10; // might increase averaging samples to prevent the big change
const int kSampleThreshold = 10;

// DEBUG flag
#define DEBUG 1  // Enable debugging

// BLE UUID definitions
const char* serviceUuid = "12345678-1234-5678-1234-56789abcdef0";
const char* sensorCharacteristicUuid = "abcdefab-1234-5678-1234-56789abcdef0";
const char* controlCharacteristicUuid = "abcdefab-1234-5678-1234-56789abcdef1";

// Create BLE service and characteristics
BLEService sensorService(serviceUuid);
BLECharacteristic sensorCharacteristic(sensorCharacteristicUuid, BLERead | BLENotify, BLE_PACKET_SIZE); // 4 bytes for float
BLEByteCharacteristic controlCharacteristic(controlCharacteristicUuid, BLEWriteWithoutResponse);

bool startSending = false;

void setup() {
  Serial.begin(9600);
  //while (!Serial);
  Serial.println("Started");


  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Don't proceed, loop forever
  }
  // Show initial display buffer contents on the screen --
  // the library initializes this with an Adafruit splash screen.
  display.display();
  delay(2000); // Pause for 2 seconds

  display.clearDisplay();

  display.setTextSize(2);             // Normal 1:1 pixel scale
  display.setTextColor(SSD1306_WHITE);        // Draw white text
  display.setCursor(0,0);             // Start at top-left corner
  display.println(F("Awaiting"));
  display.println(F("Connection"));

  //display.setTextColor(SSD1306_BLACK, SSD1306_WHITE); // Draw 'inverse' text
  //display.println(3.141592);

  display.display();
  delay(2000);

  if(sensor.begin() && sensor.setSamplingRate(kSamplingRate)) { 
    Serial.println("Sensor initialized");
  }
  else {
    Serial.println("Sensor not found");  
    while(1);
  }

  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1);
  }

  Serial.print("Accelerometer sample rate = ");
  Serial.print(IMU.accelerationSampleRate());
  Serial.println(" Hz");
  Serial.println();

  if (!HS300x.begin()) {
    Serial.println("Failed to initialize humidity temperature sensor!");
    while (1);
  }

  if (!BARO.begin()) {
    Serial.println("Failed to initialize pressure sensor!");
    while (1);
  }
  // Initialize BLE
  if (!BLE.begin()) {
    Serial.println("Starting BLE failed!");
    while (1);
  }
  //BLE.setMaxMtu(128);


  // Set BLE device properties
  BLE.setLocalName("ArduinoNanoBLE");
  BLE.setAdvertisedService(sensorService);
  
  // Add characteristics to the service
  sensorService.addCharacteristic(sensorCharacteristic);
  sensorService.addCharacteristic(controlCharacteristic);
  BLE.addService(sensorService);
  
  // Initialize with empty value
  uint8_t initialValue[4] = {0, 0, 0, 0};
  sensorCharacteristic.writeValue(initialValue, 4);
  
  // Start advertising
  BLE.advertise();
  if (DEBUG) Serial.println("BLE Device is now advertising with sensor service.");
  
  String address = BLE.address();
  Serial.print("Local address is: ");
  Serial.println(address);
}
// Replace the large data sending blocks with this function
void sendDataInPackets(int data_type, float* data_array, int data_length) {
  if (transmission_in_progress) return;
  transmission_in_progress = true;
  
  current_transmission_type = data_type;
  current_sequence_number = 0;
  
  // Calculate total packets needed
  int total_packets = ceil((float)(data_length * sizeof(float)) / (BLE_PACKET_SIZE - HEADER_SIZE));
  
  for (int i = 0; i < total_packets; i++) {
    // Create header
    uint8_t header[HEADER_SIZE];
    memcpy(header, &data_type, 4);
    //memcpy(header + 4, &i, 4); // sequence number

    // Print on Serial
    Serial.print("Sequence Number = ");
    Serial.println(i);

    // Calculate chunk size
    int chunk_start = i * (BLE_PACKET_SIZE - HEADER_SIZE) / sizeof(float);
    int chunk_end = min(data_length, chunk_start + (BLE_PACKET_SIZE - HEADER_SIZE) / sizeof(float));
    int chunk_size = (chunk_end - chunk_start) * sizeof(float);
    
    uint8_t packet[BLE_PACKET_SIZE];
    memcpy(packet, header, HEADER_SIZE);
    memcpy(packet + HEADER_SIZE, &data_array[chunk_start], chunk_size);
    

    // Send packet
    sensorCharacteristic.writeValue(packet, HEADER_SIZE + chunk_size);
    //sensorCharacteristic.notify();
    
    // Small delay between packets
    //delay(10); // no need for this delay anymore
    
    // Check if still connected
    if (!BLE.central().connected()) {
      transmission_in_progress = false;
      return;
    }
  }
  
  transmission_in_progress = false;
}
// Filter Instances
LowPassFilter low_pass_filter_red(kLowPassCutoff, kSamplingFrequency);
LowPassFilter low_pass_filter_ir(kLowPassCutoff, kSamplingFrequency);
HighPassFilter high_pass_filter(kHighPassCutoff, kSamplingFrequency);
Differentiator differentiator(kSamplingFrequency);
MovingAverageFilter<kAveragingSamples> averager_bpm;
MovingAverageFilter<kAveragingSamples> averager_r;
MovingAverageFilter<kAveragingSamples> averager_spo2;

LowPassFilter LPF_accel(kLowPassCutoff, kIMU_rate);

// Statistic for pulse oximetry
MinMaxAvgStatistic stat_red;
MinMaxAvgStatistic stat_ir;

// R value to SpO2 calibration factors
// See https://www.maximintegrated.com/en/design/technical-documents/app-notes/6/6845.html
float kSpO2_A = 1.5958422;
float kSpO2_B = -34.6596622;
float kSpO2_C = 112.6898759;

// Timestamp of the last heartbeat
long last_heartbeat = 0;

// Timestamp for finger detection
long finger_timestamp = 0;
bool finger_detected = false;

// Last diff to detect zero crossing
float last_diff = NAN;
bool crossed = false;
long crossed_time = 0;

float x, y, z;
float magnitude;


float temperature;
float humidity;
float pressure;

const int ppg_data_size = 55; // might have to lower kSamplingRate to fit more samples, it is being resized to 128Hz anyways
int ppg_pt = 0;
float ppg_data_values[ppg_data_size];
//int TimeArray[400];
int time_beginning = millis();

const int accel_data_size = 55; // might have to lower kSamplingRate to fit more samples, it is being resized to 128Hz anyways
int accel_pt = 0;
float accel_data_values[accel_data_size];

uint8_t fourthsample = 0;

void loop() {
  BLEDevice central = BLE.central();

  if(central){
    Serial.print("Connected to central: ");
    Serial.println(central.address());
    startSending = false;

    display.clearDisplay();
    display.setCursor(0,0);
    display.println("Connected");
    display.display();

    delay(1000);

  
    while(central.connected()){
      //BLE.poll(); // Important for maintaining BLE connection
      
      if (controlCharacteristic.written()) {
        byte command = controlCharacteristic.value();
        if (command == 1) {
          startSending = true;
          Serial.println("Start command received");
          display.clearDisplay();
          display.setCursor(0,0);
          display.println("Connected");
          display.println("Sending");
          display.println("Data");
          display.display();
        } else {
          startSending = false;
          Serial.println("Stop command received");
          display.clearDisplay();
          display.setCursor(0,0);
          display.println("Connected");
          display.println("Data");
          display.println("Stopped");
          display.display();
        }
      }

      if (startSending){
        if (0/* IMU.accelerationAvailable() */) {
          IMU.readAcceleration(x, y, z);

          /*      Applying LPF to accel data      */
          x = LPF_accel.process(x);
          y = LPF_accel.process(y);
          z = LPF_accel.process(z);

          /*        calculating magnitude         */
          magnitude = sqrt(x*x + y*y + z*z);
          
          

          if (accel_pt < accel_data_size){
            /*        Send accelerometer data       */
            Serial.print("Time: ");
            Serial.print(millis());
            Serial.print(",\t");
            Serial.print("Accelerometer: ");
            Serial.println(magnitude);
            
            accel_data_values[accel_pt] = magnitude;
            accel_pt++;
          }
          /* else{
            int character = -60000;
            uint8_t byte_char[4];
            memcpy(byte_char, &character, 4);
            sensorCharacteristic.writeValue(byte_char, 4);
            uint8_t bytes[20000];
            memcpy(bytes, accel_data_values, 20000);
            sensorCharacteristic.writeValue(bytes, 20000);
            //Serial.println("ppg_data_values is full and ready to transmit");
            accel_pt = 0;
            // Send Data in BLE here
          } */
          // Modify the data sending sections to use this function:
          // Replace the accel data sending block with:
          if (accel_pt >= accel_data_size) {
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("10 seconds of Accel data sent");
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("******************************");
            //sendDataInPackets(-60000, accel_data_values, accel_data_size);
            accel_pt = 0;
          }
        }
        auto sample = sensor.readSample(1000); // reading for 1 second
        fourthsample++; // might change to eightsample later on for better performance
        if(fourthsample >= 4){
          IMU.readAcceleration(x, y, z);
          magnitude = sqrt(x*x + y*y + z*z);
          x = LPF_accel.process(x);
          y = LPF_accel.process(y);
          z = LPF_accel.process(z); 
          magnitude = LPF_accel.process(magnitude);
          if (accel_pt < accel_data_size){
            Serial.print("Time: ");
            Serial.print(millis());
            Serial.print(",\t");
            Serial.print("Accelerometer: ");
            Serial.println(magnitude);
            accel_data_values[accel_pt] = magnitude;
            accel_pt++;
        }
        if (accel_pt >= accel_data_size) {
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("10 seconds of Accel data sent");
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("******************************");
            sendDataInPackets(-60000, accel_data_values, accel_data_size);
            accel_pt = 0;
          }
          fourthsample = 0;
        }
        float current_value_red = sample.red;
        float current_value_ir = sample.ir;


        // Detect Finger using raw sensor value
        if(sample.red > kFingerThreshold) {
          if(millis() - finger_timestamp > kFingerCooldownMs) {
            finger_detected = true;
          }
        }
        else {
          // Reset values if the finger is removed
          differentiator.reset();
          averager_bpm.reset();
          averager_r.reset();
          averager_spo2.reset();
          low_pass_filter_red.reset();
          low_pass_filter_ir.reset();
          high_pass_filter.reset();
          stat_red.reset();
          stat_ir.reset();
          
          finger_detected = false;
          finger_timestamp = millis();
        }

        if(finger_detected) {
          current_value_red = low_pass_filter_red.process(current_value_red);
          current_value_ir = low_pass_filter_ir.process(current_value_ir);

          // Statistics for pulse oximetry
          stat_red.process(current_value_red);
          stat_ir.process(current_value_ir);

          // Heart beat detection using value for red LED
          float current_value = high_pass_filter.process(current_value_red);
          float current_diff = differentiator.process(current_value);
          /* int character = -50000;
          uint8_t byte_char[4];
          memcpy(byte_char, &character, 4);
          sensorCharacteristic.writeValue(byte_char, 4);
          uint8_t bytes[4];
          memcpy(bytes, &current_value, 4);
          sensorCharacteristic.writeValue(bytes, 4); */
          if (ppg_pt < ppg_data_size){
            
            Serial.print("Time: ");
            Serial.print(millis());
            Serial.print(",\t");
            Serial.print("PPG value: ");
            Serial.println(current_value);            
            
            Serial.print("ppg_pt =");
            Serial.print(ppg_pt);
            ppg_data_values[ppg_pt] = current_value;
            ppg_pt++;
            
          }
          /* else{
            //Serial.println("ppg_data_values is full and ready to transmit");
            int character = -50000;
            uint8_t byte_char[4];
            memcpy(byte_char, &character, 4);
            sensorCharacteristic.writeValue(byte_char, 4);
            uint32_t bytes[4];
            memcpy(bytes, ppg_data_values, 16);
            sensorCharacteristic.writeValue(bytes, 16);
            ppg_pt = 0;
            // Send Data here in BLE here
          } */
          // Replace the ppg data sending block with:
          if (ppg_pt >= ppg_data_size) {
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("10 seconds of PPG data sent");
            Serial.println("******************************");
            Serial.println("******************************");
            Serial.println("******************************");
            sendDataInPackets(-50000, ppg_data_values, ppg_data_size);
            ppg_pt = 0;
          }
          // delay(10);
          // Valid values?
          if(!isnan(current_diff) && !isnan(last_diff)) {
            
            // Detect Heartbeat - Zero-Crossing
            if(last_diff > 0 && current_diff < 0) {
              crossed = true;
              crossed_time = millis();
            }
            
            if(current_diff > 0) {
              crossed = false;
            }
        
            // Detect Heartbeat - Falling Edge Threshold
            if(crossed && current_diff < kEdgeThreshold) {
              if(last_heartbeat != 0 && crossed_time - last_heartbeat > 300) {
                // Show Results
                int bpm = 60000/(crossed_time - last_heartbeat);
                float rred = (stat_red.maximum()-stat_red.minimum())/stat_red.average();
                float rir = (stat_ir.maximum()-stat_ir.minimum())/stat_ir.average();
                float r = rred/rir;
                float spo2 = kSpO2_A * r * r + kSpO2_B * r + kSpO2_C;
                if(spo2>100) spo2 = 100;
                if(bpm > 50 && bpm < 250 /* && spo2 <= 100 */) {
                  if(plot){
                    Serial.println(current_value_ir);
                  }
                  else{
                    // Average?
                  if(kEnableAveraging) {
                    int average_bpm = averager_bpm.process(bpm); // to remove the 40 ms delay, I am thinking to put the sending outside, beside the ppg sending, and define average_bpm as global variable
                    int average_r = averager_r.process(r);
                    int average_spo2 = averager_spo2.process(spo2);
        
                    // Show if enough samples have been collected
                    if(averager_bpm.count() >= kSampleThreshold) {
                      Serial.print("Time (ms): ");
                      Serial.println(millis()); 
                      Serial.print("Heart Rate (avg, bpm): ");
                      Serial.println(average_bpm);
                      Serial.print("R-Value (avg): ");
                      Serial.println(average_r);  
                      Serial.print("SpO2 (avg, %): ");
                      Serial.println(average_spo2);

                      //humidity    = HS300x.readHumidity();
                      temperature = sensor.readTemperature();
                      //pressure = BARO.readPressure();

                      uint8_t packet[24];
                      int data_type;
                      
                      data_type = -30000;
                      memcpy(packet, &data_type, 4);
                      memcpy(packet + 4, &average_bpm, 4);
                      data_type = -20000;
                      memcpy(packet + 8, &data_type, 4);
                      memcpy(packet + 12, &average_spo2, 4);
                      data_type = -10000;
                      memcpy(packet + 16, &data_type, 4);
                      memcpy(packet + 20, &temperature, 4);


                      sensorCharacteristic.writeValue(packet, 24);

                      /* float packet_temp[5];
                      data_type = -30000;
                      memcpy(packet_temp, &average_bpm, 4);
                      data_type = -20000;
                      memcpy(packet_temp + 4, &data_type, 4);
                      memcpy(packet_temp + 8, &average_spo2, 4);
                      data_type = -10000;
                      memcpy(packet_temp + 12, &data_type, 4);
                      memcpy(packet_temp + 16, &temperature, 4);

                      sendDataInPackets(-30000, packet_temp, 5); */

                      /* character = -20000;
                      memcpy(byte_char, &character, 4);
                      sensorCharacteristic.writeValue(byte_char, 4);
                      memcpy(bytes, &average_spo2, 4);
                      sensorCharacteristic.writeValue(bytes, 4);

                      character = -10000;
                      memcpy(byte_char, &character, 4);
                      sensorCharacteristic.writeValue(byte_char, 4);
                      memcpy(bytes, &temperature, 4);
                      sensorCharacteristic.writeValue(bytes, 4); */


                      /*  character = -15000;
                      memcpy(byte_char, &character, 4);
                      sensorCharacteristic.writeValue(byte_char, 4);
                      memcpy(bytes, &humidity, 4);
                      sensorCharacteristic.writeValue(bytes, 4);

                      character = -10000;
                      memcpy(byte_char, &character, 4);
                      sensorCharacteristic.writeValue(byte_char, 4);
                      memcpy(bytes, &temperature, 4);
                      sensorCharacteristic.writeValue(bytes, 4);

                       character = -70000;
                      memcpy(byte_char, &character, 4);
                      sensorCharacteristic.writeValue(byte_char, 4);
                      memcpy(bytes, &pressure, 4);
                      sensorCharacteristic.writeValue(bytes, 4);

                      Serial.print("Temperature = ");
                      Serial.print(temperature);
                      Serial.println(" °C");

                      Serial.print("Humidity    = ");
                      Serial.print(humidity);
                      Serial.println(" %");

                      Serial.print("Pressure = ");
                      Serial.print(pressure);
                      Serial.println(" kPa"); */

                      /* display.clearDisplay();
                      display.setCursor(0,0);
                      display.print("bpm:");
                      display.println(average_bpm);  
                      display.print("SpO2:");
                      display.print(average_spo2);
                      display.println(" %");
                      display.print("T:");
                      display.print(temperature);
                      display.println("C");
                      display.print("a:");
                      display.print(magnitude);
                      display.println("g");
                      display.display(); */
                    }
                  }
                  else {
                      Serial.print("Time (ms): ");
                      Serial.println(millis()); 
                      Serial.print("Heart Rate (current, bpm): ");
                      Serial.println(bpm);  
                      Serial.print("R-Value (current): ");
                      Serial.println(r);
                      Serial.print("SpO2 (current, %): ");
                      Serial.println(spo2);  
                  }
                  }
                }

                // Reset statistic
                stat_red.reset();
                stat_ir.reset();
              }
        
              crossed = false;
              last_heartbeat = crossed_time;
            }
          }

          last_diff = current_diff;
        }
      }
      //delay(10); this caused the slower sensor readings, might be important for BLE though
    }

    Serial.println("Central disconnected");
    display.clearDisplay();
    display.setCursor(0,0);
    display.println("Disconnected");
    display.display();
    startSending = false; // Reset sending flag when disconnected
    accel_pt = 0; // Reset data pointer
    ppg_pt = 0;
    BLE.advertise();
  }
}
