// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:vm_service/vm_service.dart';

import '../../service/vm_service_wrapper.dart';
import '../../shared/diagnostics/diagnostics_node.dart';
import '../../shared/diagnostics/inspector_service.dart';
import '../../shared/framework/app_error_handling.dart' as error_handling;
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/byte_utils.dart';
import '../../shared/primitives/message_bus.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import '../inspector/inspector_tree_controller.dart';
import 'logging_screen.dart';
import 'metadata.dart';

final _log = Logger('logging_controller');

const defaultLogBufferReductionSize = 500;
final timeFormat = DateFormat('HH:mm:ss.SSS');
final dateTimeFormat = DateFormat('HH:mm:ss.SSS (MM/dd/yy)');

bool _verboseDebugging = false;

typedef OnShowDetails =
    void Function({String? text, InspectorTreeController? tree});

typedef CreateLoggingTree =
    InspectorTreeController Function({VoidCallback? onSelectionChange});

typedef ZoneDescription = ({String? name, int? identityHashCode});

Future<String> _retrieveFullStringValue(
  VmServiceWrapper? service,
  IsolateRef isolateRef,
  InstanceRef stringRef,
) {
  final fallback = '${stringRef.valueAsString}...';
  // TODO(kenz): why is service null?

  return service
          ?.retrieveFullStringValue(
            isolateRef.id!,
            stringRef,
            onUnavailable: (truncatedValue) => fallback,
          )
          .then((value) => value ?? fallback) ??
      Future.value(fallback);
}

const _gcLogKind = 'gc';

final _verboseFlutterFrameworkLogKinds = [
  FlutterEvent.firstFrame,
  FlutterEvent.frameworkInitialization,
  FlutterEvent.frame,
  FlutterEvent.imageSizesForFrame,
];

final _verboseFlutterServiceLogKinds = [
  FlutterEvent.serviceExtensionStateChanged,
];

/// Log kinds to show without a summary in the table.
final _hideSummaryLogKinds = <String>{
  FlutterEvent.firstFrame,
  FlutterEvent.frameworkInitialization,
};

