// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/globals.dart';

import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/filter.dart';
import '../../../shared/utils.dart';
import 'logging_controller_v2.dart';
import 'logging_table_row.dart';
import 'logging_table_v2.dart';

const _gcLogKind = 'gc';

final _verboseFlutterFrameworkLogKinds = <String>{
  FlutterEvent.firstFrame,
  FlutterEvent.frameworkInitialization,
  FlutterEvent.frame,
  FlutterEvent.imageSizesForFrame,
};

final _verboseFlutterServiceLogKinds = <String>{
  FlutterEvent.serviceExtensionStateChanged,
};

/// Log kinds to show without a summary in the table.
final _hideSummaryLogKinds = <String>{
  FlutterEvent.firstFrame,
  FlutterEvent.frameworkInitialization,
};

/// A class for holding state and state changes relevant to [LoggingControllerV2]
/// and [LoggingTableV2].
///
/// The [LoggingTableV2] table uses variable height rows. This model caches the
/// relevant heights and offsets so that the row heights only need to be calculated
/// once per parent width.
class LoggingTableModel extends DisposableController
    with ChangeNotifier, DisposerMixin, FilterControllerMixin<LogDataV2> {
  LoggingTableModel() {
    _worker = InterruptableChunkWorker(
      callback: (index) => getLogHeight(
        index,
      ),
      progressCallback: (progress) => _cacheLoadProgress.value = progress,
    );

    _retentionLimit = preferences.logging.retentionLimit.value;

    addAutoDisposeListener(
      preferences.logging.retentionLimit,
      _onRetentionLimitUpdate,
    );

    _retentionLimit = preferences.logging.retentionLimit.value;
    subscribeToFilterChanges();
  }

  final _logs = ListQueue<_LogEntry>();

  /// [FilterControllerMixin] uses [ListValueNotifier] which isn't well optimized to the
  /// retention limit behavior that [LoggingTableModel] uses. So we use
  /// [ListQueue] here to facilitate those actions. Then instead of
  /// using [FilterControllerMixin.filteredLogs] in [FilterControllerMixin.filterData],
  /// we use [_filteredLogs]. After any changes are done to [_filteredLogs], [notifyListeners]
  /// must be manually triggered, since the listener behaviour is accomplished by the
  /// [LoggingTableModel] being a [ChangeNotifier].
  final _filteredLogs = ListQueue<_FilteredLogEntry>();

  final _selectedLogs = ListQueue<LogDataV2>();
  late int _retentionLimit;

  late final InterruptableChunkWorker _worker;

  /// Represents the state of reloading the height caches.
  ///
  /// When null, then the cache is not loading.
  /// When double, then the value is represents how much progress has been made.
  ValueListenable<double?> get cacheLoadProgress => _cacheLoadProgress;
  final _cacheLoadProgress = ValueNotifier<double?>(null);

  void _onRetentionLimitUpdate() {
    _retentionLimit = preferences.logging.retentionLimit.value;
    while (_logs.length > _retentionLimit) {
      _trimOneOutOfRetentionLog();
    }
    _recalculateOffsets();
    notifyListeners();
  }

  void _recalculateOffsets() {
    double runningOffset = 0.0;
    for (var i = 0; i < _filteredLogs.length; i++) {
      _filteredLogs.elementAt(i).offset = runningOffset;
      runningOffset += getFilteredLogHeight(i);
    }
  }

  @override
  void dispose() {
    _cacheLoadProgress.dispose();
    _worker.dispose();
    super.dispose();
  }

  @override
  void filterData(Filter<LogDataV2> filter) {
    super.filterData(filter);

    _filteredLogs
      ..clear()
      ..addAll(
        _logs.where(_filterCallback).map((e) => _FilteredLogEntry(e)).toList(),
      );
    _recalculateOffsets();
    notifyListeners();
  }

  bool _filterCallback(_LogEntry entry) {
    final filter = activeFilter.value;

    final log = entry.log;
    final filteredOutByToggleFilters = filter.toggleFilters.any(
      (toggleFilter) =>
          toggleFilter.enabled.value && !toggleFilter.includeCallback(log),
    );
    if (filteredOutByToggleFilters) return false;

    final queryFilter = filter.queryFilter;
    if (!queryFilter.isEmpty) {
      final filteredOutByQueryFilterArgument = queryFilter
          .filterArguments.values
          .any((argument) => !argument.matchesValue(log));
      if (filteredOutByQueryFilterArgument) return false;

      if (filter.queryFilter.substringExpressions.isNotEmpty) {
        for (final substring in filter.queryFilter.substringExpressions) {
          final matchesKind = log.kind.caseInsensitiveContains(substring);
          if (matchesKind) return true;

          final matchesSummary = log.summary != null &&
              log.summary!.caseInsensitiveContains(substring);
          if (matchesSummary) return true;

          final matchesDetails = log.details != null &&
              log.details!.caseInsensitiveContains(substring);
          if (matchesDetails) return true;
        }
        return false;
      }
    }

    return true;
  }

  double get tableWidth => _tableWidth;

  /// Update the width of the table.
  ///
  /// If different from the last width, this will flush all of the calculated heights, and recalculate their heights
  /// in the background.
  set tableWidth(double width) {
    if (width != _tableWidth) {
      _tableWidth = width;
      for (final log in _logs) {
        log.height = null;
      }
      for (final log in _filteredLogs) {
        log.offset = null;
      }
      unawaited(_preFetchRowHeights());
    }
  }

  /// Get the filtered log at [index].
  LogDataV2 filteredLogAt(int index) =>
      _filteredLogs.elementAt(index).logEntry.log;

  double _tableWidth = 0.0;

  /// The total number of logs being held by the [LoggingTableModel].
  int get logCount => _logs.length;

  /// The number of filtered logs.
  int get filteredLogCount => _filteredLogs.length;

  /// The number of selected logs.
  int get selectedLogCount => _selectedLogs.length;

  void _handleConnectionStart(VmServiceWrapper service) {
    // Log stdout events.
    final stdoutHandler = _StdoutEventHandler(this, 'stdout');
    autoDisposeStreamSubscription(
      service.onStdoutEventWithHistorySafe.listen(stdoutHandler.handle),
    );

    // Log stderr events.
    final stderrHandler = _StdoutEventHandler(this, 'stderr', isError: true);
    autoDisposeStreamSubscription(
      service.onStderrEventWithHistorySafe.listen(stderrHandler.handle),
    );

    // Log GC events.
    autoDisposeStreamSubscription(service.onGCEvent.listen(_handleGCEvent));

    // Log `dart:developer` `log` events.
    autoDisposeStreamSubscription(
      service.onLoggingEventWithHistorySafe.listen(_handleDeveloperLogEvent),
    );

    // Log Flutter extension events.
    autoDisposeStreamSubscription(
      service.onExtensionEventWithHistorySafe.listen(_handleExtensionEvent),
    );
  }

  void _handleExtensionEvent(Event e) {
    if (e.extensionKind == FlutterEvent.frame) {
      final frame = FrameInfo(e.extensionData!.data);

      final frameId = '#${frame.number}';
      final frameInfoText =
          '$frameId ${frame.elapsedMs.toStringAsFixed(1).padLeft(4)}ms ';

      log(
        LogData(
          e.extensionKind!.toLowerCase(),
          jsonEncode(e.extensionData!.data),
          e.timestamp,
          summary: frameInfoText,
        ),
      );
    } else if (e.extensionKind == FlutterEvent.imageSizesForFrame) {
      final images = ImageSizesForFrame.from(e.extensionData!.data);

      for (final image in images) {
        log(
          LogData(
            e.extensionKind!.toLowerCase(),
            jsonEncode(image.json),
            e.timestamp,
            summary: image.summary,
          ),
        );
      }
    } else if (e.extensionKind == FlutterEvent.navigation) {
      final navInfo = NavigationInfo.from(e.extensionData!.data);

      log(
        LogData(
          e.extensionKind!.toLowerCase(),
          jsonEncode(e.json),
          e.timestamp,
          summary: navInfo.routeDescription,
        ),
      );
    } else if (_hideSummaryLogKinds.contains(e.extensionKind)) {
      log(
        LogData(
          e.extensionKind!.toLowerCase(),
          jsonEncode(e.json),
          e.timestamp,
          summary: '',
        ),
      );
    } else if (e.extensionKind == FlutterEvent.serviceExtensionStateChanged) {
      final changedInfo =
          ServiceExtensionStateChangedInfo.from(e.extensionData!.data);

      log(
        LogData(
          e.extensionKind!.toLowerCase(),
          jsonEncode(e.json),
          e.timestamp,
          summary: '${changedInfo.extension}: ${changedInfo.value}',
        ),
      );
    } else if (e.extensionKind == FlutterEvent.error) {
      // TODO(pq): add tests for error extension handling once framework changes
      // are landed.
      final node = RemoteDiagnosticsNode(
        e.extensionData!.data,
        objectGroup,
        false,
        null,
      );
      // Workaround the fact that the error objects from the server don't have
      // style error.
      node.style = DiagnosticsTreeStyle.error;
      if (_verboseDebugging) {
        _log.info('node toStringDeep:######\n${node.toStringDeep()}\n###');
      }

      final summary = _findFirstSummary(node) ?? node;
      log(
        LogData(
          e.extensionKind!.toLowerCase(),
          jsonEncode(e.extensionData!.data),
          e.timestamp,
          summary: summary.toDiagnosticsNode().toString(),
        ),
      );
    } else {
      log(
        LogData(
          e.extensionKind!.toLowerCase(),
          jsonEncode(e.json),
          e.timestamp,
          summary: e.json.toString(),
        ),
      );
    }
  }

  void _handleGCEvent(Event e) {
    final newSpace = HeapSpace.parse(e.json!['new'])!;
    final oldSpace = HeapSpace.parse(e.json!['old'])!;
    final isolateRef = (e.json!['isolate'] as Map).cast<String, Object?>();

    final usedBytes = newSpace.used! + oldSpace.used!;
    final capacityBytes = newSpace.capacity! + oldSpace.capacity!;

    final time = ((newSpace.time! + oldSpace.time!) * 1000).round();

    final summary = '${isolateRef['name']} • '
        '${e.json!['reason']} collection in $time ms • '
        '${printBytes(usedBytes, unit: ByteUnit.mb, includeUnit: true)} used of '
        '${printBytes(capacityBytes, unit: ByteUnit.mb, includeUnit: true)}';

    final event = <String, Object>{
      'reason': e.json!['reason'],
      'new': newSpace.json,
      'old': oldSpace.json,
      'isolate': isolateRef,
    };

    final message = jsonEncode(event);
    log(LogData('gc', message, e.timestamp, summary: summary));
  }

  void _handleDeveloperLogEvent(Event e) {
    final service = serviceConnection.serviceManager.service;

    final logRecord = _LogRecord(e.json!['logRecord']);

    String? loggerName =
        _valueAsString(InstanceRef.parse(logRecord.loggerName));
    if (loggerName == null || loggerName.isEmpty) {
      loggerName = 'log';
    }
    final level = logRecord.level;
    final messageRef = InstanceRef.parse(logRecord.message)!;
    String? summary = _valueAsString(messageRef);
    if (messageRef.valueAsStringIsTruncated == true) {
      summary = '${summary!}...';
    }
    final error = InstanceRef.parse(logRecord.error);
    final stackTrace = InstanceRef.parse(logRecord.stackTrace);

    final details = summary;
    Future<String> Function()? detailsComputer;

    // If the message string was truncated by the VM, or the error object or
    // stackTrace objects were non-null, we need to ask the VM for more
    // information in order to render the log entry. We do this asynchronously
    // on-demand using the `detailsComputer` Future.
    if (messageRef.valueAsStringIsTruncated == true ||
        _isNotNull(error) ||
        _isNotNull(stackTrace)) {
      detailsComputer = () async {
        // Get the full string value of the message.
        String result =
            await _retrieveFullStringValue(service, e.isolate!, messageRef);

        // Get information about the error object. Some users of the
        // dart:developer log call may pass a data payload in the `error`
        // field, encoded as a json encoded string, so handle that case.
        if (_isNotNull(error)) {
          if (error!.valueAsString != null) {
            final errorString =
                await _retrieveFullStringValue(service, e.isolate!, error);
            result += '\n\n$errorString';
          } else {
            // Call `toString()` on the error object and display that.
            final toStringResult = await service!.invoke(
              e.isolate!.id!,
              error.id!,
              'toString',
              <String>[],
              disableBreakpoints: true,
            );

            if (toStringResult is ErrorRef) {
              final errorString = _valueAsString(error);
              result += '\n\n$errorString';
            } else if (toStringResult is InstanceRef) {
              final str = await _retrieveFullStringValue(
                service,
                e.isolate!,
                toStringResult,
              );
              result += '\n\n$str';
            }
          }
        }

        // Get info about the stackTrace object.
        if (_isNotNull(stackTrace)) {
          result += '\n\n${_valueAsString(stackTrace)}';
        }

        return result;
      };
    }

    const severeIssue = 1000;
    final isError = level != null && level >= severeIssue ? true : false;

    log(
      LogData(
        loggerName,
        details,
        e.timestamp,
        isError: isError,
        summary: summary,
        detailsComputer: detailsComputer,
      ),
    );
  }

  /// Add a log to the list of tracked logs.
  void add(LogDataV2 log) {
    final newEntry = _LogEntry(log);
    _logs.add(newEntry);
    getLogHeight(_logs.length - 1);
    _trimOneOutOfRetentionLog();

    if (!_filterCallback(newEntry)) {
      // Only add the log to filtered logs if it matches the filter.
      return;
    }
    _filteredLogs.add(_FilteredLogEntry(newEntry));

    // TODO(danchevalier): Calculate the new offset here

    notifyListeners();
  }

  void _trimOneOutOfRetentionLog() {
    if (_logs.length > _retentionLimit) {
      if (identical(_logs.first.log, _filteredLogs.first.logEntry.log)) {
        // Remove a filtered log if it is about to go out of retention.
        _filteredLogs.removeFirst();
      }

      // Remove the log that has just gone out of retention.
      _logs.removeFirst();
    }
  }

  /// Clears all of the logs from the model.
  void clear() {
    _logs.clear();
    _filteredLogs.clear();
    notifyListeners();
  }

  /// Get the offset of a filtered log, at [index], from the top of the list of filtered logs.
  double filteredLogOffsetAt(int _) {
    throw Exception('Implement this when needed');
  }

  double getLogHeight(int index) {
    final entry = _logs.elementAt(index);
    final cachedHeight = entry.height;
    if (cachedHeight != null) return cachedHeight;
    return entry.height ??= LoggingTableRow.calculateRowHeight(
      entry.log,
      _tableWidth,
    );
  }

  /// Get the height of a filtered Log at [index].
  double getFilteredLogHeight(int index) {
    final filteredLog = _filteredLogs.elementAt(index);
    final cachedHeight = filteredLog.logEntry.height;
    if (cachedHeight != null) return cachedHeight;

    return filteredLog.logEntry.height ??= LoggingTableRow.calculateRowHeight(
      filteredLog.logEntry.log,
      _tableWidth,
    );
  }

  Future<bool> _preFetchRowHeights() async {
    final didComplete = await _worker.doWork(_logs.length);
    if (didComplete) {
      _cacheLoadProgress.value = null;
    }
    _recalculateOffsets();
    return didComplete;
  }

  /// The toggle filters available for the Logging screen.
  @override
  List<ToggleFilter<LogDataV2>> createToggleFilters() => [
        if (serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ??
            true) ...[
          ToggleFilter<LogDataV2>(
            name: 'Hide verbose Flutter framework logs (initialization, frame '
                'times, image sizes)',
            includeCallback: (log) => !_verboseFlutterFrameworkLogKinds
                .any((kind) => kind.caseInsensitiveEquals(log.kind)),
            enabledByDefault: true,
          ),
          ToggleFilter<LogDataV2>(
            name: 'Hide verbose Flutter service logs (service extension state '
                'changes)',
            includeCallback: (log) => !_verboseFlutterServiceLogKinds
                .any((kind) => kind.caseInsensitiveEquals(log.kind)),
            enabledByDefault: true,
          ),
        ],
        ToggleFilter<LogDataV2>(
          name: 'Hide garbage collection logs',
          includeCallback: (log) => !log.kind.caseInsensitiveEquals(_gcLogKind),
          enabledByDefault: true,
        ),
      ];
}

class _LogEntry {
  _LogEntry(this.log);
  final LogDataV2 log;
  double? height;
}

class _FilteredLogEntry {
  _FilteredLogEntry(this.logEntry);
  final _LogEntry logEntry;
  double? offset;
}
