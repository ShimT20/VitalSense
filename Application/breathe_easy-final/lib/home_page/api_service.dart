import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  /// Converts a PPG file to an ECG file by calling the PPG-to-ECG API.
  Future<File> ppgToEcg(File ppgFile) async {
    print('Starting PPG to ECG conversion for file: ${ppgFile.path}');
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.255.161.194:5000/upload'), // Replace with actual URL
    );
    print('Sending multipart request to: ${request.url}');
    request.files.add(await http.MultipartFile.fromPath('file', ppgFile.path));
    print('File added to request: ${ppgFile.path}');
    
    var response = await request.send().timeout(Duration(seconds: 120), onTimeout: () {
      // Optionally cancel the request, log or throw a specialized exception.
     throw Exception('The connection has timed out, please try again.');
    });;
    print('Received response with status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('Successfully received ECG data');
      var ecgData = await response.stream.bytesToString();
      print('ECG data length: ${ecgData.length} characters');
      print(ecgData);
      File ecgFile = File('${ppgFile.path}');
      print('Writing ECG data to: ${ecgFile.path}');
      await ecgFile.writeAsString(ecgData);
      print('ECG file created successfully');
      return ecgFile;
    } else {
      print('Error: Failed to convert PPG to ECG');
      throw Exception('Failed to convert PPG to ECG: ${response.statusCode}');
    }
  }

  /// Sends an ECG file to the ECG-to-apnea-index API and returns the apnea index.
  Future<double> getApneaIndex(File ecgFile) async {
    print('Starting apnea index calculation for file: ${ecgFile.path}');
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.255.161.194:8080/predict'), // Replace with actual URL
    );
    print('Sending multipart request to: ${request.url}');
    request.files.add(await http.MultipartFile.fromPath('file', ecgFile.path));
    print('File added to request: ${ecgFile.path}');
    
    var response = await request.send();
    print('Received response with status code: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('Successfully received apnea index response');
      var jsonResponse = await response.stream.bytesToString();
      print('Raw JSON response: $jsonResponse');
      var data = jsonDecode(jsonResponse);
      print('Parsed JSON data: $data');
      return data as double;
    } else {
      print('Error: Failed to get apnea index');
      throw Exception('Failed to get apnea index: ${response.statusCode}');
    }
  }
}