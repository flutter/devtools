// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../config_specific/import_export/import_export.dart';
import '../../../../config_specific/logger/logger.dart' as logger;
import '../../../../primitives/utils.dart';
import '../../../../service/service_extensions.dart';
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/theme.dart';
import '../../primitives/memory_utils.dart';
import '../../primitives/ui.dart';
import 'diagnostics/model.dart';
import 'diagnostics/not_gced_analyzer.dart';
import 'formatter.dart';
import 'instrumentation/model.dart';
import 'primitives/analysis_status.dart';

// TODO(polina-c): reference these constants in dart SDK, when it gets submitted
// there.
// https://github.com/flutter/devtools/issues/3951
const _extensionKindToReceiveLeaksSummary = 'memory_leaks_summary';
const _extensionKindToReceiveLeaksDetails = 'memory_leaks_details';

const _filePrefix = 'memory_leaks';

// TODO(polina-c): review UX with UX specialists
// https://github.com/flutter/devtools/issues/3951
class LeaksPane extends StatefulWidget {
  const LeaksPane({Key? key}) : super(key: key);

  @override
  State<LeaksPane> createState() => _LeaksPaneState();
}

class _LeaksPaneController {
  _LeaksPaneController() {
    _subscribeForMemoryLeaksMessages();
  }

  final status = AnalysisStatusController();

  final leakSummaryHistory = ValueNotifier<String>('');
  final leakSummaryReceived = ValueNotifier<bool>(false);
  LeakSummary? _lastLeakSummary;

  final _exportController = ExportController();

  late StreamSubscription summarySubscription;
  late StreamSubscription detailsSubscription;

  /// Subscribes for summary with history and for details without history.
  void _subscribeForMemoryLeaksMessages() {
    detailsSubscription =
        serviceManager.service!.onExtensionEvent.listen(_receivedLeaksDetails);

    summarySubscription = serviceManager.service!.onExtensionEventWithHistory
        .listen(_receivedLeaksSummary);
  }

  void dispose() {
    summarySubscription.cancel();
    detailsSubscription.cancel();
    status.dispose();
  }

  void _receivedLeaksSummary(Event event) {
    if (event.extensionKind != _extensionKindToReceiveLeaksSummary) return;
    leakSummaryReceived.value = true;
    try {
      final newSummary = LeakSummary.fromJson(event.json!['extensionData']!);
      final time = event.timestamp != null
          ? DateTime.fromMicrosecondsSinceEpoch(event.timestamp!)
          : DateTime.now();

      if (newSummary.matches(_lastLeakSummary)) return;
      _lastLeakSummary = newSummary;
      leakSummaryHistory.value =
          '${formatDateTime(time)}: ${newSummary.toMessage()}\n'
          '${leakSummaryHistory.value}';
    } catch (error, trace) {
      leakSummaryHistory.value = 'error: $error\n${leakSummaryHistory.value}';
      logger.log(error);
      logger.log(trace);
    }
  }

  Future<NotGCedAnalyzerTask> _createAnalysisTask(
    List<LeakReport> reports,
  ) async {
    final graph = (await snapshotMemory())!;
    return NotGCedAnalyzerTask.fromSnapshot(graph, reports);
  }

  Future<void> _receivedLeaksDetails(Event event) async {
    if (event.extensionKind != _extensionKindToReceiveLeaksDetails) return;
    if (status.status.value != AnalysisStatus.Ongoing) return;
    NotGCedAnalyzerTask? task;

    try {
      await _setMessageWithDelay('Received details. Parsing...');
      final leakDetails = Leaks.fromJson(event.json!['extensionData']!);

      final notGCed = leakDetails.byType[LeakType.notGCed] ?? [];

      NotGCedAnalyzed? notGCedAnalyzed;
      if (notGCed.isNotEmpty) {
        await _setMessageWithDelay('Taking heap snapshot...');
        task = await _createAnalysisTask(notGCed);
        await _setMessageWithDelay('Detecting retaining paths...');
        notGCedAnalyzed = analyseNotGCed(task);
      }

      await _setMessageWithDelay('Formatting...');

      final yaml = analyzedLeaksToYaml(
        gcedLate: leakDetails.gcedLate,
        notDisposed: leakDetails.notDisposed,
        notGCed: notGCedAnalyzed,
      );

      _saveResultAndSetStatus(yaml, task);
    } catch (error, trace) {
      var message = '${status.message.value}\nError: $error';
      if (task != null) {
        final fileName = _saveTask(task, DateTime.now());
        message += '\nDownloaded raw data to $fileName.';
        await _setMessageWithDelay(message);
        status.status.value = AnalysisStatus.ShowingError;
      }
      logger.log(error);
      logger.log(trace);
    }
  }

