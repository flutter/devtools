// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/diagnostics/diagnostics_node.dart';
import '../../../../shared/primitives/utils.dart';
import '../../inspector_data_models.dart';
import 'overflow_indicator_painter.dart';
import 'theme.dart';
import 'widgets_theme.dart';

/// A widget for positioning sized widgets that follows layout as follows:
///      | top    |
/// left | center | right
///      | bottom |
@immutable
class BorderLayout extends StatelessWidget {
  const BorderLayout({
    Key? key,
    this.left,
    this.leftWidth,
    this.top,
    this.topHeight,
    this.right,
    this.rightWidth,
    this.bottom,
    this.bottomHeight,
    this.center,
  })  : assert(
          left != null ||
              top != null ||
              right != null ||
              bottom != null ||
              center != null,
        ),
        super(key: key);

  final Widget? center;
  final Widget? top;
  final Widget? left;
  final Widget? right;
  final Widget? bottom;

  final double? leftWidth;
  final double? rightWidth;
  final double? topHeight;
  final double? bottomHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Center(
          child: Container(
            margin: EdgeInsets.only(
              left: leftWidth ?? 0,
              right: rightWidth ?? 0,
              top: topHeight ?? 0,
              bottom: bottomHeight ?? 0,
            ),
            child: center,
          ),
        ),
        if (top != null)
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(height: topHeight, child: top),
          ),
        if (left != null)
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: leftWidth, child: left),
          ),
        if (right != null)
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: rightWidth, child: right),
          ),
        if (bottom != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(height: bottomHeight, child: bottom),
          ),
      ],
    );
  }
}

@immutable
class Truncateable extends StatelessWidget {
  const Truncateable({Key? key, this.truncate = false, required this.child})
      : super(key: key);

  final Widget child;
  final bool truncate;

  @override
  Widget build(BuildContext context) {
    return Flexible(flex: truncate ? 1 : 0, child: child);
  }
}

/// Widget that draws bounding box with the title (usually widget name) in its top left
///
/// [hint] is an optional widget to be placed in the top right of the box
/// [child] is an optional widget to be placed in the center of the box
/// [borderColor] outer box border color and background color for the title
/// [textColor] color for title text
class WidgetVisualizer extends StatelessWidget {
  const WidgetVisualizer({
    Key? key,
    required this.title,
    this.hint,
    required this.isSelected,
    required this.layoutProperties,
    required this.child,
    this.overflowSide,
    this.largeTitle = false,
  }) : super(key: key);

  final LayoutProperties layoutProperties;
  final String title;
  final Widget child;
  final Widget? hint;
  final bool isSelected;
  final bool largeTitle;

  final OverflowSide? overflowSide;

  static const _overflowIndicatorSize = 20.0;
  static const _borderUnselectedWidth = 1.0;
  static const _borderSelectedWidth = 3.0;
  static const _selectedPadding = 4.0;

