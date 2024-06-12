// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../test_data/editor_service/fake_editor.dart';

/// A simple UI that acts as a stand-in host editor to simplify the development
/// workflow when working on embedded tooling. Uses a [FakeEditor] to provide
/// functionality over DTD (or legacy `postMessage`).
class MockEditorWidget extends StatefulWidget {
  const MockEditorWidget({
    super.key,
    required this.editor,
    this.child,
  });

  /// The fake editor API we can use to simulate an editor.
  final FakeEditor editor;

  final Widget? child;

  @override
  State<MockEditorWidget> createState() => _MockEditorWidgetState();
}

class _MockEditorWidgetState extends State<MockEditorWidget> {
  FakeEditor get editor => widget.editor;

  /// The number of communication messages to keep in the log.
  static const maxLogEvents = 20;

  /// The last [maxLogEvents] communication messages sent between the panel
  /// and the "host IDE".
  final logRing = ListQueue<String>();

  /// A stream that emits each time the log is updated to allow the log widget
  /// to be rebuilt.
  Stream<void>? logUpdated;

  /// Flutter icon for the sidebar.
  final sidebarImageBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAMAAADXqc3KAAABF1BMVEUAAAD///////+/v//MzMzb29vf39/j4+PV1erY2Njb29vS4eHX1+TZ2ebW1uDY2OLW3d3Y2N7Z2d/a2uDV2+DW2+DX3OHZ2eLZ2d7V2t/Y2OHX29/X29/Z2eDW2eDW2uDX2uHW2d/X2uDY2+HW2d/W2+HW2eHX2d/W2+DW2eDX2eHX2uHX29/X2d/Y2uDY2uDW2uDX2uDX2+DX2+DX2eDX2t/Y2+DX29/Y2eDW2eDX2uDX2uDW2d/X2uDX2uDY2uDX2uHX2eDX2uDX2uHY2t/X2+DX2uDY2uDX2uDX2uDX2+DW2uDX2eDX2uDX2uDX2uDX2eDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uDX2uANs9umAAAAXHRSTlMAAgMEBQcICQwNDhETFBkaJScoKTEyMzU2Nzs/QElKS0xQU1VYXV5fY2RlbXh5e3yDi4yNjpmboaKjpKepqrO1ub7AwcLEzM/R2Nnc4OPk5efr7O3w8vT3+Pn7/A+G+WEAAAABYktHRAH/Ai3eAAAA0UlEQVQoz2NgQAKythCgwYAKFCLtTIHAO0YbVVw23AREqUTroYlH0FrcGK94FJq4HExcH5c4t5IyGAiCxeUjDUGUWrQOr0cMBJiDJYwiJYCkarQOt5sXP5Al4OvKBZZgsgqRBJsDERf0c+GE2sFsE2IAVy/k78wBt53ZJkYXKi4c4MCO5C4mCR53Tz4gQyTIng3VyVoxSiDK04cVLY6YLEOlQE4PN2NElzEPkwFS0qHWLNhlxIPt2LDLiAY6cmDaoygmJqYe4cSJLmMBDStNIAcAHhssjDYY1ccAAAAASUVORK5CYII=',
  );

  @override
  void initState() {
    super.initState();

    logUpdated = editor.log.map((log) {
      logRing.add(log);
      while (logRing.length > maxLogEvents) {
        logRing.removeFirst();
      }
    });
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
                  Text(
                    'Mock Editor',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: defaultSpacing),
                  const Text(
                    'Use these buttons to simulate actions that would usually occur in the IDE.',
                  ),
                  const SizedBox(height: defaultSpacing),
                  Row(
                    children: [
                      const Text('Devices: '),
                      ElevatedButton(
                        onPressed: editor.connectDevices,
                        child: const Text('Connect'),
                      ),
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
                        onPressed: () => editor.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'macos',
                          flutterMode: 'debug',
                        ),
                        child: const Text('Desktop debug'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => editor.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'macos',
                          flutterMode: 'profile',
                        ),
                        child: const Text('Desktop profile'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => editor.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'macos',
                          flutterMode: 'release',
                        ),
                        child: const Text('Desktop release'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => editor.startSession(
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
                        onPressed: () => editor.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'chrome',
                          flutterMode: 'debug',
                        ),
                        child: const Text('Web debug'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => editor.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'chrome',
                          flutterMode: 'profile',
                        ),
                        child: const Text('Web profile'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => editor.startSession(
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
                        onPressed: () => editor.startSession(
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
                      backgroundColor: const WidgetStatePropertyAll(
                        Colors.red,
                      ),
                    ),
                    child: const Text('Stop All'),
                  ),
                ],
              ),
            ),
            Container(
              color: editorTheme.editorBackgroundColor,
              padding: const EdgeInsets.all(10),
              child: StreamBuilder(
                stream: logUpdated,
                builder: (context, snapshot) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final log in logRing)
                          OutlineDecoration.onlyBottom(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: denseSpacing,
                              ),
                              child: Text(
                                log,
                                style: Theme.of(context).fixedFontStyle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A basic theme that matches the default colours of VS Code dart/light themes
/// so the mock environment can be displayed in either.
class VsCodeTheme {
  const VsCodeTheme._({
    required this.activityBarBackgroundColor,
    required this.editorBackgroundColor,
    required this.foregroundColor,
    required this.sidebarBackgroundColor,
  });

  const VsCodeTheme.dark()
      : this._(
          activityBarBackgroundColor: const Color(0xFF333333),
          editorBackgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: const Color(0xFFD4D4D4),
          sidebarBackgroundColor: const Color(0xFF252526),
        );

  const VsCodeTheme.light()
      : this._(
          activityBarBackgroundColor: const Color(0xFF2C2C2C),
          editorBackgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: const Color(0xFF000000),
          sidebarBackgroundColor: const Color(0xFFF3F3F3),
        );

  static VsCodeTheme of(BuildContext context) {
    return Theme.of(context).isDarkTheme
        ? const VsCodeTheme.dark()
        : const VsCodeTheme.light();
  }

  final Color activityBarBackgroundColor;
  final Color editorBackgroundColor;
  final Color foregroundColor;
  final Color sidebarBackgroundColor;
}
