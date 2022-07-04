import 'package:flutter/material.dart';

import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../primitives/utils.dart';
import '../../../../shared/globals.dart';
import 'instrumentation/model.dart';
import 'primitives/processing_status.dart';
import '../../config_specific/logger/logger.dart' as logger;

// TODO(polinach): reference this constant in dart SDK, when it gets submitted
// there.
// https://github.com/flutter/devtools/issues/3951
const _extensionKindToReceiveLeaksSummary = 'memory_leaks_summary';

// TODO(polina-c): review UX with UX specialists
// https://github.com/flutter/devtools/issues/3951
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

  // void _subscribeForMemoryLeaksMessages() {
  //   autoDisposeStreamSubscription(
  //     serviceManager.service!.onExtensionEventWithHistory.listen((event) async {
  //       if (event.extensionKind == _extensionKindToReceiveLeaksSummary) {
  //         final newSummary =
  //             LeakSummary.fromJson(event.json!['extensionData']!);
  //         if (newSummary.matches(_lastLeakSummary)) return;
  //         _lastLeakSummary = newSummary;
  //         final time = event.timestamp != null
  //             ? DateTime.fromMicrosecondsSinceEpoch(event.timestamp!)
  //             : DateTime.now();
  //         setState(() {
  //           _leakSummaryHistory =
  //               '${formatDateTime(time)}: ${newSummary.toMessage()}\n$_leakSummaryHistory';
  //         });
  //       }
  //
  //       if (event.extensionKind == 'memory_leaks_details') {
  //         try {
  //           await setHeavyState(() {
  //             _leakController.message = 'Received leaks. Parsing.';
  //           });
  //           final leakDetails = Leaks.fromJson(event.json!['extensionData']!);
  //
  //           await setHeavyState(() {
  //             _leakController.message = 'Getting retaining paths.';
  //           });
  //           final notGCed = leakDetails.leaks[LeakType.notGCed] ?? [];
  //
  //           if (notGCed.isNotEmpty) {
  //             final task = await getTask(controller, notGCed);
  //             assert(task.reports.isNotEmpty);
  //
  //             await setHeavyState(() {
  //               _leakController.message = 'Getting retaining paths.';
  //               _leakController.previousAnalysisTask =
  //                   jsonEncode(task.toJson());
  //             });
  //
  //             calculateRetainingPathsOrRetainers(task);
  //
  //             assert(task.reports.first.retainingPath != null ||
  //                 task.reports.first.retainers != null);
  //           }
  //
  //           setState(
  //             () => _leakController.message =
  //                 'Obtained paths. Copying to clipboard',
  //           );
  //
  //           await Clipboard.setData(
  //             ClipboardData(text: analyzeAndYaml(leakDetails)),
  //           );
  //
  //           setState(() {
  //             _leakController.message = 'Copied to clipboard';
  //             _leakController.isComplete = true;
  //           });
  //
  //           await Future.delayed(const Duration(seconds: 1));
  //
  //           setState(() {
  //             _leakController.reset();
  //           });
  //         } catch (e, trace) {
  //           handleError(e, trace);
  //         }
  //       }
  //     }),
  //   );
  // }

  void _reportError(Object error, StackTrace trace) {
    setState(() {
      _analysis.message = 'Processing error: $error';
      _analysis.status.value = AnalysisStatus.ShowingError;
    });
    logger.log(error);
    logger.log(trace);
  }

  Future<void> _requestLeaks() async {
    await eval.safeEval('sendLeaks()', isAlive: Stub());
    print('!!!!!!!!! Requested leaks.');
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
      ],
    );
  }
}
