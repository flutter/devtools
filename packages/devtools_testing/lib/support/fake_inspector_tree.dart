// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:math';

import 'package:devtools/src/inspector/inspector_service.dart';
import 'package:devtools/src/inspector/inspector_text_styles.dart' as styles;
import 'package:devtools/src/inspector/inspector_tree.dart';
import 'package:devtools/src/ui/fake_flutter/fake_flutter.dart';
import 'package:devtools/src/ui/flutter_html_shim.dart' as shim;
import 'package:devtools/src/ui/icons.dart';
import 'package:devtools/src/ui/material_icons.dart';
import 'package:meta/meta.dart';

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
        last = max(tick, 1);
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
