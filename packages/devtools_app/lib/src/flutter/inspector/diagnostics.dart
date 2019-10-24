// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Icon;

import '../../inspector/diagnostics_node.dart';
import '../../inspector/inspector_controller.dart';
import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import '../../inspector/inspector_tree.dart';
import '../../ui/flutter/flutter_icon_renderer.dart';
import '../../ui/icons.dart';
import '../../ui/material_icons.dart';
import '../../utils.dart';

final ColorIconMaker _colorIconMaker = ColorIconMaker();
final CustomIconMaker _customIconMaker = CustomIconMaker();
final DevToolsIcon defaultIcon = _customIconMaker.fromInfo('Default');

const bool _showRenderObjectPropertiesAsLinks = false;

/// Presents the content of a single [RemoteDiagnosticsNode].
///
/// Use this class any time you want to display a single [RemoteDiagnosticsNode]
/// in debugging UI whether you are displaying the node in the [InspectorTree]
/// in console output, or a debugger.
/// See also:
/// * [InspectorTree], which uses this class to display each node in the in
///   inspector tree.
class DiagnosticsNodeDescription extends StatefulWidget {
  const DiagnosticsNodeDescription(this.diagnostic,
                                   {this.debugLayoutModeEnabled});

  final RemoteDiagnosticsNode diagnostic;

  final ValueNotifier<bool> debugLayoutModeEnabled;

  @override
  _DiagnosticsNodeDescriptionState createState() =>
    _DiagnosticsNodeDescriptionState();
}

class _DiagnosticsNodeDescriptionState extends State<DiagnosticsNodeDescription>
  with SingleTickerProviderStateMixin {
  AnimationController _animationController;
  Animation<Color> _colorAnimation;

  ColorTween _getColorTween() {
    final Color beginColor = textStyleForLevel(widget.diagnostic.level).color;
    final Color endColor = widget.diagnostic.warning ? textStyleForLevel(
      DiagnosticLevel.warning).color : beginColor;
    return ColorTween(begin: beginColor, end: endColor);
  }

  @override
  void initState() {
    super.initState();
    if (widget.diagnostic == null) return;
    _animationController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _colorAnimation = _getColorTween().animate(_animationController);
  }

  @override
  void dispose() {
    super.dispose();
    _animationController.dispose();
  }

  Widget _toFlutterIcon(DevToolsIcon icon) {
    return Padding(
      padding: const EdgeInsets.only(right: iconPadding),
      child: getIconWidget(icon),
    );
  }

  void _addDescription(List<Widget> output,
                       String description,
                       TextStyle textStyle, {
                         bool isProperty,
                       }) {
    if (widget.diagnostic.isDiagnosticableValue) {
      final match = treeNodePrimaryDescriptionPattern.firstMatch(description);
      if (match != null) {
        output.add(Text(match.group(1), style: textStyle));
        if (match
          .group(2)
          .isNotEmpty) {
          output.add(Text(
            match.group(2),
            style: inspector_text_styles.unimportant,
          ));
        }
        return;
      }
    } else if (widget.diagnostic.type == 'ErrorDescription') {
      final match = assertionThrownBuildingError.firstMatch(description);
      if (match != null) {
        output.add(Text(match.group(1), style: textStyle));
        output.add(Text(match.group(3), style: textStyle));
        return;
      }
    }
    if (description?.isNotEmpty == true) {
      if (widget.debugLayoutModeEnabled == null)
        output.add(Text(description, style: textStyle));
      else {
        output.add(
          ValueListenableBuilder<bool>(
            valueListenable: widget.debugLayoutModeEnabled,
            builder: (_, debugLayoutModeEnabled, child) {
              if (debugLayoutModeEnabled)
                _animationController.forward();
              else
                _animationController.reverse();
              return child;
            },
            child: AnimatedBuilder(
              animation: _colorAnimation,
                builder: (context, child) => Text(
                  description,
                  style: textStyle.merge(TextStyle(
                    color: _colorAnimation.value
                  ))
                ),
              ),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.diagnostic == null) {
      return const SizedBox();
    }
    final icon = widget.diagnostic.icon;
    final children = <Widget>[];

    if (icon != null) {
      children.add(_toFlutterIcon(icon));
    }
    final String name = widget.diagnostic.name;
    TextStyle textStyle = textStyleForLevel(widget.diagnostic.level);

    if (widget.diagnostic.isProperty) {
      // Display of inline properties.
      final String propertyType = widget.diagnostic.propertyType;
      final Map<String, Object> properties = widget.diagnostic
        .valuePropertiesJson;

      if (name?.isNotEmpty == true && widget.diagnostic.showName) {
        children.add(
          Text('$name${widget.diagnostic.separator} ', style: textStyle));
      }

      if (widget.diagnostic.isCreatedByLocalProject) {
        textStyle = textStyle.merge(inspector_text_styles.regularBold);
      }

      String description = widget.diagnostic.description;
      if (propertyType != null && properties != null) {
        switch (propertyType) {
          case 'Color':
            {
              final int alpha = JsonUtils.getIntMember(properties, 'alpha');
              final int red = JsonUtils.getIntMember(properties, 'red');
              final int green = JsonUtils.getIntMember(properties, 'green');
              final int blue = JsonUtils.getIntMember(properties, 'blue');
              String radix(int chan) => chan.toRadixString(16).padLeft(2, '0');
              if (alpha == 255) {
                description = '#${radix(red)}${radix(green)}${radix(blue)}';
              } else {
                description =
                '#${radix(alpha)}${radix(red)}${radix(green)}${radix(blue)}';
              }

              final Color color = Color.fromARGB(alpha, red, green, blue);
              children
                .add(_toFlutterIcon(_colorIconMaker.getCustomIcon(color)));
              break;
            }

          case 'IconData':
            {
              final int codePoint =
              JsonUtils.getIntMember(properties, 'codePoint');
              if (codePoint > 0) {
                final DevToolsIcon icon =
                FlutterMaterialIcons.getIconForCodePoint(codePoint);
                if (icon != null) {
                  children.add(_toFlutterIcon(icon));
                }
              }
              break;
            }
        }
      }

      if (_showRenderObjectPropertiesAsLinks &&
        propertyType == 'RenderObject') {
        textStyle = textStyle..merge(inspector_text_styles.link);
      }

      // TODO(jacobr): custom display for units, iterables, and padding.
      _addDescription(
        children,
        description,
        textStyle,
        isProperty: true,
      );

      if (widget.diagnostic.level == DiagnosticLevel.fine &&
        widget.diagnostic.hasDefaultValue) {
        children.add(const Text(' '));
        children.add(_toFlutterIcon(defaultIcon));
      }
    } else {
      // Non property, regular node case.
      if (name?.isNotEmpty == true && widget.diagnostic.showName &&
        name != 'child') {
        if (name.startsWith('child ')) {
          children.add(Text(name, style: inspector_text_styles.unimportant));
        } else {
          children.add(Text(name, style: textStyle));
        }

        if (widget.diagnostic.showSeparator) {
          children.add(Text(
            widget.diagnostic.separator,
            style: inspector_text_styles.unimportant,
          ));
          if (widget.diagnostic.separator != ' ' &&
            widget.diagnostic.description.isNotEmpty) {
            children.add(Text(
              ' ',
              style: inspector_text_styles.unimportant,
            ));
          }
        }
      }

      if (!widget.diagnostic.isSummaryTree &&
        widget.diagnostic.isCreatedByLocalProject) {
        textStyle = textStyle.merge(inspector_text_styles.regularBold);
      }

      _addDescription(
        children,
        widget.diagnostic.description,
        textStyle,
        isProperty: false,
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}
