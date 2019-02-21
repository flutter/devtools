// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(jacobr): make this class production quality. It is missing some
// important edge cases.

/// Use this library to render an inspector tree to HTML elements instead of
/// canvas.
library inspector_tree_html;

import 'dart:html';

import 'package:meta/meta.dart';

import '../ui/elements.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/flutter_html_shim.dart';
import '../ui/html_icon_renderer.dart';
import '../ui/icons.dart';
import 'diagnostics_node.dart';
import 'inspector_service.dart';
import 'inspector_tree.dart';
import 'inspector_tree_web.dart';

abstract class HtmlPaintEntry extends PaintEntry {
  void paint(Element parent);

  Element element;
}

class IconPaintEntry extends HtmlPaintEntry {
  IconPaintEntry({
    @required this.iconRenderer,
  });

  @override
  Icon get icon => iconRenderer.icon;

  final HtmlIconRenderer iconRenderer;

  @override
  void paint(Element parent) {
    element = iconRenderer.createElement();
    parent.append(element);
  }

  @override
  void attach(InspectorTree owner) {
    // The browser handles painting images when they are available so we don't
    // have to do anything.
  }
}

class HtmlTextPaintEntry extends HtmlPaintEntry {
  HtmlTextPaintEntry({
    @required this.text,
    @required this.color,
    @required this.font,
  });

  final String text;
  final String color;
  final String font;

  @override
  Icon get icon => null;

  @override
  void paint(Element parent) {
    element = Element.span()..text = text;
    if (color != null) {
      element.style.color = color;
    }
    if (font != null) {
      element.style.font = font;
    }
    parent.append(element);
  }
}

class InspectorTreeNodeRenderHtmlBuilder
    extends InspectorTreeNodeRenderBuilder<InspectorTreeNodeHtmlRender> {
  InspectorTreeNodeRenderHtmlBuilder({
    @required DiagnosticLevel level,
    @required DiagnosticsTreeStyle treeStyle,
    @required this.allowWrap,
  }) : super(level: level, treeStyle: treeStyle);

  TextStyle lastStyle;
  String font;
  String color;
  final bool allowWrap;
  final List<HtmlPaintEntry> _entries = [];

  @override
  void appendText(String text, TextStyle textStyle) {
    if (text == null || text.isEmpty) {
      return;
    }
    if (textStyle != lastStyle) {
      if (textStyle.color != lastStyle?.color) {
        color = colorToCss(textStyle.color);
      }
      font = fontStyleToCss(textStyle);
      lastStyle = textStyle;
    }
    _entries.add(HtmlTextPaintEntry(text: text, color: color, font: font));
  }

  @override
  void addIcon(Icon icon) {
    _entries.add(IconPaintEntry(iconRenderer: getIconRenderer(icon)));
  }

  @override
  InspectorTreeNodeHtmlRender build() {
    // The html renderer does not know what its size is.
    final classes = [
      'inspector-level-${diagnosticLevelToName[level]}',
      'inspector-style-${treeStyleToName[treeStyle]}',
    ];
    if (!allowWrap) {
      classes.add('inspector-no-wrap');
    }
    return InspectorTreeNodeHtmlRender(_entries, const Size(0, 0), classes);
  }
}

class InspectorTreeNodeHtmlRender
    extends InspectorTreeNodeRender<HtmlPaintEntry> {
  InspectorTreeNodeHtmlRender(
      List<HtmlPaintEntry> entries, Size size, this.cssClasses)
      : super(entries, size);

  final List<String> cssClasses;

  void paint(Element container) {
    container.classes.addAll(cssClasses);
    element = container;
    for (var entry in entries) {
      entry.paint(container);
    }
  }

  Element element;

  @override
  PaintEntry hitTest(Offset location) {
    // TODO(jacobr): consider removing this method from the base class.
    throw 'Not yet supported by HTML tree';
  }
}

class InspectorTreeNodeHtml extends InspectorTreeNode {
  @override
  InspectorTreeNodeRenderBuilder createRenderBuilder() {
    return InspectorTreeNodeRenderHtmlBuilder(
      level: diagnostic.level,
      treeStyle: diagnostic.style,
      allowWrap: diagnostic.allowWrap,
    );
  }
}

class InspectorTreeHtml extends InspectorTree implements InspectorTreeWeb {
  InspectorTreeHtml({
    @required bool summaryTree,
    @required FlutterTreeType treeType,
    NodeAddedCallback onNodeAdded,
    VoidCallback onSelectionChange,
    TreeEventCallback onExpand,
    TreeHoverEventCallback onHover,
  })  : _container = div(c: 'inspector-tree-html'),
        super(
          summaryTree: summaryTree,
          treeType: treeType,
          onNodeAdded: onNodeAdded,
          onSelectionChange: onSelectionChange,
          onExpand: onExpand,
          onHover: onHover,
        ) {
    _container.onClick.listen(onMouseClick);
    _container.element.onMouseMove.listen(onMouseMove);
    _container.element.onMouseLeave.listen(onMouseLeave);
  }

  InspectorTreeRow _resolveTreeRow(Element e) {
    while (e != null && !e.classes.contains('inspector-tree-row')) {
      e = e.parent;
    }
    if (e == null) {
      return null;
    }
    final parent = e.parent;
    final int index = parent.children.indexOf(e);
    assert(index >= 0 && index < numRows);
    final row = root.getRow(index, selection: selection);
    // TODO(jacobr): figure out why this assert is sometimes failing.
    // final InspectorTreeNodeHtmlRender render = row.node.renderObject;
    // assert(render.element.parent == e);
    return row;
  }

