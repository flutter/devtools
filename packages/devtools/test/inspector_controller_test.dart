// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';
import 'dart:io';

import 'package:devtools/src/inspector/flutter_widget.dart';
import 'package:devtools/src/inspector/inspector_controller.dart';
import 'package:devtools/src/inspector/inspector_service.dart';
import 'package:devtools/src/inspector/inspector_text_styles.dart' as styles;
import 'package:devtools/src/inspector/inspector_tree.dart';
import 'package:devtools/src/ui/fake_flutter/fake_flutter.dart';
import 'package:devtools/src/ui/flutter_html_shim.dart' as shim;
import 'package:devtools/src/ui/icons.dart';
import 'package:devtools/src/ui/material_icons.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

import 'matchers/fake_flutter_matchers.dart';
import 'matchers/matchers.dart';
import 'support/flutter_test_driver.dart' show FlutterRunConfiguration;
import 'support/flutter_test_environment.dart';

class FakePaintEntry extends PaintEntry {
  FakePaintEntry({this.icon, this.text, this.textStyle, @required this.x});

  @override
  final Icon icon;
  final String text;
  final TextStyle textStyle;
  final double x;

  double get right {
    double right = x;
    if (icon != null) {
      right += icon.iconWidth;
    }
    if (text != null) {
      right += text.length * 10;
    }
    return right;
  }
}

class FakeInspectorTreeNodeRender
    extends InspectorTreeNodeRender<FakePaintEntry> {
  FakeInspectorTreeNodeRender(List<FakePaintEntry> entries, Size size)
      : super(entries, size);

  @override
  PaintEntry hitTest(Offset location) {
    location = location - offset;
    if (location.dy < 0 || location.dy >= size.height) {
      return null;
    }
    // There is no need to optimize this but we could perform a binary search.
    for (var entry in entries) {
      if (entry.x <= location.dx && entry.right > location.dx) {
        return entry;
      }
    }
    return null;
  }
}

class FakeInspectorTreeNodeRenderBuilder
    extends InspectorTreeNodeRenderBuilder {
  final List<FakePaintEntry> entries = [];
  double x = 0;

  @override
  void addIcon(Icon icon) {
    x += 20;
    entries.add(FakePaintEntry(icon: icon, x: x));
  }

  @override
  void appendText(String text, TextStyle textStyle) {
    x += text.length * 10;
    entries.add(FakePaintEntry(text: text, textStyle: textStyle, x: x));
  }

  @override
  InspectorTreeNodeRender build() {
    final double rowWidth = entries.isEmpty ? 0 : entries.last.right;
    return FakeInspectorTreeNodeRender(entries, Size(rowWidth, rowHeight));
  }
}

class FakeInspectorTreeNode extends InspectorTreeNode {
  @override
  InspectorTreeNodeRenderBuilder createRenderBuilder() {
    return FakeInspectorTreeNodeRenderBuilder();
  }
}

const double fakeRowWidth = 200.0;

class FakeInspectorTree extends InspectorTreeFixedRowHeight {
  FakeInspectorTree({
    @required bool summaryTree,
    @required FlutterTreeType treeType,
    @required NodeAddedCallback onNodeAdded,
    VoidCallback onSelectionChange,
    TreeEventCallback onExpand,
    TreeHoverEventCallback onHover,
  }) : super(
          summaryTree: summaryTree,
          treeType: treeType,
          onNodeAdded: onNodeAdded,
          onSelectionChange: onSelectionChange,
          onExpand: onExpand,
          onHover: onHover,
        );

  final List<Rect> scrollToRequests = [];

  @override
  InspectorTreeNode createNode() {
    return FakeInspectorTreeNode();
  }

  @override
  Rect getBoundingBox(InspectorTreeRow row) {
    return Rect.fromLTWH(
      getDepthIndent(row.depth),
      getRowY(row.index),
      fakeRowWidth,
      rowHeight,
    );
  }

  @override
  void scrollToRect(Rect targetRect) {
    scrollToRequests.add(targetRect);
  }

  Completer<void> setStateCalled;

