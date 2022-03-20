// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Create an `InspectorTreeControllerFlutter` from a single `RemoteDiagnosticsNode`
InspectorTreeController inspectorTreeControllerFromNode(
    RemoteDiagnosticsNode node) {
  final controller = InspectorTreeController()
    ..config = InspectorTreeConfig(
      summaryTree: false,
      treeType: FlutterTreeType.widget,
      onNodeAdded: (_, __) {},
      onClientActiveChange: (_) {},
    );

  controller.root = InspectorTreeNode()
    ..appendChild(
      InspectorTreeNode()..diagnostic = node,
    );

  return controller;
}

/// Replicates the functionality of `getRootWidgetSummaryTreeWithPreviews` from
/// inspector_polyfill_script.dart
Future<RemoteDiagnosticsNode> widgetToInspectorTreeDiagnosticsNode({
  required Widget widget,
  required WidgetTester tester,
}) async {
  await tester.pumpWidget(wrap(widget));
  final element = find.byWidget(widget).evaluate().first;
  final nodeJson =
      element.toDiagnosticsNode(style: DiagnosticsTreeStyle.dense).toJsonMap(
            InspectorSerializationDelegate(
              service: WidgetInspectorService.instance,
              subtreeDepth: 1000000,
              summaryTree: true,
              addAdditionalPropertiesCallback: (node, delegate) {
                final additionalJson = <String, Object>{};

                final value = node.value;
                if (value is Element) {
                  final renderObject = value.renderObject;
                  if (renderObject is RenderParagraph) {
                    additionalJson['textPreview'] =
                        renderObject.text.toPlainText();
                  }
                }

                return additionalJson;
              },
            ),
          );

  return RemoteDiagnosticsNode(nodeJson, null, false, null);
}
