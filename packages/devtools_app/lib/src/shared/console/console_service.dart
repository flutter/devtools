// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/vm_service_wrapper.dart';
import '../diagnostics/dart_object_node.dart';
import '../diagnostics/diagnostics_node.dart';
import '../diagnostics/generic_instance_reference.dart';
import '../diagnostics/inspector_service.dart';
import '../diagnostics/tree_builder.dart';
import '../globals.dart';
import '../memory/adapted_heap_data.dart';
import '../primitives/utils.dart';

/// A line in the console.
///
/// TODO(jacobr): support console lines that are structured error messages as
/// well.
class ConsoleLine {
  factory ConsoleLine.text(
    String text, {
    bool forceScrollIntoView = false,
  }) =>
      TextConsoleLine(
        text,
        forceScrollIntoView: forceScrollIntoView,
      );

  factory ConsoleLine.dartObjectNode(
    DartObjectNode variable, {
    bool forceScrollIntoView = false,
  }) =>
      VariableConsoleLine(
        variable,
        forceScrollIntoView: forceScrollIntoView,
      );

  ConsoleLine._(this.forceScrollIntoView);

  // Whether this console line should be scrolled into view when it is added.
  final bool forceScrollIntoView;
}

class TextConsoleLine extends ConsoleLine {
  TextConsoleLine(this.text, {bool forceScrollIntoView = false})
      : super._(forceScrollIntoView);
  final String text;

  @override
  String toString() {
    return text;
  }
}

class VariableConsoleLine extends ConsoleLine {
  VariableConsoleLine(this.variable, {bool forceScrollIntoView = false})
      : super._(
          forceScrollIntoView,
        );
  final DartObjectNode variable;

  @override
  String toString() {
    return variable.toString();
  }
}

/// Source of truth for the state of the Console including both events from the
/// VM and events emitted from other UI.
class ConsoleService with DisposerMixin {
  void appendBrowsableInstance({
    required InstanceRef? instanceRef,
    required IsolateRef? isolateRef,
    required HeapObjectSelection? heapSelection,
  }) async {
    if (instanceRef == null) {
      final object = heapSelection?.object;
      if (object == null || isolateRef == null) {
        serviceConnection.consoleService.appendStdio(
          'Not enough information to browse the instance.',
        );
        return;
      }

      instanceRef = await evalService.findObject(object, isolateRef);
    }

    // If instanceRef is null at this point, user will see static references.

    appendInstanceRef(
      value: instanceRef,
      diagnostic: null,
      isolateRef: isolateRef,
      forceScrollIntoView: true,
      heapSelection: heapSelection,
    );
  }

  void appendInstanceRef({
    String? name,
    required InstanceRef? value,
    required RemoteDiagnosticsNode? diagnostic,
    required IsolateRef? isolateRef,
    bool forceScrollIntoView = false,
    bool expandAll = false,
    HeapObjectSelection? heapSelection,
  }) async {
    _stdioTrailingNewline = false;
    final variable = DartObjectNode.fromValue(
      name: name,
      value: value,
      diagnostic: diagnostic,
      isolateRef: isolateRef,
      heapSelection: heapSelection,
    );
    // TODO(jacobr): fix out of order issues by tracking raw order.
    await buildVariablesTree(variable, expandAll: expandAll);
    if (expandAll) {
      variable.expandCascading();
    }
    _stdio.add(
      ConsoleLine.dartObjectNode(
        variable,
        forceScrollIntoView: forceScrollIntoView,
      ),
    );
  }

  final _stdio = ListValueNotifier<ConsoleLine>([]);
  bool _stdioTrailingNewline = false;

  InspectorObjectGroupBase get objectGroup {
    final inspectorService = serviceConnection.inspectorService!;
    if (_objectGroup?.inspectorService == inspectorService) {
      return _objectGroup!;
    }
    unawaited(_objectGroup?.dispose());
    _objectGroup = inspectorService.createObjectGroup('console');
    return _objectGroup!;
  }

  InspectorObjectGroupBase? _objectGroup;

  /// Clears the contents of stdio.
  void clearStdio() {
    if (_stdio.value.isNotEmpty) {
      _stdio.clear();
    }
  }

  DartObjectNode? itemAt(int invertedIndex) {
    assert(invertedIndex >= 0);
    final list = _stdio.value;
    if (invertedIndex > list.length - 1) return null;
    final item = list[list.length - 1 - invertedIndex];
    if (item is! VariableConsoleLine) return null;
    return item.variable;
  }