  /// Hack to allow tests to wait until the next time this UI is updated.
  Future<void> get nextUiFrame {
    setStateCalled ??= Completer();

    return setStateCalled.future;
  }

  @override
  void setState(VoidCallback modifyState) {
    // Execute async calls synchronously for faster test execution.
    modifyState();

    setStateCalled?.complete(null);
    setStateCalled = null;

    for (int i = 0; i < numRows; i++) {
      final row = root.getRow(i, selection: selection);
      row?.node?.renderObject?.attach(
        this,
        Offset(row.depth * columnWidth, i * rowHeight),
      );
    }
  }

  // Debugging string to make it easy to write integration tests.
  String toStringDeep(
      {bool hidePropertyLines = false, bool includeTextStyles = false}) {
    if (root == null) return '<empty>\n';
    // Visualize the ticks computed for this node so that bugs in the tick
    // computation code will result in rendering artifacts in the text output.
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < numRows; i++) {
      final row = root.getRow(i, selection: selection);
      if (hidePropertyLines && row?.node?.diagnostic?.isProperty == true) {
        continue;
      }
      int last = 0;
      for (int tick in row.ticks) {
        // Visualize the line to parent if there is one.
        if (tick - last > 0) {
          sb.write('  ' * (tick - last));
        }
        if (tick == (row.depth - 1) && row.lineToParent) {
          sb.write('├─');
        } else {
          sb.write('│ ');
        }
        last = tick;
      }
      final int delta = row.depth - last;
      if (delta > 0) {
        if (row.lineToParent) {
          if (delta > 1 || last == 0) {
            sb.write('  ' * (delta - 1));
            sb.write('└─');
          } else {
            sb.write('──');
          }
        } else {
          sb.write('  ' * delta);
        }
      }
      final renderObject = row.node.renderObject;
      if (renderObject == null) {
        sb.write('<empty>\n');
        continue;
      }
      final entries = renderObject.entries;
      for (FakePaintEntry entry in entries) {
        if (entry.icon != null) {
          // Visualize icons
          final Icon icon = entry.icon;
          if (icon == collapseArrow) {
            sb.write('▼');
          } else if (icon == expandArrow) {
            sb.write('▶');
          } else if (icon is UrlIcon) {
            sb.write('[${icon.src}]');
          } else if (icon is ColorIcon) {
            sb.write('[${shim.colorToCss(icon.color)}]');
          } else if (icon is CustomIcon) {
            sb.write('[${icon.text}]');
          } else if (icon is MaterialIcon) {
            sb.write('[${icon.text}]');
          }
        }
        // TODO(jacobr): optionally visualize colors as well.
        if (entry.text != null) {
          if (entry.textStyle != null && includeTextStyles) {
            final String shortStyle = styles.debugStyleNames[entry.textStyle];
            if (shortStyle == null) {
              // Display the style a little like an html style.
              sb.write('<style ${entry.textStyle}>${entry.text}</style>');
            } else {
              if (shortStyle == '') {
                // Omit the default text style completely for readability of
                // the debug output.
                sb.write(entry.text);
              } else {
                sb.write('<$shortStyle>${entry.text}</$shortStyle>');
              }
            }
          } else {
            sb.write(entry.text);
          }
        }
      }
      if (row.isSelected) {
        sb.write(' <-- selected');
      }
      sb.write('\n');
    }
    return sb.toString();
  }

  @override
  String tooltip = '';
}

