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
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';
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
        if (_leaksSummary.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(child: Text(_leaksSummary)),
          ),
      ],
    );
  }
}

class _LeakAnalysisController {
  bool isStarted = false;
  bool isComplete = false;
  String message = '';
  String? error;

  void reset() {
    message = '';
    isStarted = false;
    isComplete = false;
    error = null;
  }
}

class _LeakAnalysis extends StatefulWidget {
  const _LeakAnalysis({Key? key}) : super(key: key);

  @override
  State<_LeakAnalysis> createState() => _LeakAnalysisState();
}

class _LeakAnalysisState extends State<_LeakAnalysis>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, _LeakAnalysis> {
  final _leakController = _LeakAnalysisController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
    _subscribeForMemoryLeaksDetails();
  }

  void _subscribeForMemoryLeaksDetails() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEvent.listen((event) async {
        if (event.extensionKind == 'memory_leaks_details') {
          try {
            print('!!!!!!!!! Received leaks.');
            setState(() {
              _leakController.message = 'Received leaks. Parsing.';
            });
            final leakDetails = Leaks.fromJson(event.json!['extensionData']!);

            setState(() {
              _leakController.message = 'Getting retaining paths.';
            });
            final notGCed = leakDetails.leaks[LeakType.notGCed];
            await setRetainingPaths(controller, notGCed ?? []);
            setState(
              () => _leakController.message =
                  'Obtained paths. Copying to clipboard.',
            );
            await Clipboard.setData(
                ClipboardData(text: analyzeAndYaml(leakDetails)));
            setState(() {
              _leakController.message = 'Copied to clipboard';
              _leakController.isComplete = true;
            });
            await Future.delayed(const Duration(seconds: 1));
            setState(() {
              _leakController.reset();
            });
          } catch (e, trace) {
            handleError(e, trace);
          }
        }
      }),
    );
  }

  void handleError(Object error, StackTrace trace) {
    setState(() {
      _leakController.error = 'Processing error: $error';
    });
    logger.log(error);
    logger.log(trace);
  }

  Future<void> _requestLeaks() async {
    await eval.safeEval('sendLeaks()', isAlive: Stub());
  }

  @override
  Widget build(BuildContext context) {
    if (!_leakController.isStarted) {
      return MaterialButton(
        child: const Text('Analyze and Copy to Clipboard'),
        onPressed: () async {
          try {
            await _requestLeaks();
            setState(() {
              _leakController.isStarted = true;
              _leakController.message = 'Requested details.';
            });
          } catch (e, trace) {
            handleError(e, trace);
          }
        },
      );
    }

    if (_leakController.error != null) {
      return Column(
        children: [
          Text(_leakController.message),
          Text(_leakController.error!),
          MaterialButton(
            child: const Text('OK'),
            onPressed: () => setState(() => _leakController.reset()),
          )
        ],
      );
    }

    return Column(
      children: [
        Text(_leakController.message),
        if (!_leakController.isComplete)
          MaterialButton(
            child: const Text('Cancel'),
            onPressed: () => setState(() => _leakController.reset()),
          ),
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