  void _saveResultAndSetStatus(String yaml, NotGCedAnalyzerTask? task) async {
    final now = DateTime.now();
    final yamlFile = _exportController.generateFileName(
      time: now,
      prefix: _filePrefix,
      type: ExportFileType.yaml,
    );
    _exportController.downloadFile(yaml, fileName: yamlFile);
    final String? taskFile = _saveTask(task, now);

    final taskFileMessage = taskFile == null ? '' : ' and $taskFile';
    await _setMessageWithDelay(
      'Downloaded the leak analysis to $yamlFile$taskFileMessage.',
    );
    status.status.value = AnalysisStatus.ShowingResult;
  }

  /// Saves raw analysis task for troubleshooting and deeper analysis.
  String? _saveTask(NotGCedAnalyzerTask? task, DateTime? now) {
    if (task == null) return null;

    final json = jsonEncode(task.toJson());
    final jsonFile = _exportController.generateFileName(
      time: now,
      prefix: _filePrefix,
      postfix: '.raw',
      type: ExportFileType.json,
    );
    return _exportController.downloadFile(json, fileName: jsonFile);
  }

  Future<void> _setMessageWithDelay(String message) async {
    status.message.value = message;
    await delayForBatchProcessing(micros: 5000);
  }

  Future<void> forceGC() async {
    status.status.value = AnalysisStatus.Ongoing;
    await _setMessageWithDelay('Forcing full garbage collection...');
    await _invokeMemoryLeakTrackingExtension(
      <String, dynamic>{
        // TODO(polina-c): reference the constant in Flutter
        // https://github.com/flutter/devtools/issues/3951
        'forceGC': 'true',
      },
    );
    status.status.value = AnalysisStatus.ShowingResult;
    await _setMessageWithDelay('Full garbage collection initiated.');
  }

  Future<void> requestLeaks() async {
    status.status.value = AnalysisStatus.Ongoing;
    await _setMessageWithDelay('Requested details from the application.');

    await _invokeMemoryLeakTrackingExtension(
      <String, dynamic>{
        // TODO(polina-c): reference the constant in Flutter
        // https://github.com/flutter/devtools/issues/3951
        'requestDetails': 'true',
      },
    );
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
}

class _LeaksPaneState extends State<LeaksPane> {
  late _LeaksPaneController _leaksController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _leaksController = _LeaksPaneController();
  }

  @override
  void dispose() {
    _leaksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _leaksController.leakSummaryReceived,
      builder: (_, leakSummaryReceived, __) {
        if (!leakSummaryReceived) {
          return Column(
            children: const [
              _LeaksHelpLink(),
              Text('No information about memory leaks yet.'),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnalysisStatusView(
              controller: _leaksController.status,
              analysisStarter: Row(
                children: [
                  _AnalyzeButton(leaksController: _leaksController),
                  const SizedBox(width: denseSpacing),
                  _ForceGCButton(leaksController: _leaksController),
                  const SizedBox(width: 2 * denseSpacing),
                  const _LeaksHelpLink(),
                ],
              ),
            ),
            const SizedBox(height: denseSpacing),
            Expanded(
              child: SingleChildScrollView(
                child: ValueListenableBuilder<String>(
                  valueListenable: _leaksController.leakSummaryHistory,
                  builder: (_, value, __) => Text(value),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LeaksHelpLink extends StatelessWidget {
  const _LeaksHelpLink({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DocumentationLink(
      url: linkToGuidance,
      gaScreenName: analytics_constants.memory,
      gaSelectedItemDescription:
          analytics_constants.topicDocumentationLink('leaks'),
    );
  }
}

class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({Key? key, required this.leaksController})
      : super(key: key);

  final _LeaksPaneController leaksController;

  @override
  Widget build(BuildContext context) {
    return IconLabelButton(
      label: 'Analyze and Download',
      icon: Icons.download,
      tooltip: 'Analyze the leaks and download the result\n'
          'to ${_filePrefix}_<time>.yaml.',
      onPressed: () async => await leaksController.requestLeaks(),
      minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
    );
  }
}

class _ForceGCButton extends StatelessWidget {
  const _ForceGCButton({Key? key, required this.leaksController})
      : super(key: key);

  final _LeaksPaneController leaksController;

  @override
  Widget build(BuildContext context) {
    return IconLabelButton(
      label: 'Force GC',
      icon: Icons.delete,
      tooltip: 'Force full GC in the application\n'
          'to make sure to collect everything that can be collected.',
      onPressed: () async => await leaksController.forceGC(),
      minScreenWidthForTextBeforeScaling: primaryControlsMinVerboseWidth,
    );
  }
}
