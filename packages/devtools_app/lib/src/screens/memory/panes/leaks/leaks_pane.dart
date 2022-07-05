import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../config_specific/logger/logger.dart' as logger;
import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../primitives/utils.dart';
import '../../../../service/service_extensions.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/utils.dart';
import '../../memory_controller.dart';
import 'diagnostics/model.dart';
import 'diagnostics/not_gced_analyzer.dart';
import 'instrumentation/model.dart';
import 'primitives/analysis_status.dart';

// TODO(polina-c): reference this constants in dart SDK, when it gets submitted
// there.
// https://github.com/flutter/devtools/issues/3951
const _extensionKindToReceiveLeaksSummary = 'memory_leaks_summary';
const _extensionKindToReceiveLeaksDetails = 'memory_leaks_details';

// TODO(polina-c): review UX with UX specialists
// https://github.com/flutter/devtools/issues/3951
class LeaksPane extends StatefulWidget {
  const LeaksPane({Key? key}) : super(key: key);

  @override
  State<LeaksPane> createState() => _LeaksPaneState();
}

class _LeaksPaneState extends State<LeaksPane>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, LeaksPane> {
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

  Future<NotGCedAnalyzerTask> _createAnalysisTask(
    List<LeakReport> reports,
  ) async {
    final graph = (await controller.snapshotMemory())!;
    return NotGCedAnalyzerTask.fromSnapshot(graph, reports);
  }

  Future<void> _receivedLeaksDetails(Event event) async {
    if (_analysis.status.value != AnalysisStatus.Ongoing) return;
    _analysis.message.value = 'Received details. Parsing.';
    final leakDetails = Leaks.fromJson(event.json!['extensionData']!);

    _analysis.status.value = AnalysisStatus.ShowingResult;

    final notGCed = leakDetails.byType[LeakType.notGCed] ?? [];

    NotGCedAnalyzed? notGCedAnalyzed;
    if (notGCed.isNotEmpty) {
      _analysis.message.value = 'Taking heap snapshot.';
      final task = await _createAnalysisTask(notGCed);
      _analysis.message.value = 'Detecting retaining paths.';
      notGCedAnalyzed = analyseNotGCed(task);
    }

    _analysis.message.value = 'Formatting.';


    final yaml = analyzedLeakToYaml(
      gcedLate: leakDetails.gcedLate,
      notDisposed: leakDetails.notDisposed,
      notGCed: notGCedAnalyzed,
    );

    await Clipboard.setData(
      ClipboardData(text: yaml),
    );

    setState(() {
      _leakController.message = 'Copied to clipboard';
      _leakController.isComplete = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _leakController.reset();
    });

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


  void _subscribeForMemoryLeaksMessages() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEventWithHistory.listen((event) async {
        if (event.extensionKind == _extensionKindToReceiveLeaksSummary) {
          _receivedLeaksSummary(event);
        }
      }),
    );

    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEvent.listen((event) async {
        if (event.extensionKind == _extensionKindToReceiveLeaksDetails) {
          await _receivedLeaksDetails(event);
        }
      }),
    );
  }

  Future<void> _requestLeaks() async {
    _analysis.status.value = AnalysisStatus.Ongoing;
    _analysis.message.value = 'Requested details from the application.';

    await serviceManager.service!.callServiceExtension(
      memoryLeakTracking,
      isolateId: serviceManager.isolateManager.mainIsolate.value!.id!,
      args: <String, dynamic>{
        // TODO(polina-c): reference the constant in Flutter
        // https://github.com/flutter/devtools/issues/3951
        'requestDetails': 'true',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_leakSummaryHistory.isEmpty) return const Text('No information yet.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeepAliveWrapper(
          child: AnalysisStatusView(
            controller: _analysis,
            processStarter: Tooltip(
              message: 'Analyze the leaks and save the result\n'
                  'to the file Downloads/leaks_<time>.yaml.',
              child: MaterialButton(
                child: const Text('Analyze and Save'),
                onPressed: () async => _requestLeaks(),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(child: Text(_leakSummaryHistory)),
        ),
      ],
    );
  }
}
