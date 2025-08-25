import 'dart:async';
import 'dart:typed_data';
import 'package:breathe_easy/csvConvertion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
//import 'package:flutter_zxing/flutter_zxing.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'scanning_model.dart';
export 'scanning_model.dart';

//import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
//import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';



// To save the file in the device
class FileStorage {
  static Future<String> getExternalDocumentPath() async {
    // To check whether permission is given for this app or not.
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      // If not we will ask for permission first
      await Permission.storage.request();
    }
    Directory _directory = Directory("");
    if (Platform.isAndroid) {
      // Redirects it to download folder in android
      _directory = Directory("/storage/emulated/0/Download");
    } else {
      _directory = await getApplicationDocumentsDirectory();
    }

    final exPath = _directory.path;
    debugPrint("Saved Path: $exPath");
    await Directory(exPath).create(recursive: true);
    return exPath;
  }

  static Future<String> get _localPath async {
    // final directory = await getApplicationDocumentsDirectory();
    // return directory.path;
    // To get the external path from device of download folder
    final String directory = await getExternalDocumentPath();
    return directory;
  }

  static Future<File> writeCounter(String bytes, String name) async {
    final path = await _localPath;
    // Create a file for the path of
    // device and file name with extension
    File file = File('$path/$name');
    ;
    print("Save file");

    // Write the data in the file you have created
    return file.writeAsString(bytes);
  }
}

/// Singleton BLE service that manages scanning, connection, and data reception.
class BleService {
  // Add ValueNotifiers for sensor data
  final ValueNotifier<int?> bpmNotifier = ValueNotifier(null);
  final ValueNotifier<int?> spo2Notifier = ValueNotifier(null);
  final ValueNotifier<double?> temperatureNotifier = ValueNotifier(null);
  final ValueNotifier<double?> humidityNotifier = ValueNotifier(null);
  final ValueNotifier<double?> pressureNotifier = ValueNotifier(null);
  final ValueNotifier<int> ppgDataLengthNotifier = ValueNotifier(0);
  final ValueNotifier<int> accelDataLengthNotifier = ValueNotifier(0);
  final ValueNotifier<int> tempDataLengthNotifier = ValueNotifier(0);
  final ValueNotifier<int> bpmDataLengthNotifier = ValueNotifier(0);
  final ValueNotifier<int> spo2DataLengthNotifier = ValueNotifier(0);

  final ValueNotifier<int> spo2ApneaIndex = ValueNotifier(0);
  List<double> _spo2Data = [];
  // Data processing state
  //int? _lastIdentifier;
  //int _lastSeq = -1;
  final Map<int, List<double>> _dataBuffers = {
    -60000: [], // Accelerometer
    -50000:
        [], // PPG // for multiplexing just separate the values and then insert them, ez
    -10000: [], // temperature
  };

  final Map<int, List<int>> _sensorBuffers = {
    -30000: [], // Bpm
    -20000: [], // SpO2
  };

  //List<double> _apneaIndices = [];
  //final ValueNotifier<int> apneaIndicesNotifier = ValueNotifier(0);

  static final BleService instance = BleService._internal();
  BleService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  /// Stores sensor values to later write into CSV
  final List<String> recordedData = [];
  // UUIDs (must match your Arduino code)
  final Uuid smartBandServiceUuid =
      Uuid.parse("12345678-1234-5678-1234-56789abcdef0");
  final Uuid sensorDataCharacteristicUuid =
      Uuid.parse("abcdefab-1234-5678-1234-56789abcdef0");
  final Uuid controlCharacteristicUuid = Uuid.parse(
      "abcdefab-1234-5678-1234-56789abcdef1"); // New control characteristic

  // Lists for discovered and connected devices.
  final List<DiscoveredDevice> discoveredDevices = [];
  final List<DiscoveredDevice> connectedDevices = [];

  // ValueNotifiers for UI updates.
  final ValueNotifier<List<DiscoveredDevice>> discoveredNotifier =
      ValueNotifier([]);
  final ValueNotifier<List<DiscoveredDevice>> connectedNotifier =
      ValueNotifier([]);
  final ValueNotifier<String> sensorDataNotifier = ValueNotifier("");

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  StreamSubscription<List<int>>? _sensorDataSubscription;

