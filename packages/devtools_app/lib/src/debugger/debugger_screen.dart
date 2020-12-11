// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../config_specific/host_platform/host_platform.dart';
import '../flex_split_column.dart';
import '../listenable.dart';
import '../octicons.dart';
import '../screen.dart';
import '../split.dart';
import '../theme.dart';
import 'breakpoints.dart';
import 'call_stack.dart';
import 'codeview.dart';
import 'console.dart';
import 'controls.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'scripts.dart';
import 'variables.dart';

// This is currently a dev-time flag as the overall call depth may not be that
// interesting to users.
const bool debugShowCallStackCount = false;

class DebuggerScreen extends Screen {
  const DebuggerScreen()
      : super.conditional(
          id: id,
          requiresDebugBuild: true,
          title: 'Debugger',
          icon: Octicons.bug,
        );

  static const id = 'debugger';

  @override
  String get docPageId => screenId;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  Widget build(BuildContext context) => const DebuggerScreenBody();

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final controller = Provider.of<DebuggerController>(context);
    return DebuggerStatus(controller: controller);
  }
}

class DebuggerScreenBody extends StatefulWidget {
  const DebuggerScreenBody();

  static final codeViewKey = GlobalKey(debugLabel: 'codeViewKey');
  static final scriptViewKey = GlobalKey(debugLabel: 'scriptViewKey');

  @override
  DebuggerScreenBodyState createState() => DebuggerScreenBodyState();
}

