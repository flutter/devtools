// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:leak_tracker/devtools_integration.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/config_specific/import_export/import_export.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/utils.dart';
import '../../shared/primitives/memory_utils.dart';
import 'diagnostics/formatter.dart';
import 'diagnostics/leak_analyzer.dart';
import 'diagnostics/model.dart';
import 'primitives/analysis_status.dart';
import 'primitives/simple_items.dart';

const yamlFilePrefix = 'memory_leaks';

class LeaksPaneController {
  LeaksPaneController()
      : assert(
          supportedLeakTrackingProtocols
              .contains(appLeakTrackerProtocolVersion),
        ) {
    subscriptionWithHistory = serviceManager
        .service!.onExtensionEventWithHistory
        .listen(_onAppMessageWithHistory);
  }

  final analysisStatus = AnalysisStatusController();

  final leakSummaryHistory = ValueNotifier<String>('');
  late String appProtocolVersion;
  final appStatus =
      ValueNotifier<AppStatus>(AppStatus.noCommunicationsRecieved);

  LeakSummary? _lastLeakSummary;

  final _exportController = ExportController();

  late StreamSubscription subscriptionWithHistory;

  void dispose() {
    unawaited(subscriptionWithHistory.cancel());
    analysisStatus.dispose();
  }

  void _onAppMessageWithHistory(Event vmServiceEvent) {
    if (appStatus.value == AppStatus.unsupportedProtocolVersion) return;

    final message = EventFromApp.fromVmServiceEvent(vmServiceEvent)?.message;
    if (message == null) return;

    if (message is LeakTrackingStarted) {
      appStatus.value = AppStatus.leakTrackingStarted;
      appProtocolVersion = message.protocolVersion;
      return;
    }

    if (message is LeakSummary) {
      appStatus.value = AppStatus.leaksFound;
      if (message.matches(_lastLeakSummary)) return;
      _lastLeakSummary = message;

      leakSummaryHistory.value =
          '${formatDateTime(message.time)}: ${message.toMessage()}\n'
          '${leakSummaryHistory.value}';
      return;
    }

    throw StateError('Unsupported event type: ${message.runtimeType}');
  }

  Future<NotGCedAnalyzerTask> _createAnalysisTask(
    List<LeakReport> reports,
  ) async {
    final graph = (await snapshotMemory())!;
    return NotGCedAnalyzerTask.fromSnapshot(graph, reports);
  }

  Future<void> requestLeaksAndSaveToYaml() async {
    try {
      analysisStatus.status.value = AnalysisStatus.Ongoing;
      await _setMessageWithDelay('Requested details from the application.');

      final leakDetails =
          await _invokeLeakExtension<RequestForLeakDetails, Leaks>(
        RequestForLeakDetails(),
      );

      final notGCed = leakDetails.byType[LeakType.notGCed] ?? [];

      NotGCedAnalyzerTask? task;
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

      _saveResultAndSetAnalysisStatus(yaml, task);
    } catch (error) {
      analysisStatus.message.value = 'Error: $error';
      analysisStatus.status.value = AnalysisStatus.ShowingError;
    }
  }

  void _saveResultAndSetAnalysisStatus(
    String yaml,
    NotGCedAnalyzerTask? task,
  ) async {
    final now = DateTime.now();
    final yamlFile = ExportController.generateFileName(
      time: now,
      prefix: yamlFilePrefix,
      type: ExportFileType.yaml,
    );
    _exportController.downloadFile(yaml, fileName: yamlFile);
    final String? taskFile = _saveTask(task, now);

    final taskFileMessage = taskFile == null ? '' : ' and $taskFile';
    await _setMessageWithDelay(
      'Downloaded the leak analysis to $yamlFile$taskFileMessage.',
    );
    analysisStatus.status.value = AnalysisStatus.ShowingResult;
  }

  /// Saves raw analysis task for troubleshooting and deeper analysis.
  String? _saveTask(NotGCedAnalyzerTask? task, DateTime? now) {
    if (task == null) return null;

    final json = jsonEncode(task.toJson());
    final jsonFile = ExportController.generateFileName(
      time: now,
      prefix: yamlFilePrefix,
      postfix: '.raw',
      type: ExportFileType.json,
    );
    return _exportController.downloadFile(json, fileName: jsonFile);
  }

  Future<void> _setMessageWithDelay(String message) async {
    analysisStatus.message.value = message;
    await delayForBatchProcessing(micros: 5000);
  }

  Future<R> _invokeLeakExtension<M extends Object, R extends Object>(
    M message,
  ) async {
    final response = await serviceManager.service!.callServiceExtension(
      memoryLeakTrackingExtensionName,
      isolateId: serviceManager.isolateManager.mainIsolate.value!.id!,
      args: RequestToApp(message).toRequestParameters(),
    );

    return ResponseFromApp<R>.fromServiceResponse(response).message;
  }

  String appStatusMessage() {
    switch (appStatus.value) {
      case AppStatus.leakTrackingNotSupported:
        return 'The application does not support leak tracking.';
      case AppStatus.noCommunicationsRecieved:
        return 'Waiting for leak tracking messages from the application...';
      case AppStatus.unsupportedProtocolVersion:
        return 'The application uses unsupported leak tracking protocol $appProtocolVersion. '
            'Upgrade to a newer version of leak_tracker to switch to one of supported protocols: $supportedLeakTrackingProtocols.';
      case AppStatus.leakTrackingStarted:
        return 'Leak tracking started. No leaks communicated so far.';
      case AppStatus.leaksFound:
        throw StateError('There is no UI message for ${AppStatus.leaksFound}.');
    }
  }
}