  // CSV helper instance
  final CsvHelper csvHelper = CsvHelper();

  /// Start scanning for devices advertising the smart band service.
  void startScan() {
    if (_scanSubscription != null) return;
    discoveredDevices.clear();
    discoveredNotifier.value = [];
    _scanSubscription = _ble
        .scanForDevices(withServices: [smartBandServiceUuid]).listen((device) {
      if (!discoveredDevices.any((d) => d.id == device.id)) {
        discoveredDevices.add(device);
        discoveredNotifier.value = List.from(discoveredDevices);
        debugPrint("Discovered device: ${device.name} (${device.id})");
      }
    }, onError: (error) {
      debugPrint("Scan error: $error");
    });
  }

  /// Stop scanning.
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Connect to a device and subscribe to sensor data.
  void connectToDevice(DiscoveredDevice device) {
    final subscription =
        _ble.connectToDevice(id: device.id).listen((connectionState) {
      debugPrint(
          "Connection state for ${device.name}: ${connectionState.connectionState}");
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        if (!connectedDevices.any((d) => d.id == device.id)) {
          connectedDevices.add(device);
          connectedNotifier.value = List.from(connectedDevices);
          final characteristic = QualifiedCharacteristic(
            serviceId: smartBandServiceUuid,
            characteristicId: sensorDataCharacteristicUuid,
            deviceId: device.id,
          );
          Future.delayed(const Duration(milliseconds: 1000), () {
            _ble.readCharacteristic(characteristic).then((data) {
              debugPrint("Initial read data: $data, length: ${data.length}");
              if (data.length >= 4) {
                final int sensorValue =
                    ByteData.sublistView(Uint8List.fromList(data))
                        .getUint32(0, Endian.little);
                sensorDataNotifier.value = sensorValue.toString();
                debugPrint("Initial sensor data read: $sensorValue");
              } else {
                debugPrint("Initial read: Data too short: $data");
              }
            }).catchError((error) {
              debugPrint("Error reading initial sensor data: $error");
            });
          });
          subscribeToSensorData(device);
        }
      } else if (connectionState.connectionState ==
          DeviceConnectionState.disconnected) {
        debugPrint("Device ${device.name} disconnected");
        connectedDevices.removeWhere((d) => d.id == device.id);
        connectedNotifier.value = List.from(connectedDevices);
        _sensorDataSubscription?.cancel();
        _sensorDataSubscription = null;
        _connectionSubscriptions.remove(device.id);
      }
    }, onError: (error) {
      debugPrint("Connection error for ${device.name}: $error");
    });
    _connectionSubscriptions[device.id] = subscription;
  }

  /// Subscribe to sensor data notifications from the connected device.
  void subscribeToSensorData(DiscoveredDevice device) {
    final characteristic = QualifiedCharacteristic(
      serviceId: smartBandServiceUuid,
      characteristicId: sensorDataCharacteristicUuid,
      deviceId: device.id,
    );
    _ble.subscribeToCharacteristic(characteristic).listen((data) async {
      debugPrint("Raw sensor data received: $data, length: ${data.length}");

      if (data.length == 24) {
        for (int i = 0; i < data.length; i += 8) {
          // Handle single value or identifier
          ByteData byteData = ByteData.sublistView(Uint8List.fromList(data));
          int value = byteData.getInt32(i, Endian.little);
          switch (value) {
            case -30000:
              int bpm_temp = byteData.getInt32(i + 4, Endian.little);
              bpmNotifier.value = bpm_temp;
              _sensorBuffers[value]!.addAll([bpm_temp]);
              bpmDataLengthNotifier.value = _sensorBuffers[value]!.length;
              break;
            case -20000:
              int spo2_temp = byteData.getInt32(i + 4, Endian.little);
              spo2Notifier.value = spo2_temp;
              _sensorBuffers[value]!.addAll([spo2_temp]);
              _spo2Data.addAll([spo2_temp.toDouble()]);
              spo2DataLengthNotifier.value = _sensorBuffers[value]!.length;
              break;
            case -15000:
              humidityNotifier.value =
                  byteData.getFloat32(i + 4, Endian.little);
              break;
            case -10000:
              double temperature_temp =
                  byteData.getFloat32(i + 4, Endian.little);
              temperatureNotifier.value = temperature_temp;
              _dataBuffers[value]!.addAll([temperature_temp]);
              tempDataLengthNotifier.value = _dataBuffers[value]!.length;
              break;
            case -70000:
              pressureNotifier.value = byteData.getFloat32(i, Endian.little);
              break;
          }
        }
        /* // Handle single value or identifier
          ByteData byteData = ByteData.sublistView(Uint8List.fromList(data));
          int value = byteData.getInt32(0, Endian.little);

          if ([-30000, -20000, -15000, -10000, -70000].contains(value)) {
          _lastIdentifier = value;
          } else if (_lastIdentifier != null) {
            switch (_lastIdentifier) {
              case -30000:
                bpmNotifier.value = value;
                _sensorBuffers[_lastIdentifier]!.addAll([value]);
                bpmDataLengthNotifier.value = _sensorBuffers[_lastIdentifier]!.length;
                break;
              case -20000:
                spo2Notifier.value = value;
                _sensorBuffers[_lastIdentifier]!.addAll([value]);
                spo2DataLengthNotifier.value = _sensorBuffers[_lastIdentifier]!.length;
                break;
              case -15000:
                humidityNotifier.value = byteData.getFloat32(0, Endian.little);
                break;
              case -10000:
                double temperature_temp = byteData.getFloat32(0, Endian.little);
                temperatureNotifier.value = temperature_temp;
                _dataBuffers[_lastIdentifier]!.addAll([temperature_temp]);
                tempDataLengthNotifier.value = _dataBuffers[_lastIdentifier]!.length;
                break;
              case -70000:
                pressureNotifier.value = byteData.getFloat32(0, Endian.little);
                break;
            }
            _lastIdentifier = null;
          } */
      } else {
        // Handle large data packet
        ByteData byteData = ByteData.sublistView(Uint8List.fromList(data));
        int dataType = byteData.getInt32(0, Endian.little);
        //int sequenceNumber = byteData.getInt32(4, Endian.little);

        //if (true/* sequenceNumber > _lastSeq && !(sequenceNumber == 166 && _lastSeq == -1) */) {
        List<double> dataChunk = [];
        for (int i = 4; i < data.length; i += 4) {
          dataChunk.add(byteData.getFloat32(i, Endian.little));
        }
        debugPrint("The datachunk received is:  $dataChunk");
        if (_dataBuffers.containsKey(dataType)) {
          /* if (sequenceNumber == 0) {
              _dataBuffers[dataType] = dataChunk;
            } else { */
          _dataBuffers[dataType]!.addAll(dataChunk);
          //}
        }

        // Update data length notifiers
        if (dataType == -50000) {
          ppgDataLengthNotifier.value = _dataBuffers[dataType]!.length;
        } else if (dataType == -60000) {
          accelDataLengthNotifier.value = _dataBuffers[dataType]!.length;
        }
        debugPrint(
            "The new length of ppgData is:  ${ppgDataLengthNotifier.value}");

        /* _lastSeq = sequenceNumber;
          if (sequenceNumber >= 166) {
            _lastSeq = -1;
          } */
        //}
      }
    }, onError: (error) {
      debugPrint("Sensor data error: $error");
    });
  }
  Map<String, dynamic> detectSleepApneaAdvanced(
    List<double> spo2, {
    double samplingRate = 1.5,
    double dropThresholdPercent = 6.0,
    double baseline = 95.0,
    int minDesaturationDurationSec = 20,
  }) {
    List<int> desaturationEvents = [];

    bool inDesaturation = false;
    int desaturationStart = -1;
    double threshold = baseline * (1 - dropThresholdPercent / 100);
    int minDurationSamples = (minDesaturationDurationSec * samplingRate).toInt();

    for (int i = 0; i < spo2.length; i++) {
      if (spo2[i] < threshold) {
        if (!inDesaturation) {
          inDesaturation = true;
          desaturationStart = i;
        }
      } else {
        if (inDesaturation) {
          int duration = i - desaturationStart;
          if (duration >= minDurationSamples) {
            desaturationEvents.add(desaturationStart);
          }
          inDesaturation = false;
        }
      }
    }
    
    // Handle case if signal ends during desaturation
    if (inDesaturation && (spo2.length - desaturationStart) >= minDurationSamples) {
      desaturationEvents.add(desaturationStart);
    }

    double totalSeconds = spo2.length / samplingRate;
    double odi = (desaturationEvents.length / totalSeconds) * 3600;

    String severity;
    if (odi < 5) {
      severity = 'Normal';
    } else if (odi < 15) {
      severity = 'Mild';
    } else if (odi < 30) {
      severity = 'Moderate';
    } else {
      severity = 'Severe';
    }

    spo2ApneaIndex.value = odi.toInt();

    return {
      'ODI': odi,
      'Severity': severity,
      'Events': desaturationEvents.length,
      'EventIndices': desaturationEvents,
};
}


  /// Sends the start command (a value of 1) to the connected device.
  Future<void> sendStartCommand(DiscoveredDevice device) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: smartBandServiceUuid,
      characteristicId: controlCharacteristicUuid,
      deviceId: device.id,
    );
    try {
      await _ble.writeCharacteristicWithoutResponse(characteristic, value: [1]);
      int mtu = await _ble.requestMtu(deviceId: device.id, mtu: 240);

      debugPrint("Sent start command to device ${device.name}");
      debugPrint("The returned negotiated mtu: $mtu");
    } catch (error) {
      debugPrint("Error sending start command: $error");
    }
  }

  Future<void> resetData() async {
    bpmDataLengthNotifier.value = 0;
    bpmNotifier.value = 0;
    spo2Notifier.value = 0;
    temperatureNotifier.value = 0;
    humidityNotifier.value = 0;
    pressureNotifier.value = 0;
    ppgDataLengthNotifier.value = 0;
    accelDataLengthNotifier.value = 0;
    tempDataLengthNotifier.value = 0;
    bpmDataLengthNotifier.value = 0;
    spo2DataLengthNotifier.value = 0;
    spo2ApneaIndex.value = 0;
    _dataBuffers[-60000] = [];
    _dataBuffers[-50000] = [];
    _dataBuffers[-10000] = [];
    _sensorBuffers[-30000] = [];
    _sensorBuffers[-20000] = [];
  }

  /// Sends the stop command (a value of 0) to the connected device.
  Future<void> sendStopCommand(DiscoveredDevice device) async {
    final characteristic = QualifiedCharacteristic(
      serviceId: smartBandServiceUuid,
      characteristicId:
          controlCharacteristicUuid, // Must match Arduino's write characteristic
      deviceId: device.id,
    );

    try {
      await _ble.writeCharacteristicWithoutResponse(
        characteristic,
        value: [0], // Sending byte 0 (STOP command)
      );
      debugPrint("Sent stop command to device ${device.name}");
    } catch (error) {
      debugPrint("Error sending stop command: $error");
      rethrow; // Optional: propagate error to UI
    }
    FileStorage.writeCounter(
        removeFirstAndLastCharacter(_dataBuffers[-50000].toString()),
        "ppgData.csv");
    debugPrint("ppgData.csv successfully saved");
    FileStorage.writeCounter(
        removeFirstAndLastCharacter(_sensorBuffers[-20000].toString()),
        "spo2Data.csv");
    debugPrint("spo2Data.csv successfully saved");

    
    detectSleepApneaAdvanced(_spo2Data);
  }

  String removeFirstAndLastCharacter(String input) {
    if (input.isEmpty) {
      return input; // Return the input string if it's already empty
    }

    String result = input.substring(1, input.length - 1);

    result = result.replaceAll(", ", "\n");
    // Use substring to get a new string excluding the first and last character
    return result;
  }

  /// Disconnect a specific device.
  void disconnectDevice(DiscoveredDevice device) {
    _connectionSubscriptions[device.id]?.cancel();
    _connectionSubscriptions.remove(device.id);
    connectedDevices.removeWhere((d) => d.id == device.id);
    connectedNotifier.value = List.from(connectedDevices);
    _sensorDataSubscription?.cancel();
    _sensorDataSubscription = null;
  }

  /// Disconnect all connected devices.
  void disconnectAll() {
    for (var subscription in _connectionSubscriptions.values) {
      subscription.cancel();
    }
    _connectionSubscriptions.clear();
    connectedDevices.clear();
    connectedNotifier.value = List.from(connectedDevices);
    _sensorDataSubscription?.cancel();
    _sensorDataSubscription = null;
  }
}

