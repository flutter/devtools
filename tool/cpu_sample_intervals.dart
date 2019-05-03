import 'dart:convert';
import 'dart:io';

/// Outputs the time intervals between adjacent cpu samples.
/// 
/// A json file path is required as a command line argument.
/// Ex: dart cpu_sample_intervals.dart ~/Downloads/example_json.dart
void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('''
    You must specify a json input file path.
    Ex: dart cpu_sample_intervals.dart ~/Downloads/example_json.dart
    ''');
    return;
  }

  final File file = File(arguments.first);
  final Map<String, dynamic> timelineDump = jsonDecode(await file.readAsString());
  final cpuSampleTraceEvents = timelineDump['cpuProfile']['traceEvents'];

  final List<int> deltas = [];
  for (int i = 0; i < cpuSampleTraceEvents.length - 1; i++) {
    final Map<String, dynamic> current = cpuSampleTraceEvents[i];
    final Map<String, dynamic> next = cpuSampleTraceEvents[i + 1];
    deltas.add(next['ts'] - current['ts']);
  }
  print(deltas);
}
