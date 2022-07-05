import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../config_specific/import_export/import_export.dart';
import '../../../../config_specific/launch_url/launch_url.dart';
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
import 'formatter.dart';
import 'instrumentation/model.dart';
import 'primitives/analysis_status.dart';

// TODO(polina-c): reference this constants in dart SDK, when it gets submitted
// there.
// https://github.com/flutter/devtools/issues/3951
const _extensionKindToReceiveLeaksSummary = 'memory_leaks_summary';
const _extensionKindToReceiveLeaksDetails = 'memory_leaks_details';
const _file_prefix = 'memory_leaks';

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
  final _exportController = ExportController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
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
    NotGCedAnalyzerTask? task;

    try {
      _analysis.message.value = 'Received details. Parsing...';
      final leakDetails = Leaks.fromJson(event.json!['extensionData']!);

      final notGCed = leakDetails.byType[LeakType.notGCed] ?? [];

      NotGCedAnalyzed? notGCedAnalyzed;
      if (notGCed.isNotEmpty) {
        _analysis.message.value = 'Taking heap snapshot...';
        task = await _createAnalysisTask(notGCed);
        _analysis.message.value = 'Detecting retaining paths...';
        notGCedAnalyzed = analyseNotGCed(task);
      }

      _analysis.message.value = 'Formatting...';

      final yaml = analyzedLeaksToYaml(
        gcedLate: leakDetails.gcedLate,
        notDisposed: leakDetails.notDisposed,
        notGCed: notGCedAnalyzed,
      );

      _saveResultAndSetStatus(yaml, task);
    } catch (error, trace) {
      var message = '${_analysis.message.value}\nError: $error';
      if (task != null) {
        final fileName = _saveTask(task, DateTime.now());
        message += '\nDownloaded raw data to $fileName.';
        _analysis.message.value = message;
        _analysis.status.value = AnalysisStatus.ShowingError;
      }
      logger.log(error);
      logger.log(trace);
    }
  }

  void _saveResultAndSetStatus(String yaml, NotGCedAnalyzerTask? task) {
    final now = DateTime.now();
    final yamlFile = _exportController.generateFileName(
      time: now,
      prefix: _file_prefix,
      extension: 'yaml',
    );
    _exportController.downloadFile(yaml, fileName: yamlFile);
    final String? taskFile = _saveTask(task, now);

    final taskFileMessage = taskFile == null ? '' : ' and $taskFile';
    _analysis.message.value =
        'Downloaded the leak analysis to $yamlFile$taskFileMessage.';
    _analysis.status.value = AnalysisStatus.ShowingResult;
  }

  /// Saves raw analysis task for troubleshooting and deeper analysis.
  String? _saveTask(NotGCedAnalyzerTask? task, DateTime? now) {
    if (task == null) return null;

    final json = jsonEncode(task.toJson());
    final jsonFile = _exportController.generateFileName(
      time: now,
      prefix: _file_prefix,
      extension: 'raw.json',
    );
    return _exportController.downloadFile(json, fileName: jsonFile);
  }

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

    await _invokeMemoryLeakTrackingExtension(
      <String, dynamic>{
        // TODO(polina-c): reference the constant in Flutter
        // https://github.com/flutter/devtools/issues/3951
        'requestDetails': 'true',
      },
    );
  }

  Future<void> _forceGC() async {
    _analysis.status.value = AnalysisStatus.Ongoing;
    _analysis.message.value = 'Forcing full garbage collection...';
    await _invokeMemoryLeakTrackingExtension(
      <String, dynamic>{
        // TODO(polina-c): reference the constant in Flutter
        // https://github.com/flutter/devtools/issues/3951
        'forceGC': 'true',
      },
    );
    _analysis.status.value = AnalysisStatus.ShowingResult;
    _analysis.message.value = 'Full garbage collection initiated.';
  }

  Future<void> _invokeMemoryLeakTrackingExtension(
    Map<String, dynamic> args,
  ) async {
    await serviceManager.service!.callServiceExtension(
      memoryLeakTracking,
      isolateId: serviceManager.isolateManager.mainIsolate.value!.id!,
      args: args,
    );
  }

  @override
  Widget build(BuildContext context) {
    final informationButton = Tooltip(
      message: 'Open memory leak tracking guidance.',
      child: IconButton(
        icon: const Icon(Icons.help_outline),
        onPressed: () async => await launchUrl(linkToGuidance, context),
      ),
    );

    if (_leakSummaryHistory.isEmpty)
      return Column(
        children: [
          informationButton,
          const Text('No information about memory leaks yet.'),
        ],
      );

    final analyzeButton = Tooltip(
      message: 'Analyze the leaks and download the result\n'
          'to ${_file_prefix}_<time>.yaml.',
      child: MaterialButton(
        child: const Text('Analyze and Download'),
        onPressed: () async => _requestLeaks(),
      ),
    );

    final forceGCButton = Tooltip(
      message: 'Force full GC in the application\n'
          'to make sure to collect everything that can be collected.',
      child: MaterialButton(
        child: const Text('Force GC'),
        onPressed: () async => _forceGC(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeepAliveWrapper(
          child: AnalysisStatusView(
            controller: _analysis,
            analysisStarter: Row(
              children: [
                informationButton,
                analyzeButton,
                forceGCButton,
              ],
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
