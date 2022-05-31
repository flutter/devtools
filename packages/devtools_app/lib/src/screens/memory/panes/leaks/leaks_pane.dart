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

final _eval = EvalOnDartLibrary(
  'package:memory_tools/app_leak_detector.dart',
  serviceManager.service!,
);

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

Future<void> _setRetainingPath(ObjectReport info) async {
  final objectRef = await _eval
      .safeEval('getNotGCedObject(${info.theIdentityHashCode})', isAlive: null);

  const pathLimit = 1000;
  final path = await serviceManager.service!.getRetainingPath(
    _eval.isolate!.id!,
    objectRef.id!,
    1000,
  );

  assert((path.elements?.length ?? 0) <= pathLimit - 1);

  info.retainingPath = pathToString(path);
  info.gcRootType = path.gcRootType;
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
  final _controller = _LeakAnalysisController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeForMemoryLeaksDetails();
  }

  void _subscribeForMemoryLeaksDetails() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEventWithHistory.listen((event) async {
        if (event.extensionKind == 'memory_leaks_details') {
          try {
            final leakDetails = Leaks.fromJson(event.json!['extensionData']!);
            setState(() {
              _controller.detailsReceived = true;
            });
            double step = 0;
            final notGCed = leakDetails.leaks[LeakType.notGCed];
            setState(() {
              if (notGCed != null && notGCed.isNotEmpty) {
                _controller.targetIdsReceived = 0;
                step = 1 / notGCed.length;
              }
            });
            for (var info in notGCed ?? []) {
              await _setRetainingPath(info);
              setState(() => _controller.targetIdsReceived =
                  _controller.targetIdsReceived + step);
            }
            await Clipboard.setData(
                ClipboardData(text: analyzeAndYaml(leakDetails)));
            setState(() {
              _controller.copiedToClipboard = true;
            });
            await Future.delayed(const Duration(seconds: 1));
            setState(() {
              _controller.reset();
            });
          } catch (e, trace) {
            setState(() {
              _controller.error = 'Processing error: $e';
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
    if (!_controller.isStarted) {
      return MaterialButton(
        child: const Text('Analyze and Copy to Clipboard'),
        onPressed: _analyzeAndCopyToClipboard,
      );
    }

    if (_controller.error != null) {
      return Column(
        children: [
          Text(_controller.error!),
          MaterialButton(
            child: const Text('OK'),
            onPressed: () => setState(() => _controller.reset()),
          )
        ],
      );
    }

    if (_controller.isComplete) {
      return Text(_controller.message);
    }

    return Column(
      children: [
        Text(_controller.message),
        MaterialButton(
          child: const Text('Cancel'),
          onPressed: () => setState(() => _controller.reset()),
        )
      ],
    );
  }

  Future<void> _analyzeAndCopyToClipboard() async {
    await _eval.safeEval('sendLeaks()', isAlive: Stub());
    setState(() => _controller.detailsRequested = true);
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