class DebuggerScreenBodyState extends State<DebuggerScreenBody>
    with AutoDisposeMixin {
  static const callStackTitle = 'Call Stack';
  static const variablesTitle = 'Variables';
  static const breakpointsTitle = 'Breakpoints';

  DebuggerController controller;
  FocusNode _libraryFilterFocusNode;

  @override
  void initState() {
    super.initState();
    _libraryFilterFocusNode = FocusNode();
    ga.screen(DebuggerScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<DebuggerController>(context);
    if (newController == controller) return;
    controller = newController;
  }

  @override
  void dispose() {
    _libraryFilterFocusNode.dispose();
    super.dispose();
  }

  void _onLocationSelected(ScriptLocation location) {
    if (location != null) {
      controller.showScriptLocation(location);
    }
  }

  Future<void> _toggleBreakpoint(ScriptRef script, int line) async {
    final bp = controller.breakpointsWithLocation.value.firstWhere((bp) {
      return bp.scriptRef == script && bp.line == line;
    }, orElse: () => null);

    if (bp != null) {
      await controller.removeBreakpoint(bp.breakpoint);
    } else {
      try {
        await controller.addBreakpoint(script.id, line);
      } catch (_) {
        // ignore errors setting breakpoints
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeView = ValueListenableBuilder(
      valueListenable: controller.currentScriptRef,
      builder: (context, scriptRef, _) {
        return CodeView(
          key: DebuggerScreenBody.codeViewKey,
          controller: controller,
          scriptRef: scriptRef,
          onSelected: _toggleBreakpoint,
        );
      },
    );

    final codeArea = ValueListenableBuilder(
      valueListenable: controller.librariesVisible,
      builder: (context, visible, _) {
        if (visible) {
          // Focus the filter text field when the ScriptPicker opens.
          _libraryFilterFocusNode.requestFocus();

          // TODO(devoncarew): Animate this opening and closing.
          return Split(
            axis: Axis.horizontal,
            initialFractions: const [0.70, 0.30],
            children: [
              codeView,
              ValueListenableBuilder(
                valueListenable: controller.sortedScripts,
                builder: (context, scripts, _) {
                  return ScriptPicker(
                    key: DebuggerScreenBody.scriptViewKey,
                    controller: controller,
                    scripts: scripts,
                    onSelected: _onLocationSelected,
                    libraryFilterFocusNode: _libraryFilterFocusNode,
                  );
                },
              ),
            ],
          );
        } else {
          return codeView;
        }
      },
    );

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        focusLibraryFilterKeySet:
            FocusLibraryFilterIntent(_libraryFilterFocusNode, controller),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          FocusLibraryFilterIntent: FocusLibraryFilterAction(),
        },
        child: Split(
          axis: Axis.horizontal,
          initialFractions: const [0.25, 0.75],
          children: [
            OutlineDecoration(child: debuggerPanes()),
            Column(
              children: [
                DebuggingControls(controller: controller),
                const SizedBox(height: denseRowSpacing),
                Expanded(
                  child: Split(
                    axis: Axis.vertical,
                    initialFractions: const [0.72, 0.28],
                    children: [
                      codeArea,
                      DebuggerConsole(controller: controller),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget debuggerPanes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FlexSplitColumn(
          totalHeight: constraints.maxHeight,
          initialFractions: const [0.40, 0.40, 0.20],
          minSizes: const [0.0, 0.0, 0.0],
          headers: <SizedBox>[
            areaPaneHeader(
              context,
              title: callStackTitle,
              needsTopBorder: false,
              actions: debugShowCallStackCount ? [_callStackRightChild()] : [],
            ),
            areaPaneHeader(context, title: variablesTitle),
            areaPaneHeader(
              context,
              title: breakpointsTitle,
              actions: [
                _breakpointsRightChild(),
              ],
              rightPadding: 0.0,
            ),
          ],
          children: const [
            CallStack(),
            Variables(),
            Breakpoints(),
          ],
        );
      },
    );
  }

  Widget _callStackRightChild() {
    return ValueListenableBuilder(
      valueListenable: controller.stackFramesWithLocation,
      builder: (context, stackFrames, _) {
        return CallStackCountBadge(stackFrames: stackFrames);
      },
    );
  }

  Widget _breakpointsRightChild() {
    return ValueListenableBuilder(
      valueListenable: controller.breakpointsWithLocation,
      builder: (context, breakpoints, _) {
        return Row(children: [
          BreakpointsCountBadge(breakpoints: breakpoints),
          ActionButton(
            child: ToolbarAction(
              icon: Icons.delete,
              onPressed:
                  breakpoints.isNotEmpty ? controller.clearBreakpoints : null,
            ),
            tooltip: 'Remove all breakpoints',
          ),
        ]);
      },
    );
  }
}

final LogicalKeySet focusLibraryFilterKeySet = LogicalKeySet(
  HostPlatform.instance.isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control,
  LogicalKeyboardKey.keyP,
);

class FocusLibraryFilterIntent extends Intent {
  const FocusLibraryFilterIntent(
    this.focusNode,
    this.debuggerController,
  )   : assert(debuggerController != null),
        assert(focusNode != null);

  final FocusNode focusNode;
  final DebuggerController debuggerController;
}

class FocusLibraryFilterAction extends Action<FocusLibraryFilterIntent> {
  @override
  void invoke(FocusLibraryFilterIntent intent) {
    intent.debuggerController.toggleLibrariesVisible();
  }
}

class DebuggerStatus extends StatefulWidget {
  const DebuggerStatus({
    Key key,
    @required this.controller,
  }) : super(key: key);

  final DebuggerController controller;

  @override
  _DebuggerStatusState createState() => _DebuggerStatusState();
}

class _DebuggerStatusState extends State<DebuggerStatus> with AutoDisposeMixin {
  String _status;

  @override
  void initState() {
    super.initState();

    addAutoDisposeListener(widget.controller.isPaused, _updateStatus);

    _status = '';
    _updateStatus();
  }

  @override
  void didUpdateWidget(DebuggerStatus oldWidget) {
    super.didUpdateWidget(oldWidget);

    // todo: should we check that widget.controller != oldWidget.controller?
    addAutoDisposeListener(widget.controller.isPaused, _updateStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _status,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _updateStatus() async {
    final status = await _computeStatus();
    if (status != _status) {
      setState(() {
        _status = status;
      });
    }
  }

  Future<String> _computeStatus() async {
    final paused = widget.controller.isPaused.value;

    if (!paused) {
      return 'running';
    }

    final event = widget.controller.lastEvent;
    final frame = event.topFrame;
    final reason =
        event.kind == EventKind.kPauseException ? ' on exception' : '';

    if (frame == null) {
      return 'paused$reason';
    }

    final fileName = ' at ' + frame.location.script.uri.split('/').last;
    final script = await widget.controller.getScript(frame.location.script);
    final pos =
        widget.controller.calculatePosition(script, frame.location.tokenPos);

    return 'paused$reason$fileName $pos';
  }
}
