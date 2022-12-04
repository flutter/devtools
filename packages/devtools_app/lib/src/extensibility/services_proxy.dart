import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/auto_dispose.dart';
import '../primitives/message_bus.dart';
import '../primitives/utils.dart';
import '../screens/inspector/diagnostics_node.dart';
import '../screens/inspector/inspector_service.dart';
import '../screens/logging/logging_controller.dart'
    show
        FrameInfo,
        ImageSizesForFrame,
        NavigationInfo,
        ServiceExtensionStateChangedInfo; // TODO: consider extracting these from the logging controller into a shared place
import '../service/vm_service_wrapper.dart';
import '../shared/globals.dart';

// Adapted from [logging_controller.dart]
class VMServicesProxy extends DisposableController
    with AutoDisposeControllerMixin {
  VMServicesProxy() {
    autoDisposeStreamSubscription(
      serviceManager.onConnectionAvailable.listen(_handleConnectionStart),
    );
    if (serviceManager.connectedAppInitialized) {
      _handleConnectionStart(serviceManager.service!);
    }
    autoDisposeStreamSubscription(
      serviceManager.onConnectionClosed.listen(_handleConnectionStop),
    );
    _handleBusEvents();
  }

  void _handleConnectionStart(VmServiceWrapper service) async {
    // Log stdout events.
    final _StdoutEventHandler stdoutHandler = _StdoutEventHandler('stdout');
    autoDisposeStreamSubscription(
      service.onStdoutEventWithHistory.listen(stdoutHandler.handle),
    );

    // Log stderr events.
    final _StdoutEventHandler stderrHandler =
        _StdoutEventHandler('stderr', isError: true);
    autoDisposeStreamSubscription(
      service.onStderrEventWithHistory.listen(stderrHandler.handle),
    );

    // Log GC events.
    autoDisposeStreamSubscription(service.onGCEvent.listen(_handleGCEvent));

    // Log `dart:developer` `log` events.
    autoDisposeStreamSubscription(
      service.onLoggingEventWithHistory.listen(_handleDeveloperLogEvent),
    );

    // Log Flutter extension events.
    autoDisposeStreamSubscription(
      service.onExtensionEventWithHistory.listen(_handleExtensionEvent),
    );
  }

  void _handleExtensionEvent(Event e) async {
    // Events to show without a summary in the table.
    const Set<String> untitledEvents = {
      'Flutter.FirstFrame',
      'Flutter.FrameworkInitialization',
    };

    // TODO(jacobr): make the list of filtered events configurable.
    const Set<String> filteredEvents = {
      // Suppress these events by default as they just add noise to the log
      ServiceExtensionStateChangedInfo.eventName,
    };

    if (filteredEvents.contains(e.extensionKind)) {
      return;
    }

    if (e.extensionKind == FrameInfo.eventName) {
      final FrameInfo frame = FrameInfo.from(e.extensionData!.data);

      final String frameId = '#${frame.number}';
      final String frameInfoText =
          '$frameId ${frame.elapsedMs!.toStringAsFixed(1).padLeft(4)}ms ';

      eventsManager.addEvent(
        VMEvent(
          e.extensionKind!.toLowerCase(),
          data: {
            'data': e.extensionData!.data,
            'timestamp': e.timestamp,
            'summary': frameInfoText,
          },
        ),
      );
    } else if (e.extensionKind == ImageSizesForFrame.eventName) {
      final images = ImageSizesForFrame.from(e.extensionData!.data);

      for (final image in images) {
        eventsManager.addEvent(
          VMEvent(
            e.extensionKind!.toLowerCase(),
            data: {
              'data': image.rawJson,
              'timestamp': e.timestamp,
              'summary': image.summary,
            },
          ),
        );
      }
    } else if (e.extensionKind == NavigationInfo.eventName) {
      final NavigationInfo navInfo = NavigationInfo.from(e.extensionData!.data);

      eventsManager.addEvent(
        VMEvent(
          e.extensionKind!.toLowerCase(),
          data: {
            'data': e.json,
            'timestamp': e.timestamp,
            'summary': navInfo.routeDescription,
          },
        ),
      );
    } else if (untitledEvents.contains(e.extensionKind)) {
      eventsManager.addEvent(
        VMEvent(
          e.extensionKind!.toLowerCase(),
          data: {
            'data': e.json,
            'timestamp': e.timestamp,
            'summary': '',
          },
        ),
      );
    } else if (e.extensionKind == ServiceExtensionStateChangedInfo.eventName) {
      final ServiceExtensionStateChangedInfo changedInfo =
          ServiceExtensionStateChangedInfo.from(e.extensionData!.data);

      eventsManager.addEvent(
        VMEvent(
          e.extensionKind!.toLowerCase(),
          data: {
            'data': e.json,
            'timestamp': e.timestamp,
            'summary': '${changedInfo.extension}: ${changedInfo.value}',
          },
        ),
      );
    } else if (e.extensionKind == 'Flutter.Error') {
      // TODO(pq): add tests for error extension handling once framework changes
      // are landed.
      final RemoteDiagnosticsNode node = RemoteDiagnosticsNode(
        e.extensionData!.data,
        _objectGroup,
        false,
        null,
      );
      // Workaround the fact that the error objects from the server don't have
      // style error.
      node.style = DiagnosticsTreeStyle.error;
      // if (_verboseDebugging) {
      // logger.log('node toStringDeep:######\n${node.toStringDeep()}\n###');
      // }

      final RemoteDiagnosticsNode summary = _findFirstSummary(node) ?? node;
      eventsManager.addEvent(
        VMEvent(
          e.extensionKind!.toLowerCase(),
          data: {
            'data': e.extensionData!.data,
            'timestamp': e.timestamp,
            'summary': summary.toDiagnosticsNode().toString(),
          },
        ),
      );
    } else {
      eventsManager.addEvent(
        VMEvent(
          e.extensionKind!.toLowerCase(),
          data: {
            'data': e.json,
            'timestamp': e.timestamp,
            'summary': e.json.toString(),
          },
        ),
      );
    }
  }

  ObjectGroup get _objectGroup =>
      serviceManager.consoleService.objectGroup as ObjectGroup;

  void _handleGCEvent(Event e) {
    final HeapSpace newSpace = HeapSpace.parse(e.json!['new'])!;
    final HeapSpace oldSpace = HeapSpace.parse(e.json!['old'])!;
    final isolateRef = e.json!['isolate'];

    final int usedBytes = newSpace.used! + oldSpace.used!;
    final int capacityBytes = newSpace.capacity! + oldSpace.capacity!;

    final int time = ((newSpace.time! + oldSpace.time!) * 1000).round();

    final String summary = '${isolateRef['name']} • '
        '${e.json!['reason']} collection in $time ms • '
        '${printMB(usedBytes, includeUnit: true)} used of ${printMB(capacityBytes, includeUnit: true)}';

    final event = <String, dynamic>{
      'reason': e.json!['reason'],
      'new': newSpace.json,
      'old': oldSpace.json,
      'isolate': isolateRef,
    };

    eventsManager.addEvent(
      VMEvent(
        'gc',
        data: {'data': event, 'timestamp': e.timestamp, 'summary': summary},
      ),
    );
  }

  void _handleDeveloperLogEvent(Event e) {
    final logRecord = e.json!['logRecord'];

    String? loggerName =
        _valueAsString(InstanceRef.parse(logRecord['loggerName']));
    if (loggerName == null || loggerName.isEmpty) {
      loggerName = 'log';
    }
    final int? level = logRecord['level'];
    final InstanceRef messageRef = InstanceRef.parse(logRecord['message'])!;
    String? summary = _valueAsString(messageRef);
    if (messageRef.valueAsStringIsTruncated == true) {
      summary = summary! + '...';
    }

    final String? details = summary;

    const int severeIssue = 1000;
    final bool isError = level != null && level >= severeIssue ? true : false;

    eventsManager.addEvent(
      VMEvent(
        loggerName,
        data: {
          'data': details,
          'timestamp': e.timestamp,
          'isError': isError,
          'summary': summary,
        },
      ),
    );
  }

  String? _valueAsString(InstanceRef? ref) {
    if (ref == null) {
      return null;
    }

    if (ref.valueAsString == null) {
      return ref.valueAsString;
    }

    if (ref.valueAsStringIsTruncated == true) {
      return '${ref.valueAsString}...';
    } else {
      return ref.valueAsString;
    }
  }

  void _handleConnectionStop(dynamic event) {}

  void _handleBusEvents() {
    autoDisposeStreamSubscription(
      messageBus.onEvent().listen(
            (BusEvent event) =>
                eventsManager.addEvent(VMEvent(event.type, data: event.data)),
          ),
    );
  }

  static RemoteDiagnosticsNode? _findFirstSummary(RemoteDiagnosticsNode node) {
    if (node.level == DiagnosticLevel.summary) {
      return node;
    }
    RemoteDiagnosticsNode? summary;
    for (var property in node.inlineProperties) {
      summary = _findFirstSummary(property);
      if (summary != null) return summary;
    }

    for (RemoteDiagnosticsNode child in node.childrenNow) {
      summary = _findFirstSummary(child);
      if (summary != null) return summary;
    }

    return null;
  }
}

