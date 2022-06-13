// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:codicon/codicon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/listenable.dart';
import '../../shared/common_widgets.dart';
import '../../shared/flex_split_column.dart';
import '../../shared/globals.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/icons.dart';
import 'breakpoints.dart';
import 'call_stack.dart';
import 'codeview.dart';
import 'controls.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'key_sets.dart';
import 'program_explorer.dart';
import 'variables.dart';

class DebuggerScreen extends Screen {
  const DebuggerScreen()
      : super.conditional(
          id: id,
          requiresDebugBuild: true,
          title: 'Debugger',
          icon: Octicons.bug,
          showFloatingDebuggerControls: false,
        );

  static const id = 'debugger';

  @override
  bool showConsole(bool embed) => true;

  @override
  ShortcutsConfiguration buildKeyboardShortcuts(BuildContext context) {
    final controller = Provider.of<DebuggerController>(context);
    final shortcuts = <LogicalKeySet, Intent>{
      goToLineNumberKeySet: GoToLineNumberIntent(context, controller),
      searchInFileKeySet: SearchInFileIntent(controller),
      escapeKeySet: EscapeIntent(controller),
      openFileKeySet: OpenFileIntent(controller),
    };
    final actions = <Type, Action<Intent>>{
      GoToLineNumberIntent: GoToLineNumberAction(),
      SearchInFileIntent: SearchInFileAction(),
      EscapeIntent: EscapeAction(),
      OpenFileIntent: OpenFileAction(),
    };
    return ShortcutsConfiguration(shortcuts: shortcuts, actions: actions);
  }

  @override
  String get docPageId => screenId;

  @override
  ValueListenable<bool> get showIsolateSelector =>
      const FixedValueListenable<bool>(true);

  @override
  Widget build(BuildContext context) => const DebuggerScreenBody();

  @override
  Widget buildStatus(BuildContext context) {
    final controller = Provider.of<DebuggerController>(context);
    return DebuggerStatus(controller: controller);
  }
}

class DebuggerScreenBody extends StatefulWidget {
  const DebuggerScreenBody();

  static final codeViewKey = GlobalKey(debugLabel: 'codeViewKey');
  static final scriptViewKey = GlobalKey(debugLabel: 'scriptViewKey');
  static final programExplorerKey =
      GlobalKey(debugLabel: 'programExploreryKey');
  static const callStackCopyButtonKey =
      Key('debugger_call_stack_copy_to_clipboard_button');

  @override
  DebuggerScreenBodyState createState() => DebuggerScreenBodyState();
}

class DebuggerScreenBodyState extends State<DebuggerScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<DebuggerController, DebuggerScreenBody> {
  static const callStackTitle = 'Call Stack';
  static const variablesTitle = 'Variables';
  static const breakpointsTitle = 'Breakpoints';

  late bool _shownFirstScript;

  @override
  void initState() {
    super.initState();
    ga.screen(DebuggerScreen.id);
    ga.timeStart(DebuggerScreen.id, analytics_constants.pageReady);
    _shownFirstScript = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    controller.onFirstDebuggerScreenLoad();
  }

  void _onLocationSelected(ScriptLocation? location) {
    if (location != null) {
      controller.showScriptLocation(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeArea = ValueListenableBuilder<bool>(
      valueListenable: controller.fileExplorerVisible,
      builder: (context, visible, child) {
        if (visible) {
          // TODO(devoncarew): Animate this opening and closing.
          return Split(
            axis: Axis.horizontal,
            initialFractions: const [0.70, 0.30],
            children: [
              child!,
              ProgramExplorer(
                key: DebuggerScreenBody.programExplorerKey,
                controller: controller.programExplorerController,
                onSelected: _onLocationSelected,
              ),
            ],
          );
        } else {
          return child!;
        }
      },
      child: DualValueListenableBuilder<ScriptRef?, ParsedScript?>(
        firstListenable: controller.currentScriptRef,
        secondListenable: controller.currentParsedScript,
        builder: (context, scriptRef, parsedScript, _) {
          if (scriptRef != null && parsedScript != null && !_shownFirstScript) {
            ga.timeEnd(DebuggerScreen.id, analytics_constants.pageReady);
            serviceManager.sendDwdsEvent(
              screen: DebuggerScreen.id,
              action: analytics_constants.pageReady,
            );
            _shownFirstScript = true;
          }
          return CodeView(
            key: DebuggerScreenBody.codeViewKey,
            controller: controller,
            scriptRef: scriptRef,
            parsedScript: parsedScript,
            onSelected: controller.toggleBreakpoint,
          );
        },
      ),
    );

    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.25, 0.75],
      children: [
        OutlineDecoration(child: debuggerPanes()),
        Column(
          children: [
            const DebuggingControls(),
            const SizedBox(height: denseRowSpacing),
            Expanded(
              child: codeArea,
            ),
          ],
        ),
      ],
    );
  }

