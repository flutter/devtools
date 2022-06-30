import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../shared/globals.dart';
import 'instrumentation/model.dart';

final DateFormat _formatter = DateFormat.Hms();
String _timeForConsole(DateTime time) => _formatter.format(time);

class LeaksPane extends StatefulWidget {
  const LeaksPane({Key? key}) : super(key: key);

  @override
  State<LeaksPane> createState() => _LeaksPaneState();
}

class _LeaksPaneState extends State<LeaksPane> with AutoDisposeMixin {
  LeakSummary? _lastLeakSummary;
  String _leakSummaryHistory = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeForMemoryLeaksSummary();
  }

  void _subscribeForMemoryLeaksSummary() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEventWithHistory.listen((event) async {
        if (event.extensionKind == 'memory_leaks_summary') {
          final newSummary =
              LeakSummary.fromJson(event.json!['extensionData']!);
          if (newSummary.equals(_lastLeakSummary)) return;
          _lastLeakSummary = newSummary;
          final time = event.timestamp != null
              ? DateTime.fromMicrosecondsSinceEpoch(event.timestamp!)
              : DateTime.now();
          setState(() {
            _leakSummaryHistory =
                '${_timeForConsole(time)}: ${newSummary.toMessage()}\n$_leakSummaryHistory';
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_leakSummaryHistory.isEmpty) const Text('No information yet.'),
        if (_leakSummaryHistory.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(child: Text(_leakSummaryHistory)),
          ),
      ],
    );
  }
}
