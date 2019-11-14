// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/inspector/diagnostics_node.dart';
import 'package:devtools_app/src/inspector/flutter/inspector_data_models.dart';
import 'package:devtools_app/src/inspector/flutter/story_of_your_layout/flex.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wrappers.dart';

void main() {
  const windowSize = Size(1500, 1500);

  Map<String, Object> buildDiagnosticsNodeJson(Axis axis) => jsonDecode('''
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
            "hasBoundedHeight": true,
            "hasBoundedWidth": true,
            "minWidth": 300.0,
            "minHeight": 60.0,
            "maxHeight": 60.0,
            "maxWidth": 300.0
        },
        "size": {
            "width": 300.0,
            "height": 60.0
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
                    "hasBoundedHeight": true,
                    "hasBoundedWidth": false,
                    "minWidth": 0.0,
                    "minHeight": 0.0,
                    "maxHeight": 56.0
                },
                "size": {
                    "width": 56.0,
                    "height": 25.0
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
                    "hasBoundedHeight": true,
                    "hasBoundedWidth": true,
                    "minWidth": 40.0,
                    "minHeight": 0.0,
                    "maxHeight": 56.0,
                    "maxWidth": 40.0
                },
                "size": {
                    "width": 40.0,
                    "height": 31.0
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
            "description": "${describeEnum(axis)}",
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
    ''');

  Widget wrap(Widget widget) => MaterialApp(home: Scaffold(body: widget));

  group('Row', () {
    final rowWidgetJsonNode = buildDiagnosticsNodeJson(Axis.horizontal);
    final node = RemoteDiagnosticsNode(rowWidgetJsonNode, null, false, null);

    testWidgets('Golden test', (WidgetTester tester) async {
      await setWindowSize(windowSize);
      final widget = wrap(StoryOfYourFlexWidget(
          FlexLayoutProperties.fromRemoteDiagnosticsNode(node)));
      await tester.pumpWidget(widget);
      await expectLater(
        find.byWidget(widget),
        matchesGoldenFile('goldens/story_of_row_layout.png'),
      );
    }, skip: kIsWeb || !isLinux);
  });
  group('Column', () {
    final columnWidgetJsonNode = buildDiagnosticsNodeJson(Axis.vertical);
    final node = RemoteDiagnosticsNode(columnWidgetJsonNode, null, false, null);
    testWidgets('Golden test', (WidgetTester tester) async {
      await setWindowSize(windowSize);
      final widget = wrap(StoryOfYourFlexWidget(
          FlexLayoutProperties.fromRemoteDiagnosticsNode(node)));
      await tester.pumpWidget(widget);
      await expectLater(
        find.byWidget(widget),
        matchesGoldenFile('goldens/story_of_column_layout.png'),
      );
    }, skip: kIsWeb || !isLinux);
  });
}