  /// Append to the stdout / stderr buffer.
  void appendStdio(String text) {
    const int kMaxLogItemsLowerBound = 5000;
    const int kMaxLogItemsUpperBound = 5500;

    // Parse out the new lines and append to the end of the existing lines.

    final newLines = text.split('\n');

    var last = _stdio.value.safeLast;
    if (_stdio.value.isNotEmpty &&
        !_stdioTrailingNewline &&
        last is TextConsoleLine) {
      _stdio.last = ConsoleLine.text('${last.text}${newLines.first}');
      if (newLines.length > 1) {
        _stdio
            .addAll(newLines.sublist(1).map((text) => ConsoleLine.text(text)));
      }
    } else {
      _stdio.addAll(newLines.map((text) => ConsoleLine.text(text)));
    }

    _stdioTrailingNewline = text.endsWith('\n');

    // Don't report trailing blank lines.
    last = _stdio.value.safeLast;
    if (_stdio.value.isNotEmpty &&
        (last is TextConsoleLine && last.text.isEmpty)) {
      _stdio.trimToSublist(0, _stdio.value.length - 1);
    }

    // For performance reasons, we drop older lines in batches, so the lines
    // will grow to kMaxLogItemsUpperBound then truncate to
    // kMaxLogItemsLowerBound.
    if (_stdio.value.length > kMaxLogItemsUpperBound) {
      _stdio.trimToSublist(_stdio.value.length - kMaxLogItemsLowerBound);
    }
  }

  /// Return the stdout and stderr emitted from the application.
  ///
  /// Note that this output might be truncated after significant output.
  ValueListenable<List<ConsoleLine>> get stdio {
    ensureServiceInitialized();
    return _stdio;
  }

  void _handleStdoutEvent(Event event) {
    final String text = decodeBase64(event.bytes!);
    appendStdio(text);
  }

  void _handleStderrEvent(Event event) {
    final String text = decodeBase64(event.bytes!);
    // TODO(devoncarew): Change to reporting stdio along with information about
    // whether the event was stdout or stderr.
    appendStdio(text);
  }

  void vmServiceOpened(VmServiceWrapper service) {
    cancelStreamSubscriptions();
    cancelListeners();
    // The debug stream listener must be added as soon as the service is opened
    // because this stream does not send event history upon the first
    // subscription like the streams in [ensureServiceInitialized].
    autoDisposeStreamSubscription(
      service.onDebugEvent.listen(_handleDebugEvent),
    );
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      () {
        clearStdio();
      },
    );
  }

  /// Whether the console service has been initialized.
  bool _serviceInitialized = false;

  /// Initialize the console service.
  ///
  /// Consumers of [ConsoleService] should call this method before using the
  /// console service in any way.
  ///
  /// These stream listeners are added here instead of in [vmServiceOpened] for
  /// performance reasons. Since these streams have event history, we will not
  /// be missing any events by listening after [vmServiceOpened], and listening
  /// only when this data is needed will improve performance for connecting to
  /// low-end devices, as well as when DevTools pages that don't need the
  /// [ConsoleService] are being used.
  void ensureServiceInitialized() {
    assert(serviceConnection.serviceManager.isServiceAvailable);
    if (!_serviceInitialized &&
        serviceConnection.serviceManager.isServiceAvailable) {
      autoDisposeStreamSubscription(
        serviceConnection.serviceManager.service!.onStdoutEventWithHistorySafe
            .listen(_handleStdoutEvent),
      );
      autoDisposeStreamSubscription(
        serviceConnection.serviceManager.service!.onStderrEventWithHistorySafe
            .listen(_handleStderrEvent),
      );
      autoDisposeStreamSubscription(
        serviceConnection.serviceManager.service!.onExtensionEventWithHistorySafe
            .listen(_handleExtensionEvent),
      );
      _serviceInitialized = true;
    }
  }

  void _handleExtensionEvent(Event e) async {
    if (e.extensionKind == 'Flutter.Error' ||
        e.extensionKind == 'Flutter.Print') {
      if (serviceConnection.serviceManager.connectedApp?.isProfileBuildNow !=
          true) {
        // The app isn't a debug build.
        return;
      }
      // TODO(jacobr): events may be out of order. Use unique ids to ensure
      // consistent order of regular print statements and structured messages.
      appendInstanceRef(
        value: null,
        diagnostic: RemoteDiagnosticsNode(
          e.extensionData!.data,
          objectGroup,
          false,
          null,
        ),
        isolateRef: objectGroup.inspectorService.isolateRef,
        expandAll: true,
      );
    }
  }

  void handleVmServiceClosed() {
    cancelStreamSubscriptions();
    _serviceInitialized = false;
  }

  void _handleDebugEvent(Event event) async {
    // TODO(jacobr): keep events in order by tracking the original time and
    // sorting.
    if (event.kind == EventKind.kInspect) {
      final inspector = objectGroup;
      if (event.isolate == inspector.inspectorService.isolateRef) {
        try {
          if (await inspector.isInspectable(
            GenericInstanceRef(
              isolateRef: event.isolate,
              value: event.inspectee,
            ),
          )) {
            // This object will trigger the widget inspector so let the widget
            // inspector decide whether it wants to log it to the console or
            // not.
            // TODO(jacobr): if the widget inspector stops using the inspect
            // event to trigger changing inspector selection, remove this
            // case. Without this logic, we could double log objects to the
            // console after clicking in the inspector as clicking in the
            // inspector directly triggers an object to be logged and clicking
            // in the inspector leads the device to emit an inspect event back
            // to other clients.
            return;
          }
        } catch (e) {
          // Fail gracefully. TODO(jacobr) verify the error was only Sentinel
          // returned getting the inspector ref.
        }
      }
      appendInstanceRef(
        value: event.inspectee,
        isolateRef: event.isolate,
        diagnostic: null,
      );
    }
  }
}
