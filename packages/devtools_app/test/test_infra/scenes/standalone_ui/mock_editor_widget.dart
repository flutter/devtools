// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:devtools_app/src/shared/primitives/list_queue_value_notifier.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import 'editor_service/simulated_editor.dart';
import 'shared/common_ui.dart';

/// A simple UI that acts as a stand-in host editor to simplify the development
/// workflow when working on embedded tooling.
///
/// Uses a [SimulatedEditor] to provide functionality over DTD (or legacy
/// `postMessage`).
class MockEditorWidget extends StatefulWidget {
  const MockEditorWidget({
    super.key,
    required this.editor,
    required this.clientLog,
    this.child,
  });

  /// The fake editor API we can use to simulate an editor.
  final SimulatedEditor editor;

  /// A stream of protocol traffic between the sidebar and DTD.
  final Stream<String> clientLog;

  final Widget? child;

  @override
  State<MockEditorWidget> createState() => _MockEditorWidgetState();
}

class _MockEditorWidgetState extends State<MockEditorWidget>
    with AutoDisposeMixin {
  SimulatedEditor get editor => widget.editor;

  Stream<String> get clientLog => widget.clientLog;

  Stream<String> get editorLog => editor.log;

  /// The number of communication messages to keep in the logs.
  static const maxLogEvents = 20;

  /// The last [maxLogEvents] communication messages sent between the sidebar
  /// and DTD.
  final clientLogRing = ListQueueValueNotifier<String>(ListQueue());

  /// The last [maxLogEvents] communication messages sent between the editor
  /// and DTD.
  final editorLogRing = ListQueueValueNotifier<String>(ListQueue());

  /// Flutter icon for the sidebar.
  final sidebarImageBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAABF1BMVEUAAAD///////+/v//MzMzb29vf39/j4+PV1erY2Njb29vS4eHX1+TZ2ebW1uDY2OLW3d3Y2N7Z2d/a2uDV2+DW2+DX3OHZ2eLZ2d7V2t/Y2OHX29/X29/Z2eDW2eDW2uDX2uHW2d/X2uDY2+HW2d/W2+HW2eHX2d/W2+DW2eDX2eHX2uHX29/X2d/Y2uDY2uDW2uDX2uDX2+DX2+DX2eDX2t/Y2+DX29/Y2eDW2eDX2uDX2uDW2d/X2uDX2uDY2uDX2uHX2eDX2uDX2uHY2t/X2+DX2uDY2uDX2uDX2uDX2+DW2uDX2eDX2uDX2uDX2uDX2eDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uANs9umAAAAXHRSTlMAAgMEBQcICQwNDhETFBkaJScoKTEyMzU2Nzs/QElKS0xQU1VYXV5fY2RlbXh5e3yDi4yNjpmboaKjpKepqrO1ub7AwcLEzM/R2Nnc4OPk5efr7O3w8vT3+Pn7/A+G+WEAAAABYktHRAH/Ai3eAAAA0UlEQVQoz2NgQAKythCgwYAKFCLtTIHAO0YbVVw23AREqUTroYlH0FrcGK94FJq4HExcH5c4t5IyGAiCxeUjDUGUWrQOr0cMBJiDJYwiJYCkarQOt5sXP5Al4OvKBZZgsgqRBJsDERf0c+GE2sFsE2IAVy/k78wBt53ZJkYXKi4c4MCO5C4mCR53Tz4gQyTIng3VyVoxSiDK04cVLY6YLEOlQE4PN2NElzEPkwFS0qHWLNhlxIPt2LDLiAY6cmDaoygmJqYe4cSJLmMBDStNIAcAHhssjDYY1ccAAAAASUVORK5CYII=',
  );

  @override
  void initState() {
    super.initState();

    // Listen to the log streams to maintain our buffer and trigger rebuilds.
    autoDisposeStreamSubscription(
      clientLog.listen((log) {
        clientLogRing.add(log);
        while (clientLogRing.length > maxLogEvents) {
          clientLogRing.removeFirst();
        }
      }),
    );
    autoDisposeStreamSubscription(
      editorLog.listen((log) {
        editorLogRing.add(log);
        while (editorLogRing.length > maxLogEvents) {
          editorLogRing.removeFirst();
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorTheme = VsCodeTheme.of(context);
    final theme = Theme.of(context);
    return SplitPane(
      axis: Axis.horizontal,
      initialFractions: const [0.25, 0.75],
      minSizes: const [200, 200],
      children: [
        Row(
          children: [
            SizedBox(
              width: 48,
              child: Container(
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 60),
                constraints: const BoxConstraints.expand(width: 48),
                color: editorTheme.activityBarBackgroundColor,
                child: Image.memory(sidebarImageBytes),
              ),
            ),
            Expanded(
              child: Container(
                color: editorTheme.sidebarBackgroundColor,
                child: widget.child ?? const Placeholder(),
              ),
            ),
          ],
        ),
        SplitPane(
          axis: Axis.vertical,
          initialFractions: const [0.5, 0.5],
          minSizes: const [200, 200],
          children: [
            Container(
              color: editorTheme.editorBackgroundColor,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mock Editor', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: defaultSpacing),
                  const Text(
                    'Use these buttons to simulate actions that would usually occur in the IDE.',
                  ),
                  const SizedBox(height: defaultSpacing),
                  Row(
                    children: [
                      const Text('Editor: '),
                      ElevatedButton(
                        onPressed:
                            editor.connected
                                ? null
                                : _withUpdate(editor.connectEditor),
                        child: const Text('Connect'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed:
                            editor.connected
                                ? _withUpdate(editor.disconnectEditor)
                                : null,
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultSpacing),
                  Row(
                    children: [
                      const Text('Devices: '),
                      ElevatedButton(
                        onPressed: editor.connectDevices,
                        child: const Text('Connect'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: editor.disconnectDevices,
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultSpacing),
                  const Text('Debug Sessions: '),
                  const SizedBox(height: denseSpacing),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed:
                            () => editor.startSession(
                              debuggerType: 'Flutter',
                              deviceId: 'macos',
                              flutterMode: 'debug',
                            ),
                        child: const Text('Desktop debug'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed:
                            () => editor.startSession(
                              debuggerType: 'Flutter',
                              deviceId: 'macos',
                              flutterMode: 'profile',
                            ),
                        child: const Text('Desktop profile'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed:
                            () => editor.startSession(
                              debuggerType: 'Flutter',
                              deviceId: 'macos',
                              flutterMode: 'release',
                            ),
                        child: const Text('Desktop release'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed:
                            () => editor.startSession(
                              debuggerType: 'Flutter',
                              deviceId: 'macos',
                              flutterMode: 'jit_release',
                            ),
                        child: const Text('Desktop jit_release'),
                      ),
                    ],
                  ),
                  const SizedBox(height: denseSpacing),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed:
                            () => editor.startSession(
                              debuggerType: 'Flutter',
                              deviceId: 'chrome',
                              flutterMode: 'debug',
                            ),
                        child: const Text('Web debug'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed:
                            () => editor.startSession(
                              debuggerType: 'Flutter',
                              deviceId: 'chrome',
                              flutterMode: 'profile',
                            ),
                        child: const Text('Web profile'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed:
                            () => editor.startSession(
                              debuggerType: 'Flutter',
                              deviceId: 'chrome',
                              flutterMode: 'release',
                            ),
                        child: const Text('Web release'),
                      ),
                    ],
                  ),
                  const SizedBox(height: denseSpacing),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed:
                            () => editor.startSession(
                              debuggerType: 'Dart',
                              deviceId: 'macos',
                            ),
                        child: const Text('Dart CLI'),
                      ),
                    ],
                  ),
                  const SizedBox(height: denseSpacing),
                  ElevatedButton(
                    onPressed: () => editor.stopAllSessions(),
                    style: theme.elevatedButtonTheme.style!.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(Colors.red),
                    ),
                    child: const Text('Stop All'),
                  ),
                ],
              ),
            ),
            DefaultTabController(
              length: 2,
              child: Container(
                color: editorTheme.editorBackgroundColor,
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: 'Client/Sidebar Log'),
                        Tab(text: 'Server Log'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final logRing in [clientLogRing, editorLogRing])
                            ValueListenableBuilder(
                              valueListenable: logRing,
                              builder: (context, logRing, _) {
                                return ListView.builder(
                                  itemCount: logRing.length,
                                  itemBuilder:
                                      (context, index) =>
                                          OutlineDecoration.onlyBottom(
                                            child: Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: denseSpacing,
                                                  ),
                                              child: Text(
                                                logRing.elementAt(index),
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).fixedFontStyle,
                                              ),
                                            ),
                                          ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Returns a function that calls [f] and then once it completes, [setState].
  Future<void> Function() _withUpdate<T>(FutureOr<T> Function() f) {
    return () async {
      await f();
      setState(() {});
    };
  }
}