void main() async {
  Catalog.setCatalog(
      Catalog.decode(await File('web/widgets.json').readAsString()));
  InspectorService inspectorService;
  InspectorController inspectorController;
  FakeInspectorTree tree;
  FakeInspectorTree detailsTree;

  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  env.afterNewSetup = () async {
    await ensureInspectorServiceDependencies();
  };

  env.afterEverySetup = () async {
    inspectorService = await InspectorService.create(env.service);
    if (env.reuseTestEnvironment) {
      // Ensure the previous test did not set the selection on the device.
      // TODO(jacobr): add a proper method to WidgetInspectorService that does
      // this. setSelection currently ignores null selection requests which is
      // a misfeature.
      await inspectorService.inspectorLibrary.eval(
        'WidgetInspectorService.instance.selection.clear()',
        isAlive: null,
      );
    }

    await inspectorService.inferPubRootDirectoryIfNeeded();

    inspectorController = InspectorController(
      inspectorTreeFactory: ({
        summaryTree,
        treeType,
        onNodeAdded,
        onSelectionChange,
        onExpand,
        onHover,
      }) {
        return FakeInspectorTree(
          summaryTree: summaryTree,
          treeType: treeType,
          onNodeAdded: onNodeAdded,
          onSelectionChange: onSelectionChange,
          onExpand: onExpand,
          onHover: onHover,
        );
      },
      inspectorService: inspectorService,
      treeType: FlutterTreeType.widget,
    );
    inspectorController.setVisibleToUser(true);
    inspectorController.setActivate(true);

    tree = inspectorController.inspectorTree;
    detailsTree = inspectorController.details.inspectorTree;

    // This is a bit fragile. It is somewhat arbitrary that the tree is updated
    // twice after being initialized.
    await tree.nextUiFrame;
    await tree.nextUiFrame;
  };

  env.beforeEveryTearDown = () async {
    inspectorController?.dispose();
    inspectorController = null;
    inspectorService?.dispose();
    inspectorService = null;
  };

  group('inspector controller tests', () {
    tearDownAll(() async {
      await env.tearDownEnvironment(force: true);
    });

    test('initial state', () async {
      await env.setupEnvironment();

      expect(
          tree.toStringDeep(),
          equalsIgnoringHashCodes(
            '▼[R] root ]\n'
            '  ▼[M] MyApp\n'
            '    ▼[M] MaterialApp\n'
            '      ▼[S] Scaffold\n'
            '      ├───▼[C] Center\n'
            '      │     [/icons/inspector/textArea.png] Text\n'
            '      └─▼[A] AppBar\n'
            '          [/icons/inspector/textArea.png] Text\n',
          ));

      expect(
          tree.toStringDeep(includeTextStyles: true),
          equalsGoldenIgnoringHashCodes(
              'inspector_controller_initial_tree_with_styles.txt'));

      expect(detailsTree.toStringDeep(), equalsIgnoringHashCodes('<empty>\n'));

      await env.tearDownEnvironment();
    });

    test('select widget', () async {
      await env.setupEnvironment();

      // select row index 5.
      simulateRowClick(tree, rowIndex: 5);
      const textSelected = // Comment to make dartfmt behave.
          '▼[R] root ]\n'
          '  ▼[M] MyApp\n'
          '    ▼[M] MaterialApp\n'
          '      ▼[S] Scaffold\n'
          '      ├───▼[C] Center\n'
          '      │     [/icons/inspector/textArea.png] Text <-- selected\n'
          '      └─▼[A] AppBar\n'
          '          [/icons/inspector/textArea.png] Text\n';

      expect(tree.toStringDeep(), equalsIgnoringHashCodes(textSelected));
      expect(
        tree.toStringDeep(includeTextStyles: true),
        equalsGoldenIgnoringHashCodes(
            'inspector_controller_selection_with_styles.txt'),
      );

      await detailsTree.nextUiFrame;
      expect(
        detailsTree.toStringDeep(),
        equalsGoldenIgnoringHashCodes(
            'inspector_controller_text_details_tree.txt'),
      );

      expect(
        detailsTree.toStringDeep(includeTextStyles: true),
        equalsGoldenIgnoringHashCodes(
            'inspector_controller_text_details_tree_with_styles.txt'),
      );

      // Select the RichText row.
      simulateRowClick(detailsTree, rowIndex: 10);
      expect(
        detailsTree.toStringDeep(),
        equalsGoldenIgnoringHashCodes(
            'inspector_controller_text_details_tree_richtext_selected.txt'),
      );

      // Test hovering over the icon shown when a property has its default
      // value.
      const int rowIndex = 2;
      final double y = detailsTree.getRowY(rowIndex);
      final textAlignRow = detailsTree.getRow(Offset(0, y));
      final FakePaintEntry lastIconEntry = textAlignRow
          .node.renderObject.entries
          .firstWhere((entry) => entry.icon == defaultIcon, orElse: () => null);
      // If the entry doesn't have the defaultIcon then the tree has changed
      // and the rest of this test case won't make sense.
      expect(lastIconEntry.icon, equals(defaultIcon));
      expect(tree.tooltip, isEmpty);
      await tree.onHover(textAlignRow.node, lastIconEntry);
      expect(tree.tooltip, equals('Default value'));
      await tree.onHover(null, null);
      expect(tree.tooltip, isEmpty);
      // TODO(jacobr): add a test that covers hovering over an enum value
      // and getting a tooltip containing all its values.

      // make sure the main tree didn't change due to changing selection in the
      // detail tree
      expect(tree.toStringDeep(), equalsIgnoringHashCodes(textSelected));

      // select row index 3.
      simulateRowClick(tree, rowIndex: 3);

      expect(
          tree.toStringDeep(),
          equalsIgnoringHashCodes(
            '▼[R] root ]\n'
            '  ▼[M] MyApp\n'
            '    ▼[M] MaterialApp\n'
            '      ▼[S] Scaffold <-- selected\n'
            '      ├───▼[C] Center\n'
            '      │     [/icons/inspector/textArea.png] Text\n'
            '      └─▼[A] AppBar\n'
            '          [/icons/inspector/textArea.png] Text\n',
          ));

      await detailsTree.nextUiFrame;
      // This tree is huge. If there is a change to package:flutter it may
      // change. If this happens don't panic and rebaseline the content.
      expect(
        detailsTree.toStringDeep(),
        equalsGoldenIgnoringHashCodes(
            'inspector_controller_details_tree_scaffold.txt'),
      );

      // The important thing about this is that the details tree should scroll
      // instead of re-rooting as the selected row is already visible in the
      // details tree.
      simulateRowClick(tree, rowIndex: 4);
      expect(
          tree.toStringDeep(),
          equalsIgnoringHashCodes(
            '▼[R] root ]\n'
            '  ▼[M] MyApp\n'
            '    ▼[M] MaterialApp\n'
            '      ▼[S] Scaffold\n'
            '      ├───▼[C] Center <-- selected\n'
            '      │     [/icons/inspector/textArea.png] Text\n'
            '      └─▼[A] AppBar\n'
            '          [/icons/inspector/textArea.png] Text\n',
          ));

      await detailsTree.nextUiFrame;
      expect(
        detailsTree.toStringDeep(hidePropertyLines: true),
        equalsGoldenIgnoringHashCodes(
            'inspector_controller_details_tree_scrolled_to_center.txt'),
      );

      // Selecting the root node of the details tree should change selection
      // in the main tree.
      simulateRowClick(detailsTree, rowIndex: 0);
      expect(
          tree.toStringDeep(),
          equalsIgnoringHashCodes(
            '▼[R] root ]\n'
            '  ▼[M] MyApp\n'
            '    ▼[M] MaterialApp\n'
            '      ▼[S] Scaffold <-- selected\n'
            '      ├───▼[C] Center\n'
            '      │     [/icons/inspector/textArea.png] Text\n'
            '      └─▼[A] AppBar\n'
            '          [/icons/inspector/textArea.png] Text\n',
          ));

      // Verify that the details tree scrolled back as well.
      // However, now more nodes are expanded.
      expect(
        detailsTree.toStringDeep(hidePropertyLines: true),
        equalsGoldenIgnoringHashCodes(
            'inspector_controller_details_tree_scaffold_expanded.txt'),
      );

      expect(
        detailsTree.toStringDeep(
            hidePropertyLines: true, includeTextStyles: true),
        equalsGoldenIgnoringHashCodes(
            'inspector_controller_details_tree_scaffold_with_styles.txt'),
      );

      // TODO(jacobr): add tests that verified that we scrolled the view to the
      // correct points on selection.

      await env.tearDownEnvironment();
    });

    // TODO(jacobr): uncomment hotReload test once the hot reload test is not
    // flaky. https://github.com/flutter/devtools/issues/642
    /*
    test('hotReload', () async {
      if (flutterVersion == '1.2.1') {
        // This test can be flaky in Flutter 1.2.1 because of
        // https://github.com/dart-lang/sdk/issues/33838
        // so we just skip it. This block of code can be removed after the next
        // stable flutter release.
        // TODO(dantup): Remove this.
        return;
      }
      await env.setupEnvironment();

      await serviceManager.performHotReload();
      // Ensure the inspector does not fall over and die after a hot reload.
      expect(
          tree.toStringDeep(),
          equalsIgnoringHashCodes(
            '▼[R] root ]\n'
            '  ▼[M] MyApp\n'
            '    ▼[M] MaterialApp\n'
            '      ▼[S] Scaffold\n'
            '      ├───▼[C] Center\n'
            '      │     [/icons/inspector/textArea.png] Text <-- selected\n'
            '      └─▼[A] AppBar\n'
            '          [/icons/inspector/textArea.png] Text\n',
          ));

      // TODO(jacobr): would be nice to have some tests that trigger a hot
      // reload that actually changes app state in a meaningful way.

      await env.tearDownEnvironment();
    });
    */
// TODO(jacobr): uncomment out the hotRestart tests once
// https://github.com/flutter/devtools/issues/337 is fixed.
/*
    test('hotRestart', () async {
      await env.setupEnvironment();

      // The important thing about this is that the details tree should scroll
      // instead of re-rooting as the selected row is already visible in the
      // details tree.
      simulateRowClick(tree, rowIndex: 4);
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R] root ]\n'
              '  ▼[M] MyApp\n'
              '    ▼[M] MaterialApp\n'
              '      ▼[S] Scaffold\n'
              '      ├───▼[C] Center <-- selected\n'
              '      │     ▼[/icons/inspector/textArea.png] Text\n'
              '      └─▼[A] AppBar\n'
              '          ▼[/icons/inspector/textArea.png] Text\n',
        ),
      );

      /// After the hot restart some existing calls to the vm service may
      /// timeout and that is ok.
      serviceManager.service.doNotWaitForPendingFuturesBeforeExit();

      await serviceManager.performHotRestart();
      // The isolate starts out paused on a hot restart so we have to resume
      // it manually to make the test pass.

      await serviceManager.service
          .resume(serviceManager.isolateManager.selectedIsolate.id);

      // First UI transition is to an empty tree.
      await detailsTree.nextUiFrame;
      expect(tree.toStringDeep(), equalsIgnoringHashCodes('<empty>\n'));

      // Notice that the selection has been lost due to the hot restart.
      await detailsTree.nextUiFrame;
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R] root ]\n'
              '  ▼[M] MyApp\n'
              '    ▼[M] MaterialApp\n'
              '      ▼[S] Scaffold\n'
              '      ├───▼[C] Center\n'
              '      │     ▼[/icons/inspector/textArea.png] Text\n'
              '      └─▼[A] AppBar\n'
              '          ▼[/icons/inspector/textArea.png] Text\n',
        ),
      );

      // Verify that the selection can actually be changed after a restart.
      simulateRowClick(tree, rowIndex: 4);
      expect(
        tree.toStringDeep(),
        equalsIgnoringHashCodes(
          '▼[R] root ]\n'
              '  ▼[M] MyApp\n'
              '    ▼[M] MaterialApp\n'
              '      ▼[S] Scaffold\n'
              '      ├───▼[C] Center <-- selected\n'
              '      │     ▼[/icons/inspector/textArea.png] Text\n'
              '      └─▼[A] AppBar\n'
              '          ▼[/icons/inspector/textArea.png] Text\n',
        ),
      );
      await env.tearDownEnvironment();
    });
*/
  }, tags: 'useFlutterSdk', timeout: const Timeout.factor(8));
}

void simulateRowClick(FakeInspectorTree tree, {@required int rowIndex}) {
  // The x coordinate does not matter as any tap in the row counts.
  tree.onTap(Offset(0, tree.getRowY(rowIndex)));
}
