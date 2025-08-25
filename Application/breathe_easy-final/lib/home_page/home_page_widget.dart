import 'package:breathe_easy/csvConvertion.dart';
import 'package:breathe_easy/onboarding/onboarding_widget.dart';
import 'package:breathe_easy/scanning/scanning_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';

import 'package:file_picker/file_picker.dart';
import 'api_service.dart';
import 'dart:io';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isStarted = false;

  final CsvHelper csvHelper = CsvHelper(); // Add this line here
  final BleService _bleService = BleService.instance;

  DateTime? _startTime;
  Duration? _sleepDuration;
  String get _sleepDurationFormatted {
    if (_sleepDuration == null) return '00:00:00';
    final h = _sleepDuration!.inHours;
    final m = _sleepDuration!.inMinutes % 60;
    final s = _sleepDuration!.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }
  List<double> _apneaIndices = [];

  double ppgApneaIndex = 0;
  double spo2ApneaIndex = 0;
  double avgApneaIndex = 0;

  Future<void> _processPpgFiles() async {
    // Open file picker to select multiple CSV files
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['csv'], // Assuming PPG data is in CSV files
    );
    if (result != null) {
      List<File> ppgFiles = result.paths.map((path) => File(path!)).toList();
      List<double> apneaIndices = [];

      for (var ppgFile in ppgFiles) {
        try {
          // Call PPG-to-ECG API
          File ecgFile = await ApiService().ppgToEcg(ppgFile);
          // Call ECG-to-apnea-index API
          double apneaIndex = await ApiService().getApneaIndex(ecgFile);
          print("apnea index calculated properly");
          /* apneaIndices.add(apneaIndex); */
          ppgApneaIndex = apneaIndex;
          // Clean up temporary ECG file
          await ecgFile.delete();
        } catch (e) {
          debugPrint('Error processing file ${ppgFile.path}: $e');
          // Optionally, show an error message to the user
        }
      }
      setState(() {
        _apneaIndices = apneaIndices; // Update the state with results
        
        debugPrint("ppg apnea index: $ppgApneaIndex");

        //call the spo2 and accel code here//

        debugPrint("spo2 apnea index: $spo2ApneaIndex");
        avgApneaIndex = ((ppgApneaIndex + spo2ApneaIndex)/2);
        debugPrint("avg apnea index: $avgApneaIndex");
      });
    }
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
        body: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: MediaQuery.sizeOf(context).width * 1.0,
                height: 190.0,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0),
                    topLeft: Radius.circular(0.0),
                    topRight: Radius.circular(0.0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      20.0, 20.0, 20.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  0.0, 30.0, 0.0, 0.0),
                              child: Text(
                                DateTime.now().hour < 12
                                    ? 'Good Morning!'
                                    : 'Good Evening!',
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context)
                                    .headlineLarge
                                    .override(
                                      fontFamily: 'Inter Tight',
                                      fontSize: 40.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 0.0, 0.0, 10.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    const Icon(
                                      Icons.opacity,
                                      color: Colors.green,
                                      size: 24.0,
                                    ),
                                  ].divide(const SizedBox(width: 8.0)),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ValueListenableBuilder<int?>(
                                      valueListenable: _bleService.spo2Notifier,
                                      builder: (ctx, spo2, _) =>
                                          Text('SpO2: ${spo2 ?? 'N/A'}%'),
                                    ),
                                  ].divide(const SizedBox(height: 4.0)),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    const Icon(
                                      Icons.favorite,
                                      color: Colors.green,
                                      size: 24.0,
                                    ),
                                  ].divide(const SizedBox(width: 8.0)),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ValueListenableBuilder<int?>(
                                      valueListenable: _bleService.bpmNotifier,
                                      builder: (ctx, bpm, _) => Text(
                                        'Heart Rate: ${bpm != null ? '$bpm bpm' : 'N/A'}',
                                      ),
                                    ),
                                  ].divide(const SizedBox(height: 4.0)),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    const Icon(
                                      Icons.thermostat,
                                      color: Colors.green,
                                      size: 24.0,
                                    ),
                                  ].divide(const SizedBox(width: 8.0)),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ValueListenableBuilder<double?>(
                                      valueListenable:
                                          _bleService.temperatureNotifier,
                                      builder: (ctx, temp, _) => Text(
                                          'Temperature: ${temp?.toStringAsFixed(1) ?? 'N/A'}°C'),
                                    ),
                                  ].divide(const SizedBox(height: 4.0)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: const AlignmentDirectional(0.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Align(
                              alignment: const AlignmentDirectional(0.0, 0.0),
                              child: Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 10.0, 0.0),
                                child: FlutterFlowIconButton(
                                  borderRadius: 500.0,
                                  buttonSize: 150.0,
                                  fillColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  icon: Icon(
                                    Icons.bluetooth_searching,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 50.0,
                                  ),
                                  onPressed: () async {
                                    context.pushNamed('scanning');
                                  },
                                ),
                              ),
                            ),
                            Align(
                              alignment: const AlignmentDirectional(0.0, 0.0),
                              child: Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      10.0, 0.0, 0.0, 0.0),
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      if (BleService.instance.connectedDevices
                                          .isNotEmpty) {
                                        if (_isStarted) {
                                          // ── STOP pressed ──
                                          await BleService.instance
                                              .sendStopCommand(
                                            BleService.instance.connectedDevices
                                                .first,
                                          );

                                          // Compute elapsed time
                                          final stopTime = DateTime.now();
                                          if (_startTime != null) {
                                            _sleepDuration = stopTime
                                                .difference(_startTime!);
                                          }

                                          debugPrint("The spo2 apnea index is: ${_bleService.spo2ApneaIndex.value}");
                                          spo2ApneaIndex = _bleService.spo2ApneaIndex.value.toDouble();
                                          setState(() {
                                            _isStarted = false;
                                          });

                                          
                                          // (Optional) print collected sensor values
                                          /* final allData = BleService
                                              .instance.csvHelper
                                              .getAllData();
                                          for (int i = 1;
                                              i < allData.length;
                                              i++) {
                                            print(allData[i][1]);
                                          } */
                                        } else {
                                          // ── START pressed ──
                                          await BleService.instance
                                              .sendStartCommand(
                                            BleService.instance.connectedDevices
                                                .first,
                                          );

                                          // 1) Clear old CSV data
                                          BleService.instance.csvHelper.clear();

                                          // 2) Reset previous readings
                                          _sleepDuration = null;

                                          // 3) Record start time
                                          _startTime = DateTime.now();

                                          setState(() {
                                            _isStarted = true;
                                          });
                                        }
                                      } else {
                                        print(
                                            'No connected device. Please connect first.');
                                      }
                                    },
                                    text: _isStarted ? 'Stop' : 'Start',
                                    options: FFButtonOptions(
                                      width: 150.0,
                                      height: 150.0,
                                      color: const Color(0xFF262D34),
                                      textStyle: FlutterFlowTheme.of(context)
                                          .headlineLarge
                                          .override(
                                            fontFamily: 'Inter Tight',
                                          ),
                                      borderRadius: BorderRadius.circular(80.0),
                                    ),
                                  )),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 0.0, horizontal: 24.0),
                        child: ElevatedButton(
                          onPressed: _processPpgFiles,
                          style: ElevatedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, 50), // Full width
                            backgroundColor:
                                const Color(0xFF4B39EF), // Purple-ish tone
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text(
                            'Show my Data',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 200.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).alternate,
                          borderRadius: BorderRadius.circular(18.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              16.0, 16.0, 16.0, 16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last Night\'s Sleep Analysis',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      fontFamily: 'Inter Tight',
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                              Align(
                                alignment: const AlignmentDirectional(0.0, 0.0),
                                child: Icon(
                                  Icons.nights_stay,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 80.0,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            0.0, 0.0, 15.0, 0.0),
                                    child: Container(
                                      decoration: const BoxDecoration(),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Sleep Duration',
                                            textAlign: TextAlign.center,
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  fontFamily: 'Inter',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              const Icon(Icons.bed,
                                                  color: Colors.green,
                                                  size: 24.0),
                                              const SizedBox(width: 8.0),
                                              Text(
                                                _sleepDurationFormatted,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ].divide(const SizedBox(height: 4.0)),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            0.0, 0.0, 15.0, 0.0),
                                    child: Container(
                                      decoration: const BoxDecoration(),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Severity',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  fontFamily: 'Inter',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .health_and_safety_outlined,
                                                color: Colors.green,
                                                size: 24.0,
                                              ),
                                              Text(
                                                avgApneaIndex.toStringAsFixed(3),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium,
                                              ),
                                            ].divide(
                                                const SizedBox(width: 8.0)),
                                          ),
                                        ].divide(const SizedBox(height: 4.0)),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Apnea index',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                fontFamily: 'Inter',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            const Icon(
                                              Icons.warning,
                                              color: Color(0xFFFFC107),
                                              size: 24.0,
                                            ),
                                            Text(
                                                avgApneaIndex.toStringAsFixed(3),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium,
                                              ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      /*Material(
                        color: Colors.transparent,
                        elevation: 2.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                        child: Container(
                          width: MediaQuery.sizeOf(context).width * 1.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).alternate,
                            borderRadius: BorderRadius.circular(24.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 16.0, 16.0, 16.0),
                            /*child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Daily Health Summary',
                                  style: FlutterFlowTheme.of(context)
                                      .headlineSmall
                                      .override(
                                        fontFamily: 'Inter Tight',
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Avg. Heart Rate',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'Inter',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            const Icon(
                                              Icons.favorite,
                                              color: Color(0xFF4B39EF),
                                              size: 24.0,
                                            ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Avg. Oxygen',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'Inter',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            const Icon(
                                              Icons.opacity,
                                              color: Color(0xFF4B39EF),
                                              size: 24.0,
                                            ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Movement',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'Inter',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            const Icon(
                                              Icons.directions_run,
                                              color: Color(0xFF4B39EF),
                                              size: 24.0,
                                            ),
                                          ].divide(const SizedBox(width: 8.0)),
                                        ),
                                      ].divide(const SizedBox(height: 4.0)),
                                    ),
                                  ],
                                ),
                              ].divide(const SizedBox(height: 16.0)),
                            ),*/
                          ),
                        ),
                      ),*/
                      Text(
                        'This device is not a substitute for professional medical advice. Always consult your healthcare provider for medical concerns.',
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              fontFamily: 'Inter',
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                      ),
                      const SizedBox(height: 0.0),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Optional: Clear any session/authentication tokens here
                          // await FirebaseAuth.instance.signOut(); // Uncomment if using Firebase

                          // Optional: Clear local app state or secure storage

                          // Navigate to login screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const OnboardingWidget()),
                          );
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 12.0),
                          textStyle: const TextStyle(
                              fontSize: 16.0, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 0.0),
                    ].divide(const SizedBox(height: 20.0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
