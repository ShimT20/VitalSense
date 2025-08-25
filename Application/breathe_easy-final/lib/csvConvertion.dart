class CsvHelper {
  List<List<dynamic>> rows = [];

  CsvHelper() {
    rows.add(['SensorValue']); // Add header row
  }

  void addRow(DateTime timestamp, double sensorValue) {
    rows.add([timestamp.toIso8601String(), sensorValue]);
    print('Row added: $sensorValue');
  }

  List<List<dynamic>> getAllData() => rows;

  void clear() {
    rows = [
      ['SensorValue']
    ]; // Keep the header
  }
}
