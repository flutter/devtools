import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import 'auto_dispose.dart';
import 'debugger/debugger_model.dart';
import 'globals.dart';
import 'inspector/diagnostics_node.dart';
import 'inspector/inspector_service.dart';
import 'utils.dart';
import 'vm_service_wrapper.dart';

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

  factory ConsoleLine.variable(
    Variable variable, {
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
  final Variable variable;

  @override
  String toString() {
    return variable.toString();
  }
}

/// Source of truth for the state of the Console including both events from the
/// VM and events emitted from other UI.
class ConsoleService extends Disposer {
  void appendInstanceRef({
    String name,
    @required InstanceRef value,
    @required RemoteDiagnosticsNode diagnostic,
    @required IsolateRef isolateRef,
    bool forceScrollIntoView = false,
    bool expandAll = false,
  }) async {
    _stdioTrailingNewline = false;
    final variable = Variable.fromRef(
      name: name,
      value: value,
      diagnostic: diagnostic,
      isolateRef: isolateRef,
    );
    // TODO(jacobr): fix out of order issues by tracking raw order.
    await buildVariablesTree(variable, expandAll: expandAll);
    if (expandAll) {
      variable.expandCascading();
    }
    _stdio.add(ConsoleLine.variable(
      variable,
      forceScrollIntoView: forceScrollIntoView,
    ));
  }

  final _stdio = ListValueNotifier<ConsoleLine>([]);
  bool _stdioTrailingNewline = false;

  ObjectGroup get objectGroup {
    final inspectorService = serviceManager.inspectorService;
    if (_objectGroup?.inspectorService == inspectorService) {
      return _objectGroup;
    }
    _objectGroup?.dispose();
    _objectGroup = inspectorService?.createObjectGroup('console');
    return _objectGroup;
  }

  ObjectGroup _objectGroup;

  /// Clears the contents of stdio.
  void clearStdio() {
    if (_stdio.value?.isNotEmpty ?? false) {
      _stdio.clear();
    }
  }

  /// Append to the stdout / stderr buffer.
  void appendStdio(
    String text, {
    bool forceScrollIntoView = false,
  }) {
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
      _stdio.sublist(0, _stdio.value.length - 1);
    }

    // For performance reasons, we drop older lines in batches, so the lines
    // will grow to kMaxLogItemsUpperBound then truncate to
    // kMaxLogItemsLowerBound.
    if (_stdio.value.length > kMaxLogItemsUpperBound) {
      _stdio.sublist(stdio.value.length - kMaxLogItemsLowerBound);
    }
  }

  /// Return the stdout and stderr emitted from the application.
  ///
  /// Note that this output might be truncated after significant output.
  ValueListenable<List<ConsoleLine>> get stdio => _stdio;

  void _handleStdoutEvent(Event event) {
    final String text = decodeBase64(event.bytes);
    appendStdio(text);
  }

  void _handleStderrEvent(Event event) {
    final String text = decodeBase64(event.bytes);
    // TODO(devoncarew): Change to reporting stdio along with information about
    // whether the event was stdout or stderr.
    appendStdio(text);
  }

  void vmServiceOpened(VmServiceWrapper service) {
    cancel();
    autoDispose(service.onDebugEvent.listen(_handleDebugEvent));
    autoDispose(service.onStdoutEventWithHistory.listen(_handleStdoutEvent));
    autoDispose(service.onStderrEventWithHistory.listen(_handleStderrEvent));
    autoDispose(
        service.onExtensionEventWithHistory.listen(_handleExtensionEvent));
    addAutoDisposeListener(serviceManager.isolateManager.mainIsolate, () {
      clearStdio();
    });
  }

  void _handleExtensionEvent(Event e) async {
    if (e.extensionKind == 'Flutter.Error' ||
        e.extensionKind == 'Flutter.Print') {
      final inspectorService = serviceManager.inspectorService;
      if (inspectorService == null) {
        // The app isn't a debug build.
        return;
      }
      // TODO(jacobr): events are may be out of order. Use unique ids to ensure
      // consistent order of regular print statements and structured messages.
      appendInstanceRef(
        value: null,
        diagnostic: RemoteDiagnosticsNode(
          e.extensionData.data,
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
    cancel();
  }

  void _handleDebugEvent(Event event) async {
    // TODO(jacobr): keep events in order by tracking the original time and
    // sorting.
    if (event.kind == EventKind.kInspect) {
      final inspector = objectGroup;
      if (inspector != null &&
          event.isolate == inspector.inspectorService.isolateRef) {
        try {
          if (await inspector.isInspectable(GenericInstanceRef(
              isolateRef: event.isolate, instanceRef: event.inspectee))) {
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