  Icon _resolveIcon(InspectorTreeRow row, Element e) {
    final InspectorTreeNodeHtmlRender render = row?.node?.renderObject;
    if (render == null) {
      return null;
    }
    while (e != null && !e.classes.contains('flutter-icon')) {
      if (e == render.element) {
        return null;
      }
      e = e.parent;
    }
    if (e == null) {
      return null;
    }
    for (var entry in render.entries) {
      if (entry.element == e) {
        return entry.icon;
      }
    }
    return null;
  }

  final CoreElement _container;

  bool _recomputeRows = false;

  @override
  void setState(modifyState) {
    // More closely match Flutter semantics where state is set immediately
    // instead of after a frame.
    modifyState();
    if (!_recomputeRows) {
      _recomputeRows = true;
      window.requestAnimationFrame((_) => _rebuildData());
    }
  }

  void _rebuildData() {
    if (_recomputeRows) {
      _recomputeRows = false;
      if (root == null) {
        _container.clear();
        return;
      }

      final int rowCount = numRows;
      // TODO(jacobr): make this rebuild more incremental.
      _container.clear();
      for (int i = 0; i < rowCount; i++) {
        _container.element.append(paintRow(i, selection: selection));
      }
    }
  }

  void onMouseClick(MouseEvent mouseEvent) {
    final row = _resolveTreeRow(mouseEvent.target);
    if (row == null) {
      return;
    }
    final Icon icon = _resolveIcon(row, mouseEvent.target);
    if (row != null) {
      onTapIcon(row, icon);
    }
  }

  void onMouseMove(MouseEvent mouseEvent) {
    if (onHover != null) {
      // TODO(jacobr): determine the icon
      onHover(_resolveTreeRow(mouseEvent.target)?.node, null);
    }
  }

  void onMouseLeave(MouseEvent mouseEvent) {
    if (onHover != null) {
      onHover(null, null);
    }
  }

  @override
  CoreElement get element => _container;

  @override
  InspectorTreeNode createNode() => InspectorTreeNodeHtml();

  Element paintRow(
    int index, {
    @required InspectorTreeNode selection,
  }) {
    try {
      final container = Element.div();
      container.classes.add('inspector-tree-row');
      // Variables incremented as part of painting.
      double currentX = 0;

      final InspectorTreeRow row = root?.getRow(index, selection: selection);
      if (row == null) {
        return container;
      }
      final InspectorTreeNode node = row.node;
      final diagnostic = node.diagnostic;
      // Add an has_property helper on RemoteDiagnosticsNode.
      if (diagnostic != null &&
          diagnostic.name?.isNotEmpty == true &&
          diagnostic.showName &&
          diagnostic.showSeparator &&
          diagnostic.description != null) {
        container.classes.add('property-value');
      }
      // final bool showExpandCollapse = node.showExpandCollapse;
      final InspectorTreeNodeHtmlRender renderObject = node.renderObject;

      // TODO(jacobr): port this code to work for the html renderer to support
      // drawing lines describing the tree. Likely the best way to render this
      // ui is by abusing CSS for drawing borders although we could also consider
      // prerendering some base64 images.
      /*
      bool hasPath = false;
      void _endPath() {
        if (!hasPath) return;
        canvas.stroke();
        hasPath = false;
      }

      void _maybeStart([Color color = Colors.grey]) {
        if (color != currentColor) {
          _endPath();
        }
        if (hasPath) return;
        hasPath = true;
        canvas.beginPath();
        if (currentColor != color) {
          currentColor = color;
          canvas.strokeStyle = colorToCss(color);
        }
        canvas.lineWidth = chartLineStrokeWidth;
      }

      for (int tick in row.ticks) {
        currentX = getDepthIndent(tick) - columnWidth * 0.5;
        if (isVisible(1.0)) {
          final highlight = row.highlightDepth == tick;
          _maybeStart(highlight ? highlightLineColor : defaultTreeLineColor);
          canvas
            ..moveTo(currentX, 0.0)
            ..lineTo(currentX, rowHeight);
        }
      }
      if (row.lineToParent) {
        final highlight = row.highlightDepth == row.depth - 1;
        currentX = getDepthIndent(row.depth - 1) - columnWidth * 0.5;
        final double width = showExpandCollapse ? columnWidth * 0.5 : columnWidth;
        if (isVisible(width)) {
          _maybeStart(highlight ? highlightLineColor : defaultTreeLineColor);
          canvas
            ..moveTo(currentX, 0.0)
            ..lineTo(currentX, rowHeight * 0.5)
            ..lineTo(currentX + width, rowHeight * 0.5);
        }
      }
      _endPath();

      */
      // Render the main row content.
      if (renderObject == null) {
        return container;
      }
      currentX = getDepthIndent(row.depth) - columnWidth;
      if (!row.node.showExpandCollapse) {
        currentX += columnWidth;
      }

      final rowContentContainer = Element.div();
      rowContentContainer.classes.add('inspector-tree-row-content');
      rowContentContainer.style.paddingLeft = '${currentX}px';
      final rowContent = Element.div();
      rowContentContainer.append(rowContent);
      renderObject.paint(rowContent);
      container.append(rowContentContainer);

      // TODO(jacobr): handle row selected backgrounds using CSS classes.
      return container;
    } catch (e, s) {
      print(s);
      return Element.div()..text = 'Error: $e, $s';
    }
  }

  @override
  void animateToTargets(List<InspectorTreeNode> targets) {
    // TODO: implement animateToTargets
    window.requestAnimationFrame((_) {
      for (var target in targets.reversed) {
        final InspectorTreeNodeHtmlRender renderObject = target.renderObject;
        // TODO(jacobr): be smarter about not calling this on all elements.
        renderObject?.element?.scrollIntoView();
      }
    });
  }

  @override
  String get tooltip => element.tooltip;

  @override
  set tooltip(String value) {
    element.tooltip = value;
  }
}
