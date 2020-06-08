// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/inspector/diagnostics_node.dart';
import 'package:devtools_app/src/inspector/inspector_data_models.dart';
import 'package:devtools_app/src/inspector/layout_explorer/flex/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

void main() {
  test('FlexProperties.fromJson creates correct value from enum', () {
    final Map<String, Object> flexJson = jsonDecode('''{
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
            "description": "BoxConstraints(w=1016.0, 0.0<=h<=Infinity)",
            "type": "DiagnosticsProperty<Constraints>",
            "name": "constraints",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3760",
            "valueId": "inspector-122",
            "summaryTree": true,
            "properties": [],
            "ifNull": "MISSING",
            "missingIfNull": true,
            "propertyType": "Constraints",
            "defaultLevel": "info"
          },
          {
            "description": "Size(1016.0, 48.0)",
            "type": "DiagnosticsProperty<Size>",
            "name": "size",
            "style": "singleLine",
            "allowNameWrap": true,
            "objectId": "inspector-3761",
            "valueId": "inspector-124",
            "summaryTree": true,
            "properties": [],
            "ifNull": "MISSING",
            "missingIfNull": true,
            "propertyType": "Size",
            "defaultLevel": "info"
          },
          {
            "description": "horizontal",
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
    ''');
    final diagnostics =
        RemoteDiagnosticsNode({'renderObject': flexJson}, null, null, null);
    final FlexLayoutProperties flexProperties =
        FlexLayoutProperties.fromDiagnostics(diagnostics);
    expect(flexProperties.direction, Axis.horizontal);
    expect(flexProperties.mainAxisAlignment, MainAxisAlignment.start);
    expect(flexProperties.mainAxisSize, MainAxisSize.max);
    expect(flexProperties.crossAxisAlignment, CrossAxisAlignment.center);
    expect(flexProperties.textDirection, TextDirection.ltr);
    expect(flexProperties.verticalDirection, VerticalDirection.down);
    expect(flexProperties.textBaseline, TextBaseline.alphabetic);
  });

  group('LayoutProperties', () {
    test('deserialize and compute min/max child correctly', () {
      final json = jsonDecode('''
       {
        "description": "Row",
        "type": "_ElementDiagnosticableTreeNode",
        "style": "dense",
        "hasChildren": true,
        "allowWrap": false,
        "objectId": "inspector-267513",
        "valueId": "inspector-251",
        "summaryTree": true,
        "constraints": {
            "type": "BoxConstraints",
            "description": "BoxConstraints(w=432.0, h=56.0)",
            "hasBoundedHeight": true,
            "hasBoundedWidth": true,
            "minWidth": "432.0",
            "minHeight": "56.0",
            "maxHeight": "56.0",
            "maxWidth": "432.0"
        },
        "size": {
            "width": "432.0",
            "height": "56.0"
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
                    "height": "56.0"
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
                    "description": "BoxConstraints(w=320.0, 0.0<=h<=56.0)",
                    "minWidth": "320.0",
                    "minHeight": "0.0",
                    "maxHeight": "56.0",
                    "maxWidth": "320.0"
                },
                "size": {
                    "width": "320.0",
                    "height": "25.0"
                },
                "flexFactor": 1,
                "createdByLocalProject": true,
                "children": [],
                "widgetRuntimeType": "Expanded"
            },
            {
                "description": "Container",
                "type": "_ElementDiagnosticableTreeNode",
                "style": "dense",
                "hasChildren": true,
                "allowWrap": false,
                "objectId": "inspector-267653",
                "valueId": "inspector-472",
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
                    "height": "56.0"
                },
                "flexFactor": null,
                "locationId": 41,
                "createdByLocalProject": true,
                "children": [],
                "widgetRuntimeType": "Container"
            }
        ],
        "widgetRuntimeType": "Row"
    }
    ''');
      final diagnostics = RemoteDiagnosticsNode(json, null, false, null);
      final layoutProperties = LayoutProperties(diagnostics);

      expect(layoutProperties.size, const Size(432.0, 56.0));
      expect(
        layoutProperties.constraints,
        const BoxConstraints(
          minWidth: 432.0,
          maxWidth: 432.0,
          minHeight: 56.0,
          maxHeight: 56.0,
        ),
      );
    });

    test('deserializeConstraints', () {
      Map<String, Object> constraintsJson = {
        'type': '_BodyBoxConstraints',
        'minWidth': '0.0',
        'maxWidth': '100.0',
        'minHeight': '0.0',
        'maxHeight': '100.0',
      };
      expect(
        LayoutProperties.deserializeConstraints(constraintsJson),
        const BoxConstraints(
          maxWidth: 100.0,
          maxHeight: 100.0,
        ),
      );

      constraintsJson = {
        'type': 'SliverConstraint',
      };
      expect(
        LayoutProperties.deserializeConstraints(constraintsJson),
        const BoxConstraints(),
      );
    });

    group('describeWidthConstraints and describeHeightConstraints', () {
      test('single value', () {
        final Map<String, Object> json = jsonDecode('''
            {
               "constraints": {
                "type": "BoxConstraints",
                "description": "BoxConstraints(w=432.0, h=56.0)",
                "hasBoundedHeight": true,
                "hasBoundedWidth": true,
                "minWidth": "25.0",
                "maxWidth": "25.0",
                "minHeight": "56.0",
                "maxHeight": "56.0"
              }
            }
          ''');
        final layoutProperties =
            LayoutProperties(RemoteDiagnosticsNode(json, null, false, null));
        expect(layoutProperties.describeHeightConstraints(), 'h=56.0');
        expect(layoutProperties.describeWidthConstraints(), 'w=25.0');
      });

      test('range value', () {
        final Map<String, Object> json = jsonDecode('''
            {
               "constraints": {
                "type": "BoxConstraints",
                "description": "BoxConstraints(w=432.0, h=56.0)",
                "hasBoundedHeight": true,
                "hasBoundedWidth": true,
                "minWidth": "25.0",
                "maxWidth": "50.0",
                "minHeight": "75.0",
                "maxHeight": "100.0"
              }
            }
          ''');
        final layoutProperties =
            LayoutProperties(RemoteDiagnosticsNode(json, null, false, null));
        expect(layoutProperties.describeHeightConstraints(), '75.0<=h<=100.0');
        expect(layoutProperties.describeWidthConstraints(), '25.0<=w<=50.0');
      });

      test('unconstrained', () {
        final Map<String, Object> json = jsonDecode('''
            {
               "constraints": {
                "type": "BoxConstraints",
                "description": "BoxConstraints(w=432.0, h=56.0)",
                "minWidth": "25.0",
                "minHeight": "75.0",
                "maxWidth": "Infinity",
                "maxHeight": "Infinity"
              }
            }
          ''');
        final layoutProperties =
            LayoutProperties(RemoteDiagnosticsNode(json, null, false, null));
        expect(layoutProperties.describeHeightConstraints(), 'h=unconstrained');
        expect(layoutProperties.describeWidthConstraints(), 'w=unconstrained');
      });
    });

    test('describeWidth and describeHeight', () {
      final Map<String, Object> json = jsonDecode('''
            {
               "size": {
                "type": "Size",
                "description": "Size(432.5, 56.0)",
                "width": "432.55",
                "height": "56.05"
              }
            }
          ''');
      final layoutProperties =
          LayoutProperties(RemoteDiagnosticsNode(json, null, false, null));
      expect(layoutProperties.describeHeight(), 'h=56.0');
      expect(layoutProperties.describeWidth(), 'w=432.6');
    });
  });

  group('computeRenderSizes', () {
    test(
        'scale sizes so the largestSize maps to largestRenderSize with forceToOccupyMaxSize=false',
        () {
      final renderSizes = computeRenderSizes(
        sizes: [100.0, 200.0, 300.0],
        smallestSize: 100.0,
        largestSize: 300.0,
        smallestRenderSize: 200.0,
        largestRenderSize: 600.0,
        maxSizeAvailable: 2000,
        useMaxSizeAvailable: false,
      );
      expect(renderSizes, [200.0, 400.0, 600.0]);
      expect(sum(renderSizes), lessThan(2000));
    });

    test(
        'scale sizes so the items fit maxSizeAvailable with forceToOccupyMaxSize=true',
        () {
      final renderSizes = computeRenderSizes(
        sizes: [100.0, 200.0, 300.0],
        smallestSize: 100.0,
        largestSize: 300.0,
        smallestRenderSize: 200.0,
        largestRenderSize: 600.0,
        maxSizeAvailable: 2000,
      );
      expect(renderSizes, [200.0, 666.6666666666667, 1133.3333333333335]);
      expect(sum(renderSizes) - 2000.0, lessThan(0.01));
    });

    test(
        'scale sizes when the items exceeds maxSizeAvailable with forceToOccupyMaxSize=true should not change any behavior',
        () {
      final renderSizes = computeRenderSizes(
        sizes: [100.0, 200.0, 300.0],
        smallestSize: 100.0,
        largestSize: 300.0,
        smallestRenderSize: 300.0,
        largestRenderSize: 900.0,
        maxSizeAvailable: 250.0,
      );
      expect(renderSizes, [300.0, 600.0, 900.0]);
      expect(sum(renderSizes), greaterThan(250.0));
    });
  });
}
