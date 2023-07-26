// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../shared/split.dart';
import '../../../shared/theme.dart';
import '../flutter_panel.dart';
import 'dart_tooling_mock_api.dart';

/// A simple UI that acts as a stand-in host IDE to simplify the development
/// workflow when working on embedded tooling.
///
/// This UI interacts with [MockDartToolingApi] to allow triggering events that
/// would normally be fired by the IDE and also shows a log of recent requests.
class VsCodeFlutterPanelMockEditor extends StatefulWidget {
  const VsCodeFlutterPanelMockEditor({super.key});

  @override
  State<VsCodeFlutterPanelMockEditor> createState() =>
      _VsCodeFlutterPanelMockEditorState();
}

class _VsCodeFlutterPanelMockEditorState
    extends State<VsCodeFlutterPanelMockEditor> {
  /// The mock API to interact with.
  final api = MockDartToolingApi();

  /// The number of communication messages to keep in the log.
  static const maxLogEvents = 20;

  /// The last [maxLogEvents] communication messages sent between the panel
  /// and the "host IDE".
  final logRing = DoubleLinkedQueue();

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
    return Split(
      axis: Axis.horizontal,
      initialFractions: const [0.2, 0.8],
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
                color: const Color(0xFF333333),
                child: Image.memory(sidebarImageBytes),
              ),
            ),
            Expanded(child: VsCodeFlutterPanel(api)),
          ],
        ),
        Split(
          axis: Axis.vertical,
          initialFractions: const [0.5, 0.5],
          minSizes: const [200, 200],
          children: [
            Container(
              color: const Color(0xFF282828),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mock Editor',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(''),
                  const Text(
                    'Use these buttons to simulate actions that would usually occur in the IDE.',
                  ),
                  const Text(''),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: api.connectDevices,
                        child: const Text('Connect Devices'),
                      ),
                      ElevatedButton(
                        onPressed: api.disconnectDevices,
                        child: const Text('Disconnect Devices'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFF222222),
              padding: const EdgeInsets.all(10),
              child: StreamBuilder(
                stream: logUpdated,
                builder: (context, snapshot) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final log in logRing)
                        Text(
                          log,
                          style: Theme.of(context).fixedFontStyle,
                        ),
                    ],
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
