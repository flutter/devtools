// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/screens/inspector_v2/layout_explorer/flex/flex.dart';
import 'package:devtools_app/src/shared/console/eval/inspector_tree.dart';
import 'package:devtools_app/src/shared/diagnostics/diagnostics_node.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../test_infra/matchers/matchers.dart';

// TODO(albertusangga): Re-enable tests in this files
// https://github.com/flutter/devtools/issues/1403
void main() {
  const windowSize = Size(1750, 1750);

  Map<String, Object> buildDiagnosticsNodeJson(Axis axis) => jsonDecode(
        '''
      {
        "description": "${axis == Axis.horizontal ? 'Row' : 'Column'}",
        "type": "_ElementDiagnosticableTreeNode",
        "style": "dense",
        "hasChildren": true,
        "allowWrap": false,
        "objectId": "inspector-267513",
        "valueId": "inspector-251",
        "summaryTree": true,
        "constraints": {
            "type": "BoxConstraints",
            "description": "BoxConstraints(w=300.0, h=60.0)",
            "minWidth": "300.0",
            "minHeight": "60.0",
            "maxHeight": "60.0",
            "maxWidth": "300.0"
        },
        "size": {
            "width": "300.0",
            "height": "60.0"
        },
        "isFlex": true,
        "children": [
            {
                "description": "Container",
                "type": "_ElementDiagnosticableTreeNode",
                "style": "dense",
                "hasChildren": true,
                "allowWrap": false,
                "objectId": "inspector-267524",
                "valueId": "inspector-269",
                "summaryTree": true,
                "constraints": {
                    "type": "BoxConstraints",
                    "description": "BoxConstraints(0.0<=w<=Infinity, 0.0<=h<=56.0)",
                    "minWidth": "0.0",
                    "minHeight": "0.0",
                    "maxHeight": "56.0",
                    "maxWidth": "Infinity"
                },
                "size": {
                    "width": "56.0",
                    "height": "25.0"
                },
                "flexFactor": null,
                "createdByLocalProject": true,
                "children": [],
                "widgetRuntimeType": "Container",
                "stateful": false
            },
            {
                "description": "Expanded",
                "type": "_ElementDiagnosticableTreeNode",
                "style": "dense",
                "hasChildren": true,
                "allowWrap": false,
                "objectId": "inspector-267563",
                "valueId": "inspector-332",
                "summaryTree": true,
                "constraints": {
                    "type": "BoxConstraints",
                    "description": "BoxConstraints(w=40.0, 0.0<=h<=56.0)",
                    "minWidth": "40.0",
                    "minHeight": "0.0",
                    "maxHeight": "56.0",
                    "maxWidth": "40.0"
                },
                "size": {
                    "width": "40.0",
                    "height": "31.0"
                },
                "flexFactor": 1,
                "createdByLocalProject": true,
                "children": [],
                "widgetRuntimeType": "Expanded"
            }
        ],
        "widgetRuntimeType": "${axis == Axis.horizontal ? 'Row' : 'Column'}",
        "renderObject": {
        "description": "RenderFlex#6cfb1 relayoutBoundary=up5",
        "type": "DiagnosticableTreeNode",
        "hasChildren": true,
        "allowWrap": false,
        "objectId": "inspector-3758",
        "valueId": "inspector-118",
        "summaryTree": true,
        "properties": [
          {
            "description": "<none> (can use size)",
            "type": "DiagnosticsProperty<ParentData>",
            "name": "parentData",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3759",
            "valueId": "inspector-120",
            "summaryTree": true,
            "properties": [],
            "ifNull": "MISSING",
            "tooltip": "can use size",
            "missingIfNull": true,
            "propertyType": "ParentData",
            "defaultLevel": "info"
          },
          {
            "description": "${axis.name}",
            "type": "EnumProperty<Axis>",
            "name": "direction",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3762",
            "valueId": "inspector-126",
            "summaryTree": true,
            "properties": [],
            "missingIfNull": false,
            "propertyType": "Axis",
            "defaultLevel": "info"
          },
          {
            "description": "start",
            "type": "EnumProperty<MainAxisAlignment>",
            "name": "mainAxisAlignment",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3763",
            "valueId": "inspector-128",
            "summaryTree": true,
            "properties": [],
            "missingIfNull": false,
            "propertyType": "MainAxisAlignment",
            "defaultLevel": "info"
          },
          {
            "description": "max",
            "type": "EnumProperty<MainAxisSize>",
            "name": "mainAxisSize",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3764",
            "valueId": "inspector-130",
            "summaryTree": true,
            "properties": [],
            "missingIfNull": false,
            "propertyType": "MainAxisSize",
            "defaultLevel": "info"
          },
          {
            "description": "center",
            "type": "EnumProperty<CrossAxisAlignment>",
            "name": "crossAxisAlignment",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3765",
            "valueId": "inspector-132",
            "summaryTree": true,
            "properties": [],
            "missingIfNull": false,
            "propertyType": "CrossAxisAlignment",
            "defaultLevel": "info"
          },
          {
            "description": "ltr",
            "type": "EnumProperty<TextDirection>",
            "name": "textDirection",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3766",
            "valueId": "inspector-83",
            "summaryTree": true,
            "properties": [],
            "defaultValue": "null",
            "missingIfNull": false,
            "propertyType": "TextDirection",
            "defaultLevel": "info"
          },
          {
            "description": "down",
            "type": "EnumProperty<VerticalDirection>",
            "name": "verticalDirection",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3767",
            "valueId": "inspector-135",
            "summaryTree": true,
            "properties": [],
            "defaultValue": "null",
            "missingIfNull": false,
            "propertyType": "VerticalDirection",
            "defaultLevel": "info"
          },
           {
            "description": "alphabetic",
            "type": "EnumProperty<TextBaseline>",
            "name": "textBaseline",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3767",
            "valueId": "inspector-135",
            "summaryTree": true,
            "properties": [],
            "defaultValue": "null",
            "missingIfNull": false,
            "propertyType": "TextBaseline",
            "defaultLevel": "info"
          }
        ]
      }
    }
    ''',
      );

  Widget wrap(Widget widget) {
    return MaterialApp(
      home: Scaffold(body: widget),
    );
  }

  /// current workaround for flaky image asset testing.
  /// https://github.com/flutter/flutter/issues/38997
  Future<void> pump(WidgetTester tester, Widget w) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(w);
      for (final element in find.byType(Image).evaluate()) {
        final Image widget = element.widget as Image;
        final ImageProvider image = widget.image;
        await precacheImage(image, element);
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgetsWithWindowSize(
    'Row golden test',
    windowSize,
    (WidgetTester tester) async {
      final rowWidgetJsonNode = buildDiagnosticsNodeJson(Axis.horizontal);
      final diagnostic =
          RemoteDiagnosticsNode(rowWidgetJsonNode, null, false, null);
      final treeNode = InspectorTreeNode()..diagnostic = diagnostic;
      final controller = TestInspectorV2Controller()..setSelectedNode(treeNode);
      final widget = wrap(FlexLayoutExplorerWidget(controller));
      await pump(tester, widget);
      await tester.pumpAndSettle();
      await expectLater(
        find.byWidget(widget),
        matchesDevToolsGolden('goldens/story_of_row_layout.png'),
      );
    },
    skip: true,
  );

  testWidgetsWithWindowSize(
    'Column golden test',
    windowSize,
    (WidgetTester tester) async {
      final columnWidgetJsonNode = buildDiagnosticsNodeJson(Axis.vertical);
      final diagnostic =
          RemoteDiagnosticsNode(columnWidgetJsonNode, null, false, null);
      final treeNode = InspectorTreeNode()..diagnostic = diagnostic;
      final controller = TestInspectorV2Controller()..setSelectedNode(treeNode);
      final widget = wrap(FlexLayoutExplorerWidget(controller));
      await pump(tester, widget);
      await expectLater(
        find.byWidget(widget),
        matchesDevToolsGolden('goldens/story_of_column_layout.png'),
      );
    },
    skip: true,
  );
}
