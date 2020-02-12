// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/inspector/diagnostics_node.dart';
import 'package:devtools_app/src/inspector/flutter/inspector_tree_flutter.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_testing/support/fake_inspector_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widgets/flutter_widgets.dart';

const summaryTreeJson = r'''{
  "description": "[root]",
  "type": "_ElementDiagnosticableTreeNode",
  "style": "dense",
  "hasChildren": true,
  "allowWrap": false,
  "objectId": "inspector-24",
  "valueId": "inspector-1",
  "summaryTree": true,
  "locationId": 0,
  "creationLocation": {
    "file": "file:///usr/local/google/home/jacobr/git/flutter/4/flutter/packages/flutter/lib/src/widgets/binding.dart",
    "line": 804,
    "column": 26,
    "parameterLocations": [
      {
        "file": null,
        "line": 805,
        "column": 7,
        "name": "container"
      },
      {
        "file": null,
        "line": 806,
        "column": 7,
        "name": "debugShortDescription"
      },
      {
        "file": null,
        "line": 807,
        "column": 7,
        "name": "child"
      }
    ]
  },
  "children": [
    {
      "description": "MyApp",
      "type": "_ElementDiagnosticableTreeNode",
      "style": "dense",
      "hasChildren": true,
      "allowWrap": false,
      "objectId": "inspector-25",
      "valueId": "inspector-3",
      "summaryTree": true,
      "locationId": 1,
      "creationLocation": {
        "file": "file:///usr/local/google/home/jacobr/git/devtools/packages/devtools_testing/fixtures/flutter_app/lib/main.dart",
        "line": 3,
        "column": 23,
        "parameterLocations": []
      },
      "createdByLocalProject": true,
      "children": [
        {
          "description": "MaterialApp",
          "type": "_ElementDiagnosticableTreeNode",
          "style": "dense",
          "hasChildren": true,
          "allowWrap": false,
          "objectId": "inspector-26",
          "valueId": "inspector-5",
          "summaryTree": true,
          "locationId": 2,
          "creationLocation": {
            "file": "file:///usr/local/google/home/jacobr/git/devtools/packages/devtools_testing/fixtures/flutter_app/lib/main.dart",
            "line": 11,
            "column": 12,
            "parameterLocations": [
              {
                "file": null,
                "line": 12,
                "column": 7,
                "name": "title"
              },
              {
                "file": null,
                "line": 13,
                "column": 7,
                "name": "theme"
              },
              {
                "file": null,
                "line": 16,
                "column": 7,
                "name": "home"
              }
            ]
          },
          "createdByLocalProject": true,
          "children": [
            {
              "description": "Scaffold",
              "type": "_ElementDiagnosticableTreeNode",
              "style": "dense",
              "hasChildren": true,
              "allowWrap": false,
              "objectId": "inspector-27",
              "valueId": "inspector-7",
              "summaryTree": true,
              "locationId": 3,
              "creationLocation": {
                "file": "file:///usr/local/google/home/jacobr/git/devtools/packages/devtools_testing/fixtures/flutter_app/lib/main.dart",
                "line": 16,
                "column": 13,
                "parameterLocations": [
                  {
                    "file": null,
                    "line": 17,
                    "column": 9,
                    "name": "appBar"
                  },
                  {
                    "file": null,
                    "line": 20,
                    "column": 9,
                    "name": "body"
                  }
                ]
              },
              "createdByLocalProject": true,
              "children": [
                {
                  "description": "Center",
                  "type": "_ElementDiagnosticableTreeNode",
                  "style": "dense",
                  "hasChildren": true,
                  "allowWrap": false,
                  "objectId": "inspector-28",
                  "valueId": "inspector-9",
                  "summaryTree": true,
                  "locationId": 4,
                  "creationLocation": {
                    "file": "file:///usr/local/google/home/jacobr/git/devtools/packages/devtools_testing/fixtures/flutter_app/lib/main.dart",
                    "line": 20,
                    "column": 21,
                    "parameterLocations": [
                      {
                        "file": null,
                        "line": 21,
                        "column": 11,
                        "name": "child"
                      }
                    ]
                  },
                  "createdByLocalProject": true,
                  "children": [
                    {
                      "description": "Text",
                      "type": "_ElementDiagnosticableTreeNode",
                      "style": "dense",
                      "hasChildren": true,
                      "allowWrap": false,
                      "objectId": "inspector-29",
                      "valueId": "inspector-11",
                      "summaryTree": true,
                      "locationId": 5,
                      "creationLocation": {
                        "file": "file:///usr/local/google/home/jacobr/git/devtools/packages/devtools_testing/fixtures/flutter_app/lib/main.dart",
                        "line": 21,
                        "column": 18,
                        "parameterLocations": [
                          {
                            "file": null,
                            "line": 21,
                            "column": 23,
                            "name": "data"
                          }
                        ]
                      },
                      "createdByLocalProject": true,
                      "children": [],
                      "widgetRuntimeType": "Text",
                      "stateful": false
                    }
                  ],
                  "widgetRuntimeType": "Center",
                  "stateful": false
                },
                {
                  "description": "AppBar",
                  "type": "_ElementDiagnosticableTreeNode",
                  "style": "dense",
                  "hasChildren": true,
                  "allowWrap": false,
                  "objectId": "inspector-30",
                  "valueId": "inspector-13",
                  "summaryTree": true,
                  "locationId": 6,
                  "creationLocation": {
                    "file": "file:///usr/local/google/home/jacobr/git/devtools/packages/devtools_testing/fixtures/flutter_app/lib/main.dart",
                    "line": 17,
                    "column": 17,
                    "parameterLocations": [
                      {
                        "file": null,
                        "line": 18,
                        "column": 11,
                        "name": "title"
                      }
                    ]
                  },
                  "createdByLocalProject": true,
                  "children": [
                    {
                      "description": "Text",
                      "type": "_ElementDiagnosticableTreeNode",
                      "style": "dense",
                      "hasChildren": true,
                      "allowWrap": false,
                      "objectId": "inspector-31",
                      "valueId": "inspector-15",
                      "summaryTree": true,
                      "locationId": 7,
                      "creationLocation": {
                        "file": "file:///usr/local/google/home/jacobr/git/devtools/packages/devtools_testing/fixtures/flutter_app/lib/main.dart",
                        "line": 18,
                        "column": 24,
                        "parameterLocations": [
                          {
                            "file": null,
                            "line": 18,
                            "column": 29,
                            "name": "data"
                          }
                        ]
                      },
                      "createdByLocalProject": true,
                      "children": [],
                      "widgetRuntimeType": "Text",
                      "stateful": false
                    }
                  ],
                  "widgetRuntimeType": "AppBar",
                  "stateful": true
                }
              ],
              "widgetRuntimeType": "Scaffold",
              "stateful": true
            }
          ],
          "widgetRuntimeType": "MaterialApp",
          "stateful": true
        }
      ],
      "widgetRuntimeType": "MyApp",
      "stateful": false
    }
  ],
  "widgetRuntimeType": "RenderObjectToWidgetAdapter<RenderBox>",
  "stateful": false
}''';

