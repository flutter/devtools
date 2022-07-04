import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../config_specific/logger/logger.dart' as logger;
import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../primitives/utils.dart';
import '../../../../service/service_extensions.dart';
import '../../../../shared/globals.dart';
import 'instrumentation/model.dart';
import 'primitives/processing_status.dart';

// TODO(polinach): reference this constants in dart SDK, when it gets submitted
// there.
// https://github.com/flutter/devtools/issues/3951
const _extensionKindToReceiveLeaksSummary = 'memory_leaks_summary';
const _extensionKindToReceiveLeaksDetails = 'memory_leaks_details';

// TODO(polina-c): review UX with UX specialists
// https://github.com/flutter/devtools/issues/3951
import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../primitives/utils.dart';
import '../../../../shared/globals.dart';
import 'instrumentation/model.dart';

// TODO(polinach): reference this constant in dart SDK, when it gets submitted
// there.
// https://github.com/flutter/devtools/issues/3951
const _extensionKindToRecieveLeaksSummary = 'memory_leaks_summary';

class LeaksPane extends StatefulWidget {
  const LeaksPane({Key? key}) : super(key: key);

  @override
  State<LeaksPane> createState() => _LeaksPaneState();
}

class _LeaksPaneState extends State<LeaksPane> with AutoDisposeMixin {
  LeakSummary? _lastLeakSummary;
  String _leakSummaryHistory = '';
  final AnalysisStatusController _analysis = AnalysisStatusController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    cancelStreamSubscriptions();
    _subscribeForMemoryLeaksMessages();
  }

  void _receivedLeaksSummary(Event event) {
    try {
      final newSummary = LeakSummary.fromJson(event.json!['extensionData']!);
      final time = event.timestamp != null
          ? DateTime.fromMicrosecondsSinceEpoch(event.timestamp!)
          : DateTime.now();

      if (newSummary.matches(_lastLeakSummary)) return;
      _lastLeakSummary = newSummary;
      setState(() {
        _leakSummaryHistory =
            '${formatDateTime(time)}: ${newSummary.toMessage()}\n$_leakSummaryHistory';
      });
    } catch (error, trace) {
      setState(
        () => _leakSummaryHistory = 'error: $error\n$_leakSummaryHistory',
      );
      logger.log(error);
      logger.log(trace);
    }
  }

  void _receivedLeaksDetails(Event event) {
    if (_analysis.status.value != AnalysisStatus.NotStarted) return;

    //   try {
    //     await setHeavyState(() {
    //       _leakController.message = 'Received leaks. Parsing.';
    //     });
    //     final leakDetails = Leaks.fromJson(event.json!['extensionData']!);

    //   try {
    //     await setHeavyState(() {
    //       _leakController.message = 'Received leaks. Parsing.';
    //     });
    //     final leakDetails = Leaks.fromJson(event.json!['extensionData']!);
    //
    //     await setHeavyState(() {
    //       _leakController.message = 'Getting retaining paths.';
    //     });
    //     final notGCed = leakDetails.leaks[LeakType.notGCed] ?? [];
    //
    //     if (notGCed.isNotEmpty) {
    //       final task = await getTask(controller, notGCed);
    //       assert(task.reports.isNotEmpty);
    //
    //       await setHeavyState(() {
    //         _leakController.message = 'Getting retaining paths.';
    //         _leakController.previousAnalysisTask =
    //             jsonEncode(task.toJson());
    //       });
    //
    //       calculateRetainingPathsOrRetainers(task);
    //
    //       assert(task.reports.first.retainingPath != null ||
    //           task.reports.first.retainers != null);
    //     }
    //
    //     setState(
    //       () => _leakController.message =
    //           'Obtained paths. Copying to clipboard',
    //     );
    //
    //     await Clipboard.setData(
    //       ClipboardData(text: analyzeAndYaml(leakDetails)),
    //     );
    //
    //     setState(() {
    //       _leakController.message = 'Copied to clipboard';
    //       _leakController.isComplete = true;
    //     });
    //
    //     await Future.delayed(const Duration(seconds: 1));
    //
    //     setState(() {
    //       _leakController.reset();
    //     });
    //   } catch (e, trace) {
    //     handleError(e, trace);
    //   }
  }

  void _subscribeForMemoryLeaksMessages() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEventWithHistory.listen((event) async {
        if (event.extensionKind == _extensionKindToReceiveLeaksSummary) {
          _receivedLeaksSummary(event);
        }
        if (event.extensionKind == _extensionKindToReceiveLeaksDetails) {
          _receivedLeaksDetails(event);
        }
      }),
    );
  }

  void _reportError(Object error, StackTrace trace) {
    setState(() {
      _analysis.message = 'Processing error: $error';
      _analysis.status.value = AnalysisStatus.ShowingError;
    });
    logger.log(error);
    logger.log(trace);
  }

  Future<void> _requestLeaks() async {
    await serviceManager.service!.callServiceExtension(
      memoryLeakTracking,
      args: <String, dynamic>{
        // TODO(polina-c): reference the constant in Flutter
        // https://github.com/flutter/devtools/issues/3951
        'requestDetails': 'true',
      },
    );
    setState(
      () => _analysis.message = 'Requested details from the application.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_leakSummaryHistory.isEmpty) return const Text('No information yet.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (_analysis.status.value == AnalysisStatus.NotStarted)
            ? Tooltip(
                message: 'Analyze the leaks and save the result\n'
                    'to the file Downloads/leaks_<time>.yaml.',
                child: MaterialButton(
                  child: const Text('Analyze and Save'),
                  onPressed: () async => _requestLeaks(),
                ),
              )
            : AnalysisStatusView(controller: _analysis),
        Expanded(
          child: SingleChildScrollView(child: Text(_leakSummaryHistory)),
        ),
        if (_leakSummaryHistory.isEmpty) const Text('No information yet.'),
        if (_leakSummaryHistory.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(child: Text(_leakSummaryHistory)),
          ),
      ],
    );
  }
}
