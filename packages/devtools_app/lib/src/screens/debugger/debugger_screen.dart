// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:codicon/codicon.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/diagnostics/primitives/source_location.dart';
import '../../shared/flex_split_column.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/listenable.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/routing.dart';
import '../../shared/screen.dart';
import '../../shared/utils.dart';
import 'breakpoints.dart';
import 'call_stack.dart';
import 'codeview.dart';
import 'codeview_controller.dart';
import 'controls.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'key_sets.dart';
import 'program_explorer.dart';
import 'program_explorer_model.dart';
import 'variables.dart';

class DebuggerScreen extends Screen {
  DebuggerScreen()
      : super.conditional(
          id: id,
          requiresDebugBuild: true,
          title: ScreenMetaData.debugger.title,
          icon: ScreenMetaData.debugger.icon,
          showFloatingDebuggerControls: false,
        );

  static final id = ScreenMetaData.debugger.id;

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
  const DebuggerScreenBody({super.key});

  static final codeViewKey = GlobalKey(debugLabel: 'codeViewKey');
  static final scriptViewKey = GlobalKey(debugLabel: 'scriptViewKey');
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
    ga.timeStart(DebuggerScreen.id, gac.pageReady);
    _shownFirstScript = false;
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      if (!_shownFirstScript ||
          controller.codeViewController.navigationInProgress) return;
      final routerDelegate = DevToolsRouterDelegate.of(context);
      routerDelegate.updateStateIfChanged(
        CodeViewSourceLocationNavigationState(
          script: controller.codeViewController.currentScriptRef.value!,
          line: 0,
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    unawaited(controller.onFirstDebuggerScreenLoad());
  }

  @override
  Widget build(BuildContext context) {
    final codeViewController = controller.codeViewController;
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.25, 0.75],
      children: [
        RoundedOutlinedBorder(
          clip: true,
          child: debuggerPanes(),
        ),
        Column(
          children: [
            const DebuggingControls(),
            const SizedBox(height: intermediateSpacing),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: codeViewController.fileExplorerVisible,
                builder: (context, visible, child) {
                  // Conditional expression
                  // ignore: prefer-conditional-expression
                  if (visible) {
                    // TODO(devoncarew): Animate this opening and closing.
                    return Split(
                      axis: Axis.horizontal,
                      initialFractions: const [0.7, 0.3],
                      children: [
                        child!,
                        RoundedOutlinedBorder(
                          clip: true,
                          child: ProgramExplorer(
                            controller:
                                codeViewController.programExplorerController,
                            onNodeSelected: _onNodeSelected,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return child!;
                  }
                },
                child: MultiValueListenableBuilder(
                  listenables: [
                    codeViewController.currentScriptRef,
                    codeViewController.currentParsedScript,
                  ],
                  builder: (context, values, _) {
                    final scriptRef = values.first as ScriptRef?;
                    final parsedScript = values.second as ParsedScript?;
                    if (scriptRef != null &&
                        parsedScript != null &&
                        !_shownFirstScript) {
                      ga.timeEnd(
                        DebuggerScreen.id,
                        gac.pageReady,
                      );
                      unawaited(
                        serviceManager.sendDwdsEvent(
                          screen: DebuggerScreen.id,
                          action: gac.pageReady,
                        ),
                      );
                      _shownFirstScript = true;
                    }

                    return CodeView(
                      key: DebuggerScreenBody.codeViewKey,
                      codeViewController: codeViewController,
                      debuggerController: controller,
                      scriptRef: scriptRef,
                      parsedScript: parsedScript,
                      onSelected: (script, line) => unawaited(
                        breakpointManager.toggleBreakpoint(script, line),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onNodeSelected(VMServiceObjectNode? node) {
    final location = node?.location;
    if (location != null) {
      final routerDelegate = DevToolsRouterDelegate.of(context);
      Router.navigate(context, () {
        routerDelegate.updateStateIfChanged(
          CodeViewSourceLocationNavigationState(
            script: location.scriptRef,
            line: location.location?.line ?? 0,
            object: node!.object,
          ),
        );
      });
    }
  }

  Widget debuggerPanes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FlexSplitColumn(
          totalHeight: constraints.maxHeight,
          initialFractions: const [0.4, 0.4, 0.2],
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
              roundedTopBorder: false,
              includeTopBorder: false,
            ),
            const AreaPaneHeader(
              title: Text(variablesTitle),
              roundedTopBorder: false,
            ),
            AreaPaneHeader(
              title: const Text(breakpointsTitle),
              actions: [
                _breakpointsRightChild(),
              ],
              rightPadding: 0.0,
              roundedTopBorder: false,
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
      valueListenable: breakpointManager.breakpointsWithLocation,
      builder: (context, breakpoints, _) {
        return Row(
          children: [
            BreakpointsCountBadge(breakpoints: breakpoints),
            DevToolsTooltip(
              message: 'Remove all breakpoints',
              child: ToolbarAction(
                icon: Icons.delete,
                onPressed: breakpoints.isNotEmpty
                    ? () => unawaited(breakpointManager.clearBreakpoints())
                    : null,
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
    showGoToLineDialog(
      intent._context,
      intent._controller.codeViewController,
    );
    intent._controller.codeViewController
      ..toggleFileOpenerVisibility(false)
      ..toggleSearchInFileVisibility(false);
  }
}

class SearchInFileIntent extends Intent {
  const SearchInFileIntent(this._controller);

  final DebuggerController _controller;
}

class SearchInFileAction extends Action<SearchInFileIntent> {
  @override
  void invoke(SearchInFileIntent intent) {
    intent._controller.codeViewController
      ..toggleSearchInFileVisibility(true)
      ..toggleFileOpenerVisibility(false);
  }
}

class EscapeIntent extends Intent {
  const EscapeIntent(this._controller);

  final DebuggerController _controller;
}

class EscapeAction extends Action<EscapeIntent> {
  @override
  void invoke(EscapeIntent intent) {
    intent._controller.codeViewController
      ..toggleSearchInFileVisibility(false)
      ..toggleFileOpenerVisibility(false);
  }
}

class OpenFileIntent extends Intent {
  const OpenFileIntent(this._controller);

  final DebuggerController _controller;
}

class OpenFileAction extends Action<OpenFileIntent> {
  @override
  void invoke(OpenFileIntent intent) {
    intent._controller.codeViewController
      ..toggleFileOpenerVisibility(true)
      ..toggleSearchInFileVisibility(false);
  }
}

class DebuggerStatus extends StatefulWidget {
  const DebuggerStatus({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final DebuggerController controller;

  @override
  State<DebuggerStatus> createState() => _DebuggerStatusState();
}

class _DebuggerStatusState extends State<DebuggerStatus> with AutoDisposeMixin {
  String _status = '';

  bool get _isPaused => serviceManager.isMainIsolatePaused;

  @override
  void initState() {
    super.initState();

    _updateStatusOnPause();
    unawaited(_updateStatus());
  }

  @override
  void didUpdateWidget(DebuggerStatus oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller == oldWidget.controller) return;

    cancelListeners();
    _updateStatusOnPause();
  }

  void _updateStatusOnPause() {
    addAutoDisposeListener(
      serviceManager.isolateManager.mainIsolateState?.isPaused,
      () => unawaited(
        _updateStatus(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _status,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Future<void> _updateStatus() async {
    final status = await _computeStatus();
    if (status != _status) {
      setState(() {
        _status = status;
      });
    }
  }

  Future<String> _computeStatus() async {
    if (!_isPaused) {
      return 'running';
    }

    final event = widget.controller.lastEvent;
    final String reason;
    final Frame? frame;

    if (event == null) {
      reason = '';
      frame = null;
    } else {
      frame = event.topFrame;
      // TODO(polina-c): https://github.com/flutter/devtools/issues/5387
      // Reason may be wrong.
      reason = event.kind == EventKind.kPauseException ? ' on exception' : '';
    }

    final location = frame?.location;
    final scriptUri = location?.script?.uri;
    if (scriptUri == null) {
      return 'paused$reason';
    }

    final fileName = ' at ${scriptUri.split('/').last}';
    final tokenPos = location?.tokenPos;
    final scriptRef = location?.script;
    if (tokenPos == null || scriptRef == null) {
      return 'paused$reason$fileName';
    }

    final script = await scriptManager.getScript(scriptRef);
    final pos = SourcePosition.calculatePosition(script, tokenPos);

    return 'paused$reason$fileName $pos';
  }
}

class FloatingDebuggerControls extends StatefulWidget {
  const FloatingDebuggerControls({super.key});

  @override
  State<FloatingDebuggerControls> createState() =>
      _FloatingDebuggerControlsState();
}

class _FloatingDebuggerControlsState extends State<FloatingDebuggerControls>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<DebuggerController, FloatingDebuggerControls> {
  late double controlHeight;

  bool get _isPaused => serviceManager.isMainIsolatePaused;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    cancelListeners();

    controlHeight = _isPaused ? defaultButtonHeight : 0.0;
    addAutoDisposeListener(
      serviceManager.isolateManager.mainIsolateState?.isPaused,
      () {
        setState(() {
          if (_isPaused) {
            controlHeight = defaultButtonHeight;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: _isPaused ? 1.0 : 0.0,
      duration: longDuration,
      onEnd: () {
        if (!_isPaused) {
          setState(() {
            controlHeight = 0.0;
          });
        }
      },
      child: Container(
        color: colorScheme.warningContainer,
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
              child: Text(
                'Main isolate is paused in the debugger',
                style: TextStyle(color: colorScheme.onWarningContainer),
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