  Widget debuggerPanes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FlexSplitColumn(
          totalHeight: constraints.maxHeight,
          initialFractions: const [0.40, 0.40, 0.20],
          minSizes: const [0.0, 0.0, 0.0],
          headers: <PreferredSizeWidget>[
            AreaPaneHeader(
              title: const Text(callStackTitle),
              actions: [
                CopyToClipboardControl(
                  dataProvider: () {
                    final List<String> callStackList = controller
                        .stackFramesWithLocation.value
                        .map((frame) => frame.callStackDisplay)
                        .toList();
                    for (var i = 0; i < callStackList.length; i++) {
                      callStackList[i] = '#$i ${callStackList[i]}';
                    }
                    return callStackList.join('\n');
                  },
                  buttonKey: DebuggerScreenBody.callStackCopyButtonKey,
                ),
              ],
              needsTopBorder: false,
            ),
            const AreaPaneHeader(title: Text(variablesTitle)),
            AreaPaneHeader(
              title: const Text(breakpointsTitle),
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

  Widget _breakpointsRightChild() {
    return ValueListenableBuilder<List<BreakpointAndSourcePosition>>(
      valueListenable: controller.breakpointsWithLocation,
      builder: (context, breakpoints, _) {
        return Row(
          children: [
            BreakpointsCountBadge(breakpoints: breakpoints),
            DevToolsTooltip(
              message: 'Remove all breakpoints',
              child: ToolbarAction(
                icon: Icons.delete,
                onPressed:
                    breakpoints.isNotEmpty ? controller.clearBreakpoints : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class GoToLineNumberIntent extends Intent {
  const GoToLineNumberIntent(this._context, this._controller);

  final BuildContext _context;
  final DebuggerController _controller;
}

class GoToLineNumberAction extends Action<GoToLineNumberIntent> {
  @override
  void invoke(GoToLineNumberIntent intent) {
    showGoToLineDialog(intent._context, intent._controller);
    intent._controller.toggleFileOpenerVisibility(false);
    intent._controller.toggleSearchInFileVisibility(false);
  }
}

class SearchInFileIntent extends Intent {
  const SearchInFileIntent(this._controller);

  final DebuggerController _controller;
}

class SearchInFileAction extends Action<SearchInFileIntent> {
  @override
  void invoke(SearchInFileIntent intent) {
    intent._controller.toggleSearchInFileVisibility(true);
    intent._controller.toggleFileOpenerVisibility(false);
  }
}

class EscapeIntent extends Intent {
  const EscapeIntent(this._controller);

  final DebuggerController _controller;
}

class EscapeAction extends Action<EscapeIntent> {
  @override
  void invoke(EscapeIntent intent) {
    intent._controller.toggleSearchInFileVisibility(false);
    intent._controller.toggleFileOpenerVisibility(false);
  }
}

class OpenFileIntent extends Intent {
  const OpenFileIntent(this._controller);

  final DebuggerController _controller;
}

class OpenFileAction extends Action<OpenFileIntent> {
  @override
  void invoke(OpenFileIntent intent) {
    intent._controller.toggleFileOpenerVisibility(true);
    intent._controller.toggleSearchInFileVisibility(false);
  }
}

class DebuggerStatus extends StatefulWidget {
  const DebuggerStatus({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final DebuggerController controller;

  @override
  _DebuggerStatusState createState() => _DebuggerStatusState();
}

class _DebuggerStatusState extends State<DebuggerStatus> with AutoDisposeMixin {
  String _status = '';

  @override
  void initState() {
    super.initState();

    addAutoDisposeListener(widget.controller.isPaused, _updateStatus);

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

    final event = widget.controller.lastEvent!;
    final frame = event.topFrame;
    final reason =
        event.kind == EventKind.kPauseException ? ' on exception' : '';

    final scriptUri = frame?.location?.script?.uri;
    if (scriptUri == null) {
      return 'paused$reason';
    }

    final fileName = ' at ' + scriptUri.split('/').last;
    final tokenPos = frame?.location?.tokenPos;
    final scriptRef = frame?.location?.script;
    if (tokenPos == null || scriptRef == null) {
      return 'paused$reason$fileName';
    }

    final script = await scriptManager.getScript(scriptRef);
    final pos = SourcePosition.calculatePosition(script, tokenPos);

    return 'paused$reason$fileName $pos';
  }
}

class FloatingDebuggerControls extends StatefulWidget {
  @override
  _FloatingDebuggerControlsState createState() =>
      _FloatingDebuggerControlsState();
}

class _FloatingDebuggerControlsState extends State<FloatingDebuggerControls>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<DebuggerController, FloatingDebuggerControls> {
  late bool paused;

  late double controlHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    paused = controller.isPaused.value;
    controlHeight = paused ? defaultButtonHeight : 0.0;
    addAutoDisposeListener(controller.isPaused, () {
      setState(() {
        paused = controller.isPaused.value;
        if (paused) {
          controlHeight = defaultButtonHeight;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: paused ? 1.0 : 0.0,
      duration: longDuration,
      onEnd: () {
        if (!paused) {
          setState(() {
            controlHeight = 0.0;
          });
        }
      },
      child: Container(
        color: devtoolsWarning,
        height: controlHeight,
        child: OutlinedRowGroup(
          // Default focus color for the light theme - since the background
          // color of the controls [devtoolsWarning] is the same for both
          // themes, we will use the same border color.
          borderColor: Colors.black.withOpacity(0.12),
          children: [
            Container(
              height: defaultButtonHeight,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: defaultSpacing,
              ),
              child: const Text(
                'Main isolate is paused in the debugger',
                style: TextStyle(color: Colors.black),
              ),
            ),
            DevToolsTooltip(
              message: 'Resume',
              child: TextButton(
                onPressed: controller.resume,
                child: Icon(
                  Codicons.debugContinue,
                  color: Colors.green,
                  size: defaultIconSize,
                ),
              ),
            ),
            DevToolsTooltip(
              message: 'Step over',
              child: TextButton(
                onPressed: controller.stepOver,
                child: Icon(
                  Codicons.debugStepOver,
                  color: Colors.black,
                  size: defaultIconSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
