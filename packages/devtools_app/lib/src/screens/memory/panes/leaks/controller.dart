// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:leak_tracker/devtools_integration.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../config_specific/import_export/import_export.dart';
import '../../../../config_specific/logger/logger.dart' as logger;
import '../../../../primitives/utils.dart';
import '../../../../service/service_extensions.dart';
import '../../../../shared/globals.dart';
import '../../primitives/memory_utils.dart';
import 'diagnostics/formatter.dart';
import 'diagnostics/leak_analyzer.dart';
import 'diagnostics/model.dart';
import 'primitives/analysis_status.dart';
import 'primitives/simple_items.dart';
import 'package:vm_service/vm_service.dart';

const yamlFilePrefix = 'memory_leaks';

class LeaksPaneController {
  LeaksPaneController()
      : assert(
          supportedLeakTrackingProtocols.contains(leakTrackerProtocolVersion),
        ) {
    _subscribeForMemoryLeaksMessages();
  }

  final analysisAtatus = AnalysisStatusController();

  final leakSummaryHistory = ValueNotifier<String>('');
  late String appProtocolVersion;
  final appStatus =
      ValueNotifier<AppStatus>(AppStatus.noCommunicationsRecieved);

  LeakSummary? _lastLeakSummary;

  final _exportController = ExportController();

  late StreamSubscription subscriptionWithHistory;
  late StreamSubscription detailsSubscription;

  /// Subscribes for details without history and for all other messages with history.
  void _subscribeForMemoryLeaksMessages() {
    subscriptionWithHistory = serviceManager
        .service!.onExtensionEventWithHistory
        .listen(_onAppMessageWithHistory);

    detailsSubscription =
        serviceManager.service!.onExtensionEvent.listen(_onLeakDetailsReceived);
  }

  void dispose() {
    unawaited(subscriptionWithHistory.cancel());
    unawaited(detailsSubscription.cancel());
    analysisAtatus.dispose();
  }

  static DateTime _fromEpochOrNull(int? microsecondsSinceEpoch) =>
      microsecondsSinceEpoch == null
          ? DateTime.now()
          : DateTime.fromMicrosecondsSinceEpoch(microsecondsSinceEpoch);

  void _onAppMessageWithHistory(Event vmServiceEvent) {
    if (appStatus.value == AppStatus.unsupportedProtocolVersion) return;

    final event = parseFromAppEvent(vmServiceEvent, withHistory: true);
    if (event == null) return;

    if (event is LeakTrackingStarted) {
      appStatus.value = AppStatus.leakTrackingStarted;
      appProtocolVersion = event.protocolVersion;
      return;
    }

    if (event is LeakTrackingSumamry) {
      appStatus.value = AppStatus.leaksFound;
      if (event.leakSummary.matches(_lastLeakSummary)) return;
      _lastLeakSummary = event.leakSummary;

      final time = _fromEpochOrNull(vmServiceEvent.timestamp).toLocal();

      leakSummaryHistory.value =
          '${formatDateTime(time)}: ${event.leakSummary.toMessage()}\n'
          '${leakSummaryHistory.value}';
      return;
    }

    throw StateError('Unsupported event type: ${event.runtimeType}');
  }

  Future<NotGCedAnalyzerTask> _createAnalysisTask(
    List<LeakReport> reports,
  ) async {
    final graph = (await snapshotMemory())!;
    return NotGCedAnalyzerTask.fromSnapshot(graph, reports);
  }

  Future<void> _onLeakDetailsReceived(Event event) async {
    // if (event.extensionKind != _extensionKindToReceiveLeaksDetails) return;
    // if (analysisAtatus.status.value != AnalysisStatus.Ongoing) return;
    // NotGCedAnalyzerTask? task;

    // try {
    //   await _setMessageWithDelay('Received details. Parsing...');
    //   final leakDetails = Leaks.fromJson(event.json!['extensionData']!);

    //   final notGCed = leakDetails.byType[LeakType.notGCed] ?? [];

    //   NotGCedAnalyzed? notGCedAnalyzed;
    //   if (notGCed.isNotEmpty) {
    //     await _setMessageWithDelay('Taking heap snapshot...');
    //     task = await _createAnalysisTask(notGCed);
    //     await _setMessageWithDelay('Detecting retaining paths...');
    //     notGCedAnalyzed = analyseNotGCed(task);
    //   }

    //   await _setMessageWithDelay('Formatting...');

    //   final yaml = analyzedLeaksToYaml(
    //     gcedLate: leakDetails.gcedLate,
    //     notDisposed: leakDetails.notDisposed,
    //     notGCed: notGCedAnalyzed,
    //   );

    //   _saveResultAndSetStatus(yaml, task);
    // } catch (error, trace) {
    //   var message = '${analysisAtatus.message.value}\nError: $error';
    //   if (task != null) {
    //     final fileName = _saveTask(task, DateTime.now());
    //     message += '\nDownloaded raw data to $fileName.';
    //     await _setMessageWithDelay(message);
    //     analysisAtatus.status.value = AnalysisStatus.ShowingError;
    //   }
    //   logger.log(error);
    //   logger.log(trace);
    // }
  }

  void _saveResultAndSetStatus(String yaml, NotGCedAnalyzerTask? task) async {
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
    analysisAtatus.status.value = AnalysisStatus.ShowingResult;
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
    analysisAtatus.message.value = message;
    await delayForBatchProcessing(micros: 5000);
  }

  Future<void> requestLeaks() async {
    analysisAtatus.status.value = AnalysisStatus.Ongoing;
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

  String appStatusMessage() {
    switch (appStatus.value) {
      case AppStatus.leakTrackingNotSupported:
        return 'The application does not support leak tracking.';
      case AppStatus.noCommunicationsRecieved:
        return 'Waiting for leak tracking messages from the application...';
      case AppStatus.unsupportedProtocolVersion:
        return 'The application uses unsupported leak tracking protocol $appProtocolVersion. '
            'Upgrade to newer version of leak_tracker to switch to one of supported protocols: $supportedLeakTrackingProtocols.';
      case AppStatus.leakTrackingStarted:
        return 'Leak tracking started. No leaks communicated so far.';
      case AppStatus.leaksFound:
        throw StateError('there is no UI message for ${AppStatus.leaksFound}.');
    }
  }
}
