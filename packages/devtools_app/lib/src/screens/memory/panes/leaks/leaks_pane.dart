import 'package:devtools_app/src/screens/memory/panes/leaks/retaining_path.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../shared/eval_on_dart_library.dart';
import '../../../../shared/globals.dart';
import 'package:flutter/services.dart';
import '../../../../config_specific/logger/logger.dart' as logger;
import 'leak_analysis.dart';

final DateFormat _formatter = DateFormat.Hms();
String _timeForConsole(DateTime time) => _formatter.format(time);

class LeaksPane extends StatefulWidget {
  const LeaksPane({Key? key}) : super(key: key);

  @override
  State<LeaksPane> createState() => _LeaksPaneState();
}

class _LeaksPaneState extends State<LeaksPane> with AutoDisposeMixin {
  LeakSummary? _previous;
  String _leaksSummary = '';

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
          if (newSummary.equals(_previous)) return;
          _previous = newSummary;
          final time = event.timestamp != null
              ? DateTime.fromMicrosecondsSinceEpoch(event.timestamp!)
              : DateTime.now();
          setState(() {
            _leaksSummary =
                '${_timeForConsole(time)}: ${newSummary.toMessage()}\n$_leaksSummary';
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
        const _LeakAnalysis(),
        if (_leaksSummary.isEmpty) const Text('No information yet.'),
        if (_leaksSummary.isNotEmpty) Text(_leaksSummary),
      ],
    );
  }
}

class _LeakAnalysisController {
  bool detailsRequested = false;
  bool detailsReceived = false;
  double targetIdsReceived = 0;
  bool copiedToClipboard = false;
  String? error;

  void reset() {
    detailsRequested = false;
    detailsReceived = false;
    targetIdsReceived = 0;
    copiedToClipboard = false;
    error = null;
  }

  bool get isStarted => detailsRequested;

  bool get isComplete => (error != null) || copiedToClipboard;

  String get message {
    if (error != null) return error!;
    if (copiedToClipboard) return 'copied to clipboard';
    if (targetIdsReceived > 0)
      return 'analyzed ${(targetIdsReceived * 100).round()}';
    if (detailsReceived) return 'analyzing...';
    if (detailsRequested) return 'receiving details...';
    return '-';
  }
}

class _LeakAnalysis extends StatefulWidget {
  const _LeakAnalysis({Key? key}) : super(key: key);

  @override
  State<_LeakAnalysis> createState() => _LeakAnalysisState();
}

class _LeakAnalysisState extends State<_LeakAnalysis> with AutoDisposeMixin {
  final _leakController = _LeakAnalysisController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeForMemoryLeaksDetails();
  }

  void _subscribeForMemoryLeaksDetails() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEvent.listen((event) async {
        if (event.extensionKind == 'memory_leaks_details') {
          try {
            final leakDetails = Leaks.fromJson(event.json!['extensionData']!);
            setState(() {
              _leakController.detailsReceived = true;
            });
            double step = 0;
            final notGCed = leakDetails.leaks[LeakType.notGCed];
            setState(() {
              if (notGCed != null && notGCed.isNotEmpty) {
                _leakController.targetIdsReceived = 0;
                step = 1 / notGCed.length;
              }
            });
            // for (var info in notGCed ?? []) {
            //   await setRetainingPath(info);
            //   setState(() => _controller.targetIdsReceived =
            //       _controller.targetIdsReceived + step);
            // }
            await setRetainingPaths(_leakController notGCed ?? []);
            setState(() => _leakController.targetIdsReceived = 1);
            await Clipboard.setData(
                ClipboardData(text: analyzeAndYaml(leakDetails)));
            setState(() {
              _leakController.copiedToClipboard = true;
            });
            await Future.delayed(const Duration(seconds: 1));
            setState(() {
              _leakController.reset();
            });
          } catch (e, trace) {
            setState(() {
              _leakController.error = 'Processing error: $e';
            });
            logger.log(e);
            logger.log(trace);
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_leakController.isStarted) {
      return MaterialButton(
        child: const Text('Analyze and Copy to Clipboard'),
        onPressed: () async {
          await eval.safeEval('sendLeaks()', isAlive: Stub());
          setState(() => _leakController.detailsRequested = true);
        },
      );
    }

    if (_leakController.error != null) {
      return Column(
        children: [
          Text(_leakController.error!),
          MaterialButton(
            child: const Text('OK'),
            onPressed: () => setState(() => _leakController.reset()),
          )
        ],
      );
    }

    if (_leakController.isComplete) {
      return Text(_leakController.message);
    }

    return Column(
      children: [
        Text(_leakController.message),
        MaterialButton(
          child: const Text('Cancel'),
          onPressed: () => setState(() => _leakController.reset()),
        )
      ],
    );
  }
}

class Stub implements Disposable {
  @override
  bool disposed = false;

  @override
  void dispose() {
    // TODO: implement dispose
  }
}
