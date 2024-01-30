// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../test_infra/test_data/dart_tooling_api/mock_api.dart';

/// A simple UI that acts as a stand-in host IDE to simplify the development
/// workflow when working on embedded tooling.
///
/// This UI interacts with [FakeDartToolingApi] to allow triggering events that
/// would normally be fired by the IDE and also shows a log of recent requests.
class VsCodeFlutterPanelMockEditor extends StatefulWidget {
  const VsCodeFlutterPanelMockEditor({
    super.key,
    required this.api,
    this.child,
  });

  /// The mock API to interact with.
  final FakeDartToolingApi api;

  final Widget? child;

  @override
  State<VsCodeFlutterPanelMockEditor> createState() =>
      _VsCodeFlutterPanelMockEditorState();
}

class _VsCodeFlutterPanelMockEditorState
    extends State<VsCodeFlutterPanelMockEditor> {
  FakeDartToolingApi get api => widget.api;

  /// The number of communication messages to keep in the log.
  static const maxLogEvents = 20;

  /// The last [maxLogEvents] communication messages sent between the panel
  /// and the "host IDE".
  final logRing = DoubleLinkedQueue<String>();

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

    // Listen to the log stream to maintain our buffer and trigger rebuilds.
    logUpdated = api.log.map((log) {
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
    return Split(
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
        Split(
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
                        onPressed: api.connectDevices,
                        child: const Text('Connect'),
                      ),
                      ElevatedButton(
                        onPressed: api.disconnectDevices,
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
                        onPressed: () => api.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'macos',
                          flutterMode: 'debug',
                        ),
                        child: const Text('Desktop debug'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => api.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'macos',
                          flutterMode: 'profile',
                        ),
                        child: const Text('Desktop profile'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => api.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'macos',
                          flutterMode: 'release',
                        ),
                        child: const Text('Desktop release'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => api.startSession(
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
                        onPressed: () => api.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'chrome',
                          flutterMode: 'debug',
                        ),
                        child: const Text('Web debug'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => api.startSession(
                          debuggerType: 'Flutter',
                          deviceId: 'chrome',
                          flutterMode: 'profile',
                        ),
                        child: const Text('Web profile'),
                      ),
                      const SizedBox(width: denseSpacing),
                      ElevatedButton(
                        onPressed: () => api.startSession(
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
                        onPressed: () => api.startSession(
                          debuggerType: 'Dart',
                          deviceId: 'macos',
                        ),
                        child: const Text('Dart CLI'),
                      ),
                    ],
                  ),
                  const SizedBox(height: denseSpacing),
                  ElevatedButton(
                    onPressed: () => api.endSessions(),
                    style: theme.elevatedButtonTheme.style!.copyWith(
                      backgroundColor: const MaterialStatePropertyAll(
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