class TestClient implements InspectorControllerClient {
  @override
  void onChanged() {
    // TODO: implement onChanged
  }

  @override
  void scrollToRect(Rect rect) {
    // TODO: implement scrollToRect
  }
}

void main() {
  group('inspector tree animation', () {
    testWidgets('expand collapse', (WidgetTester tester) async {
      final node =
          RemoteDiagnosticsNode(jsonDecode(summaryTreeJson), null, false, null);
      final inspectorTree =
          FakeInspectorTree(); // InspectorTreeControllerFlutter();
      final client = TestClient();

      inspectorTree.config = InspectorTreeConfig(
        treeType: FlutterTreeType.widget,
        summaryTree: true,
        onNodeAdded: (_, __) {},
      );
      final InspectorTreeNode rootNode = inspectorTree.setupInspectorTreeNode(
        inspectorTree.createNode(),
        node,
        expandChildren: true,
        expandProperties: false,
      );
      inspectorTree.root = rootNode;

      expect(
        inspectorTree.toStringDeep(),
        equals(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center\n'
          '      │     [T]Text\n'
          '      └─▼[A]AppBar\n'
          '          [T]Text\n',
        ),
      );

      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root] (animate in)\n'
          '  ▼[M]MyApp (animate in)\n'
          '    ▼[M]MaterialApp (animate in)\n'
          '      ▼[S]Scaffold (animate in)\n'
          '      ├───▼[C]Center (animate in)\n'
          '      │     [T]Text (animate in)\n'
          '      └─▼[A]AppBar (animate in)\n'
          '          [T]Text (animate in)\n',
        ),
      );
      inspectorTree.animationDone();
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center\n'
          '      │     [T]Text\n'
          '      └─▼[A]AppBar\n'
          '          [T]Text\n',
        ),
      );

      var row = inspectorTree.getCachedRow(3);
      row.node.isExpanded = false;
      expect(
        inspectorTree.toStringDeep(),
        equals(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▶[S]Scaffold\n',
        ),
      );
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▶[S]Scaffold\n'
          '      ├───▼[C]Center (animate out)\n'
          '      │     [T]Text (animate out)\n'
          '      └─▼[A]AppBar (animate out)\n'
          '          [T]Text (animate out)\n',
        ),
      );
      inspectorTree.animationDone();

      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▶[S]Scaffold\n',
        ),
      );
      row.node.isExpanded = true;
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▼[C]Center (animate in)\n'
          '      │     [T]Text (animate in)\n'
          '      └─▼[A]AppBar (animate in)\n'
          '          [T]Text (animate in)\n',
        ),
      );

      inspectorTree.animationDone();
      row = inspectorTree.getCachedRow(4);
      row.node.isExpanded = false;
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▼[S]Scaffold\n'
              '      ├───▶[C]Center\n'
              '      │     [T]Text (animate out)\n'
              '      └─▼[A]AppBar\n'
              '          [T]Text\n',
        ),
      );

      inspectorTree.animationDone();
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
          '  ▼[M]MyApp\n'
          '    ▼[M]MaterialApp\n'
          '      ▼[S]Scaffold\n'
          '      ├───▶[C]Center\n'
          '      └─▼[A]AppBar\n'
          '          [T]Text\n',
        ),
      );

      row.node.isExpanded = true;
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▼[S]Scaffold\n'
              '      ├───▼[C]Center\n'
              '      │     [T]Text (animate in)\n'
              '      └─▼[A]AppBar\n'
              '          [T]Text\n',
        ),
      );
    });

    testWidgets('optimize', (WidgetTester tester) async {
      final node =
      RemoteDiagnosticsNode(jsonDecode(summaryTreeJson), null, false, null);
      final inspectorTree =
      FakeInspectorTree(); // InspectorTreeControllerFlutter();
      final client = TestClient();

      inspectorTree.config = InspectorTreeConfig(
        treeType: FlutterTreeType.widget,
        summaryTree: true,
        onNodeAdded: (_, __) {},
      );
      final InspectorTreeNode rootNode = inspectorTree.setupInspectorTreeNode(
        inspectorTree.createNode(),
        node,
        expandChildren: true,
        expandProperties: false,
      );
      inspectorTree.root = rootNode;

      expect(
        inspectorTree.toStringDeep(),
        equals(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▼[S]Scaffold\n'
              '      ├───▼[C]Center\n'
              '      │     [T]Text\n'
              '      └─▼[A]AppBar\n'
              '          [T]Text\n',
        ),
      );

      inspectorTree.animationDone();
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▼[S]Scaffold\n'
              '      ├───▼[C]Center\n'
              '      │     [T]Text\n'
              '      └─▼[A]AppBar\n'
              '          [T]Text\n',
        ),
      );

      var row = inspectorTree.getCachedRow(3);
      row.node.isExpanded = false;
      var animatedRows = inspectorTree.animatedRows;
      expect(
        inspectorTree.toStringDeep(),
        equals(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▶[S]Scaffold\n',
        ),
      );
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▶[S]Scaffold\n'
              '      ├───▼[C]Center (animate out)\n'
              '      │     [T]Text (animate out)\n'
              '      └─▼[A]AppBar (animate out)\n'
              '          [T]Text (animate out)\n',
        ),
      );
      inspectorTree.optimizeRowAnimation(animatedRows[4].node, animatedRows[5].node);
      expect(
        inspectorTree.toStringDeep(showAnimation: true),
        equals(
          '▼[R][root]\n'
              '  ▼[M]MyApp\n'
              '    ▼[M]MaterialApp\n'
              '      ▶[S]Scaffold\n'
              '      ├───▼[C]Center (animate out)\n'
              '      │     [T]Text (animate out)\n'
        ),
      );
    });
  });
}
