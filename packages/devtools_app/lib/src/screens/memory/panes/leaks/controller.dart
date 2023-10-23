// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

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
    subscriptionWithHistory = serviceConnection
        .serviceManager.service!.onExtensionEventWithHistory
        .listen(_onAppMessageWithHistory);
  }

  final analysisStatus = AnalysisStatusController();

  final leakSummaryHistory = ValueNotifier<String>('');
  late String appProtocolVersion;
  final appStatus =
      ValueNotifier<AppStatus>(AppStatus.noCommunicationsReceived);

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

      _addToLeakSummaryHistory(
        '${formatDateTime(message.time)}: ${message.toMessage()}',
      );

      return;
    }

    throw StateError('Unsupported event type: ${message.runtimeType}');
  }

  Future<NotGCedAnalyzerTask> _createAnalysisTask(
    List<LeakReport> reports,
  ) async {
    final graph = (await snapshotMemoryInSelectedIsolate())!;
    return NotGCedAnalyzerTask.fromSnapshot(graph, reports);
  }

  Future<void> requestLeaksAndSaveToYaml() async {
    try {
      analysisStatus.status.value = AnalysisStatus.ongoing;
      await _setMessageWithDelay('Requested details from the application.');

      final leakDetails =
          await _invokeLeakExtension<RequestForLeakDetails, Leaks>(
        RequestForLeakDetails(),
      );

      _addToLeakSummaryHistory('Collected leaks.');

      final notGCed = leakDetails.byType[LeakType.notGCed] ?? [];

      NotGCedAnalyzerTask? task;
      NotGCedAnalyzed? notGCedAnalyzed;

      if (notGCed.isNotEmpty) {
        await _setMessageWithDelay('Taking heap snapshot...');
        task = await _createAnalysisTask(notGCed);
        await _setMessageWithDelay('Detecting retaining paths...');
        notGCedAnalyzed = await analyzeNotGCed(task);
      }

      await _setMessageWithDelay('Formatting...');

      final yaml = analyzedLeaksToYaml(
        gcedLate: leakDetails.gcedLate,
        notDisposed: leakDetails.notDisposed,
        notGCed: notGCedAnalyzed,
      );

      _saveResultAndSetAnalysisStatus(yaml);
    } catch (error) {
      analysisStatus.message.value = 'Error: $error';
      analysisStatus.status.value = AnalysisStatus.showingError;
    }
  }

  void _saveResultAndSetAnalysisStatus(String yaml) {
    final now = DateTime.now();
    final yamlFile = ExportController.generateFileName(
      time: now,
      prefix: yamlFilePrefix,
      type: ExportFileType.yaml,
    );
    _exportController.downloadFile(yaml, fileName: yamlFile);

    analysisStatus.status.value = AnalysisStatus.showingResult;
  }

  Future<void> _setMessageWithDelay(String message) async {
    analysisStatus.message.value = message;
    await delayToReleaseUiThread(micros: 5000);
  }

  Future<R> _invokeLeakExtension<M extends Object, R extends Object>(
    M message,
  ) async {
    final response =
        await serviceConnection.serviceManager.service!.callServiceExtension(
      memoryLeakTrackingExtensionName,
      isolateId: serviceConnection
          .serviceManager.isolateManager.mainIsolate.value!.id!,
      args: RequestToApp(message).toRequestParameters(),
    );

    return ResponseFromApp<R>.fromServiceResponse(response).message;
  }

  String appStatusMessage() {
    switch (appStatus.value) {
      case AppStatus.leakTrackingNotSupported:
        return 'The application does not support leak tracking.';
      case AppStatus.noCommunicationsReceived:
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

  void _addToLeakSummaryHistory(String entry) {
    leakSummaryHistory.value = '$entry\n'
        '${leakSummaryHistory.value}';
  }
}
