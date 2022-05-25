import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memory_tools/primitives.dart';

import '../../../primitives/auto_dispose_mixin.dart';
import '../../../shared/eval_on_dart_library.dart';
import '../../../shared/globals.dart';

final DateFormat _formatter = DateFormat.Hms();
String _timeForConsole(DateTime time) => _formatter.format(time);

class LeaksArea extends StatefulWidget {
  const LeaksArea({Key? key}) : super(key: key);

  @override
  State<LeaksArea> createState() => _LeaksAreaState();
}

class _LeaksAreaState extends State<LeaksArea> with AutoDisposeMixin {
  var _leaksSummary = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeForMemoryLeaks();
  }

  void _subscribeForMemoryLeaks() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEventWithHistory.listen((event) {
        if (event.extensionKind == 'memory_leaks_summary') {
          final newSummary = LeakSummary(event.json!['extensionData']!);
          final time = event.timestamp != null
              ? DateTime.fromMicrosecondsSinceEpoch(event.timestamp!)
              : DateTime.now();
          setState(() {
            _leaksSummary =
                '${_timeForConsole(time)}: $newSummary\n$_leaksSummary';
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
        if (_leaksSummary.isEmpty) const Text('No information yet.'),
        if (_leaksSummary.isNotEmpty) Text(_leaksSummary),
        MaterialButton(
            child: const Text('Analyze and Copy to Clipboard'),
            onPressed: _analyzeAndCopyToClipboard),
      ],
    );
  }

  Future<void> _analyzeAndCopyToClipboard() async {
    final eval = EvalOnDartLibrary(
      'package:flutter_leaks/test_lib.dart',
      serviceManager.service!,
    );
    final result = await eval.safeEval('getObject(27182)', isAlive: null);
    print('evaluated: ${result.id!}, ${result.valueAsString}');

    final path = await serviceManager.service!.getRetainingPath(
      eval.isolate!.id!,
      result.id!,
      100,
    );

    print('path: $path');
  }
}