/// Screen controller for the Logging screen.
///
/// This controller can be accessed from anywhere in DevTools, as long as it was
/// first registered, by
/// calling `screenControllers.lookup<LoggingController>()`.
///
/// The controller lifecycle is managed by the [ScreenControllers] class. The
/// `init` method is called lazily upon the first controller access from
/// `screenControllers`. The `dispose` method is called by `screenControllers`
/// when DevTools is destroying a set of DevTools screen controllers.
class LoggingController extends DevToolsScreenController
    with
        SearchControllerMixin<LogData>,
        FilterControllerMixin<LogData>,
        AutoDisposeControllerMixin {
  static const _minLogLevelFilterId = 'min-log-level';
  static const _verboseFlutterFrameworkFilterId = 'verbose-flutter-framework';
  static const _verboseFlutterServiceFilterId = 'verbose-flutter-service';
  static const _gcFilterId = 'gc';

  @override
  void init() {
    super.init();
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        _handleConnectionStart(serviceConnection.serviceManager.service!);

        autoDisposeStreamSubscription(
          serviceConnection.serviceManager.service!.onIsolateEvent.listen((
            event,
          ) {
            messageBus.addEvent(BusEvent('debugger', data: event));
          }),
        );
      }
    });
    if (serviceConnection.serviceManager.connectedAppInitialized) {
      _handleConnectionStart(serviceConnection.serviceManager.service!);
    }
    _handleBusEvents();
    initFilterController();

    addAutoDisposeListener(
      preferences.logging.retentionLimit,
      // When the retention limit setting changes, trim the logs to the exact
      // length of the limit.
      () => _updateForRetentionLimit(trimWithBuffer: false),
    );
  }

  @override
  void dispose() {
    selectedLog.dispose();
    unawaited(_logStatusController.close());
    super.dispose();
  }

  /// The setting filters available for the Logging screen.
  @override
  SettingFilters<LogData> createSettingFilters() => loggingSettingFilters;

  @visibleForTesting
  static final loggingSettingFilters = <SettingFilter<LogData, Object>>[
    SettingFilter<LogData, int>(
      id: _minLogLevelFilterId,
      name: 'Hide logs below the minimum log level',
      includeCallback:
          (LogData element, int currentFilterValue) =>
              element.level >= currentFilterValue,
      enabledCallback: (int filterValue) => filterValue > Level.ALL.value,
      possibleValues: _possibleLogLevels.map((l) => l.value).toList(),
      possibleValueDisplays: _possibleLogLevels.map((l) => l.name).toList(),
      defaultValue: Level.ALL.value,
    ),
    if (serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ??
        true) ...[
      ToggleFilter<LogData>(
        id: _verboseFlutterFrameworkFilterId,
        name:
            'Hide verbose Flutter framework logs (initialization, frame '
            'times, image sizes)',
        includeCallback:
            (log) =>
                !_verboseFlutterFrameworkLogKinds.any(
                  (kind) => kind.caseInsensitiveEquals(log.kind),
                ),
        defaultValue: true,
      ),
      ToggleFilter<LogData>(
        id: _verboseFlutterServiceFilterId,
        name:
            'Hide verbose Flutter service logs (service extension state '
            'changes)',
        includeCallback:
            (log) =>
                !_verboseFlutterServiceLogKinds.any(
                  (kind) => kind.caseInsensitiveEquals(log.kind),
                ),
        defaultValue: true,
      ),
    ],
    ToggleFilter<LogData>(
      id: _gcFilterId,
      name: 'Hide garbage collection logs',
      includeCallback: (log) => !log.kind.caseInsensitiveEquals(_gcLogKind),
      defaultValue: true,
    ),
  ];

  static final _possibleLogLevels = Level.LEVELS
  // Omit Level.OFF from the possible minimum levels.
  .where((level) => level != Level.OFF);

  static const _kindFilterId = 'logging-kind-filter';
  static const _isolateFilterId = 'logging-isolate-filter';
  static const _zoneFilterId = 'logging-zone-filter';

  @override
  Map<String, QueryFilterArgument<LogData>> createQueryFilterArgs() =>
      loggingQueryFilterArgs;

  @visibleForTesting
  static final loggingQueryFilterArgs = <String, QueryFilterArgument<LogData>>{
    _kindFilterId: QueryFilterArgument<LogData>(
      keys: ['kind', 'k'],
      exampleUsages: ['k:stderr', '-k:stdout,gc'],
      dataValueProvider: (log) => log.kind,
      substringMatch: true,
    ),
    _isolateFilterId: QueryFilterArgument<LogData>(
      keys: ['isolate', 'i'],
      exampleUsages: ['i:main', '-i:worker'],
      dataValueProvider: (log) => log.isolateRef?.name,
      substringMatch: true,
    ),
    _zoneFilterId: QueryFilterArgument<LogData>(
      keys: ['zone', 'z'],
      exampleUsages: ['z:custom', '-z:root'],
      dataValueProvider: (log) => log.zone?.name,
      substringMatch: true,
    ),
  };

  @override
  ValueNotifier<String>? get filterTagNotifier => preferences.logging.filterTag;

  /// A stream of events for the textual description of the log contents.
  ///
  /// See also [statusText].
  Stream<String> get onLogStatusChanged => _logStatusController.stream;

  final _logStatusController = StreamController<String>.broadcast();

  List<LogData> data = <LogData>[];

  final selectedLog = ValueNotifier<LogData?>(null);

  void _updateData(List<LogData> logs) {
    data = logs;
    filterData(activeFilter.value);
    refreshSearchMatches();
    _updateSelection();
    _updateStatus();
  }

  void _updateSelection() {
    final selected = selectedLog.value;
    if (selected != null) {
      final logs = filteredData.value;
      if (!logs.contains(selected)) {
        selectedLog.value = null;
      }
    }
  }

  ObjectGroup get objectGroup =>
      serviceConnection.consoleService.objectGroup as ObjectGroup;

  String get statusText {
    final totalCount = data.length;
    final showingCount = filteredData.value.length;

    String label;

    label =
        totalCount == showingCount
            ? nf.format(totalCount)
            : 'showing ${nf.format(showingCount)} of '
                '${nf.format(totalCount)}';

    label = '$label ${pluralize('event', totalCount)}';

    return label;
  }

  void _updateStatus() {
    final label = statusText;
    _logStatusController.add(label);
  }

  void clear() {
    _updateData([]);
    serviceConnection.errorBadgeManager.clearErrors(LoggingScreen.id);
  }

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
    final kind = e.extensionKind!.toLowerCase();
    final timestamp = e.timestamp;
    final isolateRef = e.isolate;

    if (e.extensionKind == FlutterEvent.frame) {
      final frame = FrameInfo(e.extensionData!.data);

      final frameId = '#${frame.number}';
      final frameInfoText =
          '$frameId ${frame.elapsedMs.toStringAsFixed(1).padLeft(4)}ms ';

      log(
        LogData(
          kind,
          jsonEncode(e.extensionData!.data),
          timestamp,
          summary: frameInfoText,
          isolateRef: isolateRef,
        ),
      );
    } else if (e.extensionKind == FlutterEvent.imageSizesForFrame) {
      final images = ImageSizesForFrame.from(e.extensionData!.data);

      for (final image in images) {
        log(
          LogData(
            kind,
            jsonEncode(image.json),
            timestamp,
            summary: image.summary,
            isolateRef: isolateRef,
          ),
        );
      }
    } else if (e.extensionKind == FlutterEvent.navigation) {
      final navInfo = NavigationInfo.from(e.extensionData!.data);

      log(
        LogData(
          kind,
          jsonEncode(e.json),
          timestamp,
          summary: navInfo.routeDescription,
          isolateRef: isolateRef,
        ),
      );
    } else if (_hideSummaryLogKinds.contains(e.extensionKind)) {
      log(
        LogData(
          kind,
          jsonEncode(e.json),
          timestamp,
          summary: '',
          isolateRef: isolateRef,
        ),
      );
    } else if (e.extensionKind == FlutterEvent.serviceExtensionStateChanged) {
      final changedInfo = ServiceExtensionStateChangedInfo.from(
        e.extensionData!.data,
      );

      log(
        LogData(
          kind,
          jsonEncode(e.json),
          timestamp,
          summary: '${changedInfo.extension}: ${changedInfo.value}',
          isolateRef: isolateRef,
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
          kind,
          jsonEncode(e.extensionData!.data),
          timestamp,
          summary: summary.toDiagnosticsNode().toString(),
          level: Level.SEVERE.value,
          isError: true,
          isolateRef: isolateRef,
        ),
      );
    } else {
      log(
        LogData(
          kind,
          jsonEncode(e.json),
          timestamp,
          summary: e.json.toString(),
          isolateRef: isolateRef,
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

    final summary =
        '${isolateRef['name']} • '
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
    log(
      LogData(
        _gcFilterId,
        message,
        e.timestamp,
        summary: summary,
        isolateRef: e.isolateRef,
      ),
    );
  }

  void _handleDeveloperLogEvent(Event e) {
    final eventJson = e.json!;
    final service = serviceConnection.serviceManager.service;

    final logRecord = _LogRecord(eventJson['logRecord']);

    String? loggerName = _valueAsString(
      InstanceRef.parse(logRecord.loggerName),
    );
    if (loggerName == null || loggerName.isEmpty) {
      loggerName = 'log';
    }

    final level = logRecord.level;

    final zoneInstanceRef = InstanceRef.parse(logRecord.zone);
    final zone = (
      name: zoneInstanceRef?.classRef?.name,
      identityHashCode: zoneInstanceRef?.identityHashCode,
    );

    final messageRef = InstanceRef.parse(logRecord.message)!;
    String? summary = _valueAsString(messageRef);
    if (messageRef.valueAsStringIsTruncated == true) {
      summary = '${summary!}...';
    }
    final error = InstanceRef.parse(logRecord.error);
    final stackTrace = InstanceRef.parse(logRecord.stackTrace);

    // TODO(kenz): we may want to narrow down the details of dart developer logs
    final details = jsonEncode(e.json);
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
        String result = await _retrieveFullStringValue(
          service,
          e.isolate!,
          messageRef,
        );

        // Get information about the error object. Some users of the
        // dart:developer log call may pass a data payload in the `error`
        // field, encoded as a json encoded string, so handle that case.
        if (_isNotNull(error)) {
          if (error!.valueAsString != null) {
            final errorString = await _retrieveFullStringValue(
              service,
              e.isolate!,
              error,
            );
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
        level: level,
        isError: isError,
        summary: summary,
        detailsComputer: detailsComputer,
        isolateRef: e.isolateRef,
        zone: zone,
      ),
    );
  }

  void log(LogData log) {
    data.add(log);
    if (includeLogForFilter(log, filter: activeFilter.value)) {
      // This will notify since [filteredData] is a [ListValueNotifier].
      filteredData.add(log);
    }
    // TODO(kenz): we don't need to re-filter the data from this method if we
    // trim the logs for the retention limit. This would require some
    // refactoring to the _updateData method to support updating the notifiers
    // without re-filtering all the data.
    // If we need to trim logs to meet the retention limit, this will call
    // [_updateData] and perform a re-filter of all the logs.
    _updateForRetentionLimit();

    // TODO(kenz): this will traverse all the logs to refresh search matches.
    // We don't need to do this. We could optimize further by updating the
    // search match status for the individual log and for the controller without
    // traversing the entire data set. This is a no-op when the search value is
    // empty, but this cost is O(N*N) when a search value is present.
    refreshSearchMatches();

    _updateStatus();
  }

  void _updateForRetentionLimit({
    bool trimWithBuffer = true,
    bool updateData = true,
  }) {
    // For performance reasons, we drop old logs in batches. Because it is
    // expensive to drop from the beginning of a list, we only do it
    // periodically (e.g. drop [_defaultBufferReductionSize] logs when the log
    // retention limit has been reached.
    final retentionLimit = preferences.logging.retentionLimit.value;
    if (data.length > retentionLimit) {
      final reduceToSize = math.max(
        retentionLimit - (trimWithBuffer ? defaultLogBufferReductionSize : 0),
        0,
      );
      int dropUntilIndex = data.length - reduceToSize;
      // Ensure we remove an even number of rows to keep the alternating
      // background in-sync.
      if (dropUntilIndex % 2 == 1) {
        dropUntilIndex--;
      }
      if (updateData) {
        _updateData(data.sublist(math.max(dropUntilIndex, 0)));
      }
    }
  }

  static RemoteDiagnosticsNode? _findFirstSummary(RemoteDiagnosticsNode node) {
    if (node.level == DiagnosticLevel.summary) {
      return node;
    }
    RemoteDiagnosticsNode? summary;
    for (final property in node.inlineProperties) {
      summary = _findFirstSummary(property);
      if (summary != null) return summary;
    }

    for (final child in node.childrenNow) {
      summary = _findFirstSummary(child);
      if (summary != null) return summary;
    }

    return null;
  }

  void _handleBusEvents() {
    // TODO(jacobr): expose the messageBus for use by vm tests.
    autoDisposeStreamSubscription(
      messageBus.onEvent(type: 'reload.end').listen((BusEvent event) {
        log(
          LogData(
            'hot.reload',
            event.data as String?,
            DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }),
    );

    autoDisposeStreamSubscription(
      messageBus.onEvent(type: 'restart.end').listen((BusEvent event) {
        log(
          LogData(
            'hot.restart',
            event.data as String?,
            DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }),
    );

    // Listen for debugger events.
    autoDisposeStreamSubscription(
      messageBus
          .onEvent()
          .where(
            (event) =>
                event.type == 'debugger' || event.type.startsWith('debugger.'),
          )
          .listen(_handleDebuggerEvent),
    );

    // Listen for DevTools internal events.
    autoDisposeStreamSubscription(
      messageBus
          .onEvent()
          .where((event) => event.type.startsWith('devtools.'))
          .listen(_handleDevToolsEvent),
    );
  }

  void _handleDebuggerEvent(BusEvent event) {
    final debuggerEvent = event.data as Event;

    // Filter ServiceExtensionAdded events as they're pretty noisy.
    if (debuggerEvent.kind == EventKind.kServiceExtensionAdded) {
      return;
    }

    log(
      LogData(
        event.type,
        jsonEncode(debuggerEvent.json),
        debuggerEvent.timestamp,
        summary: '${debuggerEvent.kind} ${debuggerEvent.isolate!.id}',
      ),
    );
  }

  void _handleDevToolsEvent(BusEvent event) {
    var details = event.data.toString();
    String? summary;

    if (details.contains('\n')) {
      final lines = details.split('\n');
      summary = lines.first;
      details = lines.sublist(1).join('\n');
    }

    log(
      LogData(
        event.type,
        details,
        DateTime.now().millisecondsSinceEpoch,
        summary: summary,
      ),
    );
  }

  @override
  Iterable<LogData> get currentDataToSearchThrough => filteredData.value;

  bool includeLogForFilter(LogData log, {required Filter filter}) {
    final filteredOutBySettingFilters = filter.settingFilters.any(
      (settingFilter) => !settingFilter.includeData(log),
    );
    if (filteredOutBySettingFilters) return false;

    final queryFilter = filter.queryFilter;
    if (!queryFilter.isEmpty) {
      final filteredOutByQueryFilterArgument = queryFilter
          .filterArguments
          .values
          .any((argument) => !argument.matchesValue(log));
      if (filteredOutByQueryFilterArgument) return false;

      if (filter.queryFilter.substringExpressions.isNotEmpty) {
        for (final substring in filter.queryFilter.substringExpressions) {
          final matchesKind = log.kind.caseInsensitiveContains(substring);
          if (matchesKind) return true;

          final matchesLevel = log.levelName.caseInsensitiveContains(substring);
          if (matchesLevel) return true;

          final matchesIsolateName =
              log.isolateRef?.name?.caseInsensitiveContains(substring) ?? false;
          if (matchesIsolateName) return true;

          final zone = log.zone;
          final matchesZoneName =
              zone?.name?.caseInsensitiveContains(substring) ?? false;
          final matchesZoneIdentity =
              zone?.identityHashCode?.toString().caseInsensitiveContains(
                substring,
              ) ??
              false;
          if (matchesZoneName || matchesZoneIdentity) return true;

          final matchesSummary =
              log.summary != null &&
              log.summary!.caseInsensitiveContains(substring);
          if (matchesSummary) return true;

          final matchesDetails =
              log.details != null &&
              log.details!.caseInsensitiveContains(substring);
          if (matchesDetails) return true;
        }
        return false;
      }
    }
    return true;
  }

  @override
  void filterData(Filter<LogData> filter) {
    super.filterData(filter);
    filteredData
      ..clear()
      ..addAll(
        data.where((log) => includeLogForFilter(log, filter: filter)).toList(),
      );
  }
}

extension type _LogRecord(Map<String, dynamic> json) {
  int? get sequenceNumber => json['sequenceNumber'];

  int? get level => json['level'];

  Map<String, Object?> get loggerName => json['loggerName'];

  Map<String, Object?> get message => json['message'];

  Map<String, Object?> get zone => json['zone'];

  Map<String, Object?> get error => json['error'];

  Map<String, Object?> get stackTrace => json['stackTrace'];
}

/// Receive and log stdout / stderr events from the VM.
///
/// This class buffers the events for up to 1ms. This is in order to combine a
/// stdout message and its newline. Currently, `foo\n` is sent as two VM events;
/// we wait for up to 1ms when we get the `foo` event, to see if the next event
/// is a single newline. If so, we add the newline to the previous log message.
class _StdoutEventHandler {
  _StdoutEventHandler(
    this.loggingController,
    this.name, {
    this.isError = false,
  });

  final LoggingController loggingController;
  final String name;
  final bool isError;

  LogData? buffer;
  Timer? timer;

  void handle(Event e) {
    final message = decodeBase64(e.bytes!);

    if (buffer != null) {
      timer?.cancel();

      if (message == '\n') {
        loggingController.log(
          LogData(
            buffer!.kind,
            buffer!.details! + message,
            buffer!.timestamp,
            summary: buffer!.summary! + message,
            isError: buffer!.isError,
            isolateRef: e.isolateRef,
          ),
        );
        buffer = null;
        return;
      }

      loggingController.log(buffer!);
      buffer = null;
    }

    const maxLength = 200;

    String summary = message;
    if (message.length > maxLength) {
      summary = message.substring(0, maxLength);
    }

    final data = LogData(
      name,
      message,
      e.timestamp,
      summary: summary,
      isError: isError,
      isolateRef: e.isolateRef,
    );

    if (message == '\n') {
      loggingController.log(data);
    } else {
      buffer = data;
      timer = Timer(const Duration(milliseconds: 1), () {
        loggingController.log(buffer!);
        buffer = null;
      });
    }
  }
}

bool _isNotNull(InstanceRef? serviceRef) {
  return serviceRef != null && serviceRef.kind != 'Null';
}

String? _valueAsString(InstanceRef? ref) {
  if (ref == null) {
    return null;
  }

  if (ref.valueAsString == null) {
    return ref.valueAsString;
  }

  return ref.valueAsStringIsTruncated == true
      ? '${ref.valueAsString}...'
      : ref.valueAsString;
}

/// A log data object that includes optional summary information about whether
/// the log entry represents an error entry, the log entry kind, and more
/// detailed data for the entry.
///
/// The details can optionally be loaded lazily on first use. If this is the
/// case, this log entry will have a non-null `detailsComputer` field. After the
/// data is calculated, the log entry will be modified to contain the calculated
/// `details` data.
class LogData with SearchableDataMixin {
  LogData(
    this.kind,
    this._details,
    this.timestamp, {
    this.summary,
    int? level,
    this.isError = false,
    this.detailsComputer,
    this.node,
    this.isolateRef,
    this.zone,
  }) : level = level ?? (isError ? Level.SEVERE.value : Level.INFO.value) {
    final originalDetails = _details;
    // Fetch details immediately on creation.
    unawaited(
      compute().catchError((Object? error) {
        // On error, set the value of details to its original value.
        _details = originalDetails;
        detailsComputed.safeComplete(true);
        error_handling.reportError(
          'Error fetching details for $kind log'
          '${error != null ? ': $error' : ''}.',
        );
      }),
    );
  }

  final String kind;
  final int level;
  final int? timestamp;
  final bool isError;
  final String? summary;
  final IsolateRef? isolateRef;
  final ZoneDescription? zone;

  String get levelName =>
      _levelName ??= LogLevelMetadataChip.generateLogLevel(level).name;
  String? _levelName;

  final RemoteDiagnosticsNode? node;
  String? _details;
  Future<String> Function()? detailsComputer;

  static const prettyPrinter = JsonEncoder.withIndent('  ');

  String? get details => _details;

  bool get needsComputing => !detailsComputed.isCompleted;

  final detailsComputed = Completer<bool>();

  Future<void> compute() async {
    if (!detailsComputed.isCompleted) {
      if (detailsComputer != null) {
        _details = await detailsComputer!();
      }
      detailsComputer = null;
      detailsComputed.safeComplete(true);
    }
  }

  String? prettyPrinted() {
    if (!detailsComputed.isCompleted) {
      return details?.trim();
    }

    try {
      return prettyPrinter
          .convert(jsonDecode(details!))
          .replaceAll(r'\n', '\n')
          .trim();
    } catch (_) {
      return details?.trim();
    }
  }

  String get encodedDetails {
    if (_encodedDetails != null) return _encodedDetails!;
    if (details == null) return '';

    // TODO(kenz): ensure this doesn't cause performance issues.
    String encoded;
    try {
      // Attempt to decode the input string as JSON
      jsonDecode(details!);
      // If decoding is successful, it's already JSON encoded
      encoded = details!;
    } catch (e) {
      // If decoding fails, it's not JSON encoded, so encode it
      encoded = jsonEncode(details!);
    }

    // Only cache the value if details have already been computed.
    if (detailsComputed.isCompleted) _encodedDetails = encoded;
    return encoded;
  }

  String? _encodedDetails;

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return kind.caseInsensitiveContains(regExpSearch) ||
        levelName.caseInsensitiveContains(regExpSearch) ||
        isolateRef?.name?.caseInsensitiveContains(regExpSearch) == true ||
        zone?.name?.caseInsensitiveContains(regExpSearch) == true ||
        (summary?.caseInsensitiveContains(regExpSearch) == true) ||
        (details?.caseInsensitiveContains(regExpSearch) == true);
  }

  @override
  String toString() => 'LogData($kind, $timestamp)';
}

// TODO(https://github.com/flutter/devtools/issues/7703): make this private once
// Logging V2 lands.
extension type FrameInfo(Map<String, dynamic> _json) {
  int? get number => _json['number'];
  num get elapsedMs => (_json['elapsed'] as num) / 1000;
}

// TODO(https://github.com/flutter/devtools/issues/7703): make this private once
// Logging V2 lands.
extension type ImageSizesForFrame(Map<String, dynamic> json) {
  static List<ImageSizesForFrame> from(Map<String, dynamic> data) {
    // Example payload:
    //
    //     "packages/flutter_gallery_assets/assets/icons/material/2.0x/material.png": {
    //       "source": "packages/flutter_gallery_assets/assets/icons/material/2.0x/material.png",
    //       "displaySize": {
    //         "width": 64.0,
    //         "height": 63.99999999999999
    //       },
    //       "imageSize": {
    //         "width": 128.0,
    //         "height": 128.0
    //       },
    //       "displaySizeInBytes": 21845,
    //       "decodedSizeInBytes": 87381
    //     }
    return data.values.map((entry_) => ImageSizesForFrame(entry_)).toList();
  }

  String get source => json['source'];

  ImageSize get displaySize => ImageSize(json['displaySize']);

  ImageSize get imageSize => ImageSize(json['imageSize']);

  int? get displaySizeInBytes => json['displaySizeInBytes'];

  int? get decodedSizeInBytes => json['decodedSizeInBytes'];

  String get summary {
    final file = path.basename(source);

    final expansion =
        math.sqrt(decodedSizeInBytes ?? 0) / math.sqrt(displaySizeInBytes ?? 1);

    return 'Image $file • displayed at '
        '${displaySize.width.round()}x${displaySize.height.round()}'
        ' • created at '
        '${imageSize.width.round()}x${imageSize.height.round()}'
        ' • ${expansion.toStringAsFixed(1)}x';
  }
}

// TODO(https://github.com/flutter/devtools/issues/7703): make this private once
// Logging V2 lands.
extension type ImageSize(Map<String, dynamic> json) {
  double get width => json['width'];

  double get height => json['height'];
}

class NavigationInfo {
  NavigationInfo(this._route);

  static NavigationInfo from(Map<String, dynamic> data) {
    return NavigationInfo(data['route']);
  }

  final Map<String, dynamic>? _route;

  String? get routeDescription => _route == null ? null : _route['description'];
}

class ServiceExtensionStateChangedInfo {
  ServiceExtensionStateChangedInfo(this.extension, this.value);

  static ServiceExtensionStateChangedInfo from(Map<String, dynamic> data) {
    return ServiceExtensionStateChangedInfo(data['extension'], data['value']);
  }

  final String? extension;
  final Object value;
}

extension on Event {
  IsolateRef? get isolateRef => IsolateRef.parse(this.json?['isolate']);
}
