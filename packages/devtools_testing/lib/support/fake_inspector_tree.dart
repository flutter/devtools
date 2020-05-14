// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_app/src/ui/icons.dart';

const double fakeRowWidth = 200.0;

class FakeInspectorTree extends InspectorTreeController
    with InspectorTreeFixedRowHeightController {
  FakeInspectorTree();

  final List<Rect> scrollToRequests = [];

  @override
  InspectorTreeNode createNode() {
    return InspectorTreeNode();
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
  void setState(VoidCallback fn) {
    // Execute async calls synchronously for faster test execution.
    fn();

    setStateCalled?.complete(null);
    setStateCalled = null;
  }

  // Debugging string to make it easy to write integration tests.
  String toStringDeep(
      {bool hidePropertyLines = false, bool includeTextStyles = false}) {
    if (root == null) return '<empty>\n';
    // Visualize the ticks computed for this node so that bugs in the tick
    // computation code will result in rendering artifacts in the text output.
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < numRows; i++) {
      final row = getCachedRow(i);
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
      final InspectorTreeNode node = row?.node;
      final diagnostic = node?.diagnostic;
      if (diagnostic == null) {
        sb.write('<empty>\n');
        continue;
      }

      if (node.showExpandCollapse) {
        if (node.isExpanded) {
          sb.write('▼');
        } else {
          sb.write('▶');
        }
      }

      final icon = node.diagnostic.icon;
      if (icon is CustomIcon) {
        sb.write('[${icon.text}]');
      } else if (icon is ColorIcon) {
        sb.write('[${icon.color.value}]');
      } else if (icon is Image) {
        sb.write('[${(icon.image as AssetImage).assetName}]');
      }
      sb.write(node.diagnostic.description);

//      // TODO(jacobr): optionally visualize colors as well.
//      if (entry.text != null) {
//        if (entry.textStyle != null && includeTextStyles) {
//          final String shortStyle = styles.debugStyleNames[entry.textStyle];
//          if (shortStyle == null) {
//            // Display the style a little like an html style.
//            sb.write('<style ${entry.textStyle}>${entry.text}</style>');
//          } else {
//            if (shortStyle == '') {
//              // Omit the default text style completely for readability of
//              // the debug output.
//              sb.write(entry.text);
//            } else {
//              sb.write('<$shortStyle>${entry.text}</$shortStyle>');
//            }
//          }
//        } else {
//          sb.write(entry.text);
//        }
//      }

      if (row.isSelected) {
        sb.write(' <-- selected');
      }
      sb.write('\n');
    }
    return sb.toString();
  }
}