class ScanningWidget extends StatefulWidget {
  const ScanningWidget({super.key});

  @override
  State<ScanningWidget> createState() => _ScanningWidgetState();
}

class _ScanningWidgetState extends State<ScanningWidget> {
  late ScanningModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final BleService _bleService = BleService.instance;
  final CsvHelper csvHelper = CsvHelper();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ScanningModel());
    _bleService.startScan();
  }

  @override
  void dispose() {
    _model.dispose();
    // Optionally stop scanning.
    // _bleService.stopScan();
    super.dispose();
  }

  

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        /*appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Text(
            'Connect your Device',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: 'Inter Tight',
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                ),
          ),
          actions: const [],
          centerTitle: false,
        ),*/
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Top Section: Instructions
              SizedBox(
                width: MediaQuery.sizeOf(context).width,
                height: 200.0,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      24.0, 24.0, 24.0, 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect to Devices',
                        style: FlutterFlowTheme.of(context)
                            .headlineLarge
                            .override(
                              fontFamily: 'Inter Tight',
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Turn on Bluetooth and scan the static QR code on your device to initiate a connection.',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Inter',
                              color: FlutterFlowTheme.of(context).primaryText,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              // Connection Status Section
              Align(
                alignment: AlignmentDirectional.center,
                child: Material(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.9,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Connection Status',
                          style: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .override(
                                fontFamily: 'Inter Tight',
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                        ),
                        ValueListenableBuilder<List<DiscoveredDevice>>(
                          valueListenable: _bleService.connectedNotifier,
                          builder: (context, connectedDevices, child) {
                            if (connectedDevices.isEmpty) {
                              return const Text("No connected devices");
                            }
                            /* return Column(
                              children: connectedDevices.map((device) {
                                return ListTile(
                                  title: Text(device.name),
                                  subtitle: Text(device.id),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _bleService.disconnectDevice(device);
                                    },
                                  ),
                                );
                              }).toList(),
                            ); */
                            // Inside the Connection Status section's ValueListenableBuilder:
                            return Column(
                              children: connectedDevices.map((device) {
                                return Column(
                                  children: [
                                    ListTile(
                                      title: Text(device.name),
                                      subtitle: Text(device.id),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => _bleService
                                            .disconnectDevice(device),
                                      ),
                                    ),
                                    /*Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => _bleService
                                              .sendStartCommand(device),
                                          child: const Text('Start Sending'),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton(
                                          onPressed: () => _bleService
                                              .sendStopCommand(device),
                                          child: const Text('Stop Sending'),
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton(
                                          onPressed: _processPpgFiles,
                                          child:
                                              const Text('Process PPG Files'),
                                        ),
                                        if (_apneaIndices.isNotEmpty) ...[
                                          const SizedBox(height: 20),
                                          const Text('Apnea Indices:',
                                              style: TextStyle(fontSize: 16)),
                                          for (var index in _apneaIndices)
                                            Text('$index',
                                                style: const TextStyle(
                                                    fontSize: 14)),
                                        ],
                                      ],
                                    ),*/
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton(
                                          onPressed: _bleService.resetData,
                                          child: const Text('reset'),
                                        ),
                                      ],
                                    )
                                  ],
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Discovered Devices Section
              Align(
                alignment: AlignmentDirectional.center,
                child: Material(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.9,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Discovered Devices',
                          style: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .override(
                                fontFamily: 'Inter Tight',
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                        ),
                        ValueListenableBuilder<List<DiscoveredDevice>>(
                          valueListenable: _bleService.discoveredNotifier,
                          builder: (context, discoveredDevices, child) {
                            if (discoveredDevices.isEmpty) {
                              return const Text("No devices found");
                            }
                            return Column(
                              children: discoveredDevices.map((device) {
                                return ListTile(
                                  title: Text(device.name),
                                  subtitle: Text(device.id),
                                  onTap: () =>
                                      _bleService.connectToDevice(device),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Troubleshooting Tips Section
              Align(
                alignment: AlignmentDirectional.center,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 10.0),
                  child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.9,
                    padding: const EdgeInsets.all(15.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Color(0xFFEF6C00), size: 24.0),
                            const SizedBox(width: 12.0),
                            Text(
                              'Troubleshooting Tips',
                              style: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .override(
                                    fontFamily: 'Inter',
                                    color: const Color(0xFFEF6C00),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '1. Ensure the smart band is powered on.',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'Inter',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '2. Turn on Bluetooth on your phone.',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'Inter',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          '3. Rescan the QR code if necessary.',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'Inter',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.center,
                child: Material(
                  elevation: 2.0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0)),
                  /*child: Container(
                    width: MediaQuery.sizeOf(context).width * 0.9,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Column(
                      children: [
                        Text('Sensor Data',
                            style: FlutterFlowTheme.of(context).headlineSmall),
                        ValueListenableBuilder<int?>(
                          valueListenable: _bleService.bpmNotifier,
                          builder: (ctx, bpm, _) =>
                              Text('BPM: ${bpm ?? 'N/A'}'),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _bleService.bpmDataLengthNotifier,
                          builder: (ctx, bpmLen, _) =>
                              Text('Bpm Samples: $bpmLen'),
                        ),
                        ValueListenableBuilder<int?>(
                          valueListenable: _bleService.spo2Notifier,
                          builder: (ctx, spo2, _) =>
                              Text('SpO2: ${spo2 ?? 'N/A'}%'),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _bleService.spo2DataLengthNotifier,
                          builder: (ctx, spo2Len, _) =>
                              Text('SpO2 Samples: $spo2Len'),
                        ),
                        ValueListenableBuilder<double?>(
                          valueListenable: _bleService.temperatureNotifier,
                          builder: (ctx, temp, _) => Text(
                              'Temperature: ${temp?.toStringAsFixed(1) ?? 'N/A'}°C'),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _bleService.tempDataLengthNotifier,
                          builder: (ctx, tempLen, _) =>
                              Text('Temperature Samples: $tempLen'),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _bleService.accelDataLengthNotifier,
                          builder: (ctx, accelLen, _) =>
                              Text('Accel Samples: $accelLen'),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _bleService.ppgDataLengthNotifier,
                          builder: (ctx, ppgLen, _) =>
                              Text('PPG Samples: $ppgLen'),
                        ),
                        /* ValueListenableBuilder<int>(
                          valueListenable: _bleService.apneaIndicesNotifier,
                          builder: (ctx, AHI, _) =>
                              Text('AHI: $AHI'),
                        ), */
                      ],
                    ),
                  ),*/
                ),
              ),
            ].divide(const SizedBox(height: 20.0)),
          ),
        ),
        /*floatingActionButton: FloatingActionButton(
          onPressed: () async {
            // Launch the QR scanner.
            final scannedCode = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QRScannerScreen()),
            );
            if (scannedCode != null) {
              if (scannedCode == "12345678-1234-5678-1234-56789abcdef0") {
                _bleService.startScan();
                if (_bleService.discoveredDevices.isNotEmpty) {
                  _bleService
                      .connectToDevice(_bleService.discoveredDevices.first);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Scanned QR code is invalid.")),
                );
              }
            }
          },
          child: const Icon(Icons.qr_code_scanner),
        ),
      ),
    );
  }
}

/// A QR scanner screen using ReaderWidget from flutter_zxing.
class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR Code")),
      body: ReaderWidget(
        onScan: (Code result) async {
          if (result.isValid) {
            debugPrint("Scanned QR Code: ${result.text}");
            Navigator.pop(context, result.text);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid scan. Please try again.")),
            );
          }
        },*/
      ),
    );
  }
}