  bool get drawOverflow => overflowSide != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final properties = layoutProperties;
    final borderColor = WidgetTheme.fromName(properties.node.description).color;
    final boxAdjust = isSelected ? _selectedPadding : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hintLocal = hint;
        return OverflowBox(
          minWidth: constraints.minWidth + boxAdjust,
          maxWidth: constraints.maxWidth + boxAdjust,
          maxHeight: constraints.maxHeight + boxAdjust,
          minHeight: constraints.minHeight + boxAdjust,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
                width:
                    isSelected ? _borderSelectedWidth : _borderUnselectedWidth,
              ),
              color: isSelected
                  ? theme.canvasColor.brighten()
                  : theme.canvasColor.darken(),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                if (drawOverflow)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: OverflowIndicatorPainter(
                        overflowSide!,
                        _overflowIndicatorSize,
                      ),
                    ),
                  ),
                Container(
                  margin: EdgeInsets.only(
                    right: overflowSide == OverflowSide.right
                        ? _overflowIndicatorSize
                        : 0.0,
                    bottom: overflowSide == OverflowSide.bottom
                        ? _overflowIndicatorSize
                        : 0.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: largeTitle
                                      ? defaultMaxRenderWidth
                                      : minRenderWidth *
                                          widgetTitleMaxWidthPercentage,
                                ),
                                decoration: BoxDecoration(color: borderColor),
                                padding: const EdgeInsets.all(4.0),
                                child: Center(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: colorScheme.widgetNameColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            if (hintLocal != null) Flexible(child: hintLocal),
                          ],
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnimatedLayoutProperties<T extends LayoutProperties>
    implements LayoutProperties {
  AnimatedLayoutProperties(this.begin, this.end, this.animation)
      : assert(begin.children.length == end.children.length),
        _children = [
          for (var i = 0; i < begin.children.length; i++)
            AnimatedLayoutProperties(
              begin.children[i],
              end.children[i],
              animation,
            ),
        ];

  final T begin;
  final T end;
  final Animation<double> animation;
  final List<LayoutProperties> _children;

  @override
  LayoutProperties? get parent => end.parent;

  @override
  set parent(LayoutProperties? parent) {
    end.parent = parent;
  }

  @override
  List<LayoutProperties> get children {
    return _children;
  }

  List<double> _lerpList(List<double> l1, List<double> l2) {
    assert(l1.length == l2.length);
    if (l1.isEmpty) return [];
    final animationLocal = animation;
    return [
      for (var i = 0; i < children.length; i++)
        lerpDouble(l1[i], l2[i], animationLocal.value)!,
    ];
  }

  @override
  List<double> childrenDimensions(Axis axis) {
    final beginDimensions = begin.childrenDimensions(axis);
    final endDimensions = end.childrenDimensions(axis);
    return _lerpList(beginDimensions, endDimensions).cast<double>();
  }

  @override
  List<double> get childrenHeights =>
      _lerpList(begin.childrenHeights, end.childrenHeights).cast<double>();

  @override
  List<double> get childrenWidths =>
      _lerpList(begin.childrenWidths, end.childrenWidths).cast<double>();

  @override
  BoxConstraints? get constraints {
    try {
      return BoxConstraints.lerp(
        begin.constraints,
        end.constraints,
        animation.value,
      );
    } catch (e) {
      return end.constraints;
    }
  }

  @override
  String describeWidthConstraints() {
    final constraintsLocal = constraints!;
    return constraintsLocal.hasBoundedWidth
        ? LayoutProperties.describeAxis(
            constraintsLocal.minWidth,
            constraintsLocal.maxWidth,
            'w',
          )
        : 'w=unconstrained';
  }

  @override
  String describeHeightConstraints() {
    final constraintsLocal = constraints!;
    return constraintsLocal.hasBoundedHeight
        ? LayoutProperties.describeAxis(
            constraintsLocal.minHeight,
            constraintsLocal.maxHeight,
            'h',
          )
        : 'h=unconstrained';
  }

  @override
  String describeWidth() => 'w=${toStringAsFixed(size.width)}';

  @override
  String describeHeight() => 'h=${toStringAsFixed(size.height)}';

  @override
  String? get description => end.description;

  @override
  double dimension(Axis axis) {
    return lerpDouble(
      begin.dimension(axis),
      end.dimension(axis),
      animation.value,
    )!;
  }

  @override
  num? get flexFactor =>
      lerpDouble(begin.flexFactor, end.flexFactor, animation.value);

  @override
  bool get hasChildren => children.isNotEmpty;

  @override
  double get height => size.height;

  @override
  bool get isFlex => begin.isFlex && end.isFlex;

  @override
  RemoteDiagnosticsNode get node => end.node;

  @override
  Size get size {
    return Size.lerp(begin.size, end.size, animation.value)!;
  }

  @override
  int get totalChildren => end.totalChildren;

  @override
  double get width => size.width;

  @override
  bool get hasFlexFactor => begin.hasFlexFactor && end.hasFlexFactor;

  @override
  LayoutProperties copyWith({
    List<LayoutProperties>? children,
    BoxConstraints? constraints,
    String? description,
    int? flexFactor,
    FlexFit? flexFit,
    bool? isFlex,
    Size? size,
  }) {
    return LayoutProperties.values(
      node: node,
      children: children ?? this.children,
      constraints: constraints ?? this.constraints,
      description: description ?? this.description,
      flexFactor: flexFactor ?? this.flexFactor,
      flexFit: flexFit ?? this.flexFit,
      isFlex: isFlex ?? this.isFlex,
      size: size ?? this.size,
    );
  }

  @override
  bool get isOverflowWidth => end.isOverflowWidth;

  @override
  bool get isOverflowHeight => end.isOverflowHeight;

  @override
  FlexFit? get flexFit => end.flexFit;

  @override
  List<LayoutProperties> get displayChildren => end.displayChildren;
}

class LayoutExplorerBackground extends StatelessWidget {
  const LayoutExplorerBackground({
    Key? key,
    required this.colorScheme,
  }) : super(key: key);

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: colorScheme.isLight ? 0.3 : 0.2,
        child: Image.asset(
          colorScheme.isLight
              ? negativeSpaceLightAssetName
              : negativeSpaceDarkAssetName,
          fit: BoxFit.none,
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
        ),
      ),
    );
  }
}