/// Receive and log stdout / stderr events from the VM.
///
/// This class buffers the events for up to 1ms. This is in order to combine a
/// stdout message and its newline. Currently, `foo\n` is sent as two VM events;
/// we wait for up to 1ms when we get the `foo` event, to see if the next event
/// is a single newline. If so, we add the newline to the previous log message.
class _StdoutEventHandler {
  _StdoutEventHandler(
    this.name, {
    this.isError = false,
  });

  final String name;
  final bool isError;

  VMEvent? buffer;
  Timer? timer;

  void handle(Event e) {
    final String message = decodeBase64(e.bytes!);
    print('_StdOutEventHandler: $message');

    if (buffer != null) {
      timer?.cancel();

      if (message == '\n') {
        final data = buffer!.data! as Map;
        eventsManager.addEvent(
          VMEvent(
            buffer!.type,
            data: {
              'data': data['data']! + message,
              'timestamp': data['timestamp'],
              'summary': data['summary']! + message,
              'isError': data['isError'],
            },
          ),
        );
        buffer = null;
        return;
      }

      eventsManager.addEvent(buffer!);
      buffer = null;
    }

    const maxLength = 200;

    String summary = message;
    if (message.length > maxLength) {
      summary = message.substring(0, maxLength);
    }

    final VMEvent event = VMEvent(
      name,
      data: {
        'data': message,
        'timestamp': e.timestamp,
        'summary': summary,
        'isError': isError,
      },
    );

    if (message == '\n') {
      eventsManager.addEvent(event);
    } else {
      buffer = event;
      timer = Timer(const Duration(milliseconds: 1), () {
        eventsManager.addEvent(buffer!);
        buffer = null;
      });
    }
  }
}
