// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../utils/utils.dart';
import 'theme/theme.dart';

/// Create a bordered, fixed-height header area with a title and optional child
/// on the right-hand side.
///
/// This is typically used as a title for a logical area of the screen.
class AreaPaneHeader extends StatelessWidget implements PreferredSizeWidget {
  const AreaPaneHeader({
    Key? key,
    required this.title,
    this.maxLines = 1,
    this.actions = const [],
    this.leftPadding = defaultSpacing,
    this.rightPadding = densePadding,
    this.tall = false,
    this.dense = false,
    this.roundedTopBorder = true,
    this.includeTopBorder = true,
    this.includeBottomBorder = true,
    this.includeLeftBorder = false,
    this.includeRightBorder = false,
  }) : super(key: key);

  final Widget title;
  final int maxLines;
  final List<Widget> actions;
  final double leftPadding;
  final double rightPadding;
  final bool tall;
  final bool dense;

  // TODO(kenz): add support for a non uniform border to allow for
  // rounded corners when some border sides are missing. This is a
  // challenge for Flutter since it is not supported out of the box:
  // https://github.com/flutter/flutter/issues/12583.

  /// Whether to use a full border with rounded top corners consistent with
  /// material 3 styling.
  ///
  /// When true, the rounded border will take precedence over any value
  /// specified by [includeTopBorder], [includeBottomBorder],
  /// [includeLeftBorder], and [includeRightBorder].
  final bool roundedTopBorder;

  final bool includeTopBorder;
  final bool includeBottomBorder;
  final bool includeLeftBorder;
  final bool includeRightBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderSide = defaultBorderSide(theme);
    final decoration = !roundedTopBorder
        ? BoxDecoration(
            border: Border(
              top: includeTopBorder ? borderSide : BorderSide.none,
              bottom: includeBottomBorder ? borderSide : BorderSide.none,
              left: includeLeftBorder ? borderSide : BorderSide.none,
              right: includeRightBorder ? borderSide : BorderSide.none,
            ),
            color: theme.colorScheme.surface,
          )
        : null;
    Widget container = Container(
      decoration: decoration,
      padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall!,
              child: title,
            ),
          ),
          ...actions,
        ],
      ),
    );
    if (roundedTopBorder) {
      container = RoundedOutlinedBorder.onlyTop(child: container);
    }
    return SizedBox.fromSize(
      size: preferredSize,
      child: container,
    );
  }

  @override
  Size get preferredSize {
    return Size.fromHeight(
      tall ? defaultHeaderHeight + 2 * densePadding : defaultHeaderHeight,
    );
  }
}

/// A blank, drop-in replacement for [AreaPaneHeader].
///
/// Acts as an empty header widget with zero size that is compatible with
/// interfaces that expect a [PreferredSizeWidget].
class BlankHeader extends StatelessWidget implements PreferredSizeWidget {
  const BlankHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  Size get preferredSize => Size.zero;
}

/// Wraps [child] in a rounded border with default styling.
///
/// This border can optionally be made non-uniform by setting any of
/// [showTop], [showBottom], [showLeft] or [showRight] to false.
///
/// If [clip] is true, the child will be wrapped in a [ClipRRect] to ensure the
/// rounded corner of the border is drawn as expected. This should not be
/// necessary in most cases.
final class RoundedOutlinedBorder extends StatelessWidget {
  const RoundedOutlinedBorder({
    super.key,
    this.showTopLeft = true,
    this.showTopRight = true,
    this.showBottomLeft = true,
    this.showBottomRight = true,
    this.clip = false,
    required this.child,
  });

  factory RoundedOutlinedBorder.onlyTop({
    required Widget? child,
    bool clip = false,
  }) =>
      RoundedOutlinedBorder(
        showBottomLeft: false,
        showBottomRight: false,
        clip: clip,
        child: child,
      );

  factory RoundedOutlinedBorder.onlyBottom({
    required Widget? child,
    bool clip = false,
  }) =>
      RoundedOutlinedBorder(
        showTopLeft: false,
        showTopRight: false,
        clip: clip,
        child: child,
      );

  final bool showTopLeft;
  final bool showTopRight;
  final bool showBottomLeft;
  final bool showBottomRight;

  /// Whether we should clip [child].
  ///
  /// This should be used sparingly and only where necessary for performance
  /// reasons.
  final bool clip;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: showTopLeft ? defaultRadius : Radius.zero,
      topRight: showTopRight ? defaultRadius : Radius.zero,
      bottomLeft: showBottomLeft ? defaultRadius : Radius.zero,
      bottomRight: showBottomRight ? defaultRadius : Radius.zero,
    );

    var child = this.child;
    if (clip) {
      child = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.hardEdge,
        child: child,
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).focusColor),
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// Wraps [child] in a border with default styling.
///
/// This border can optionally be made non-uniform by setting any of
/// [showTop], [showBottom], [showLeft] or [showRight] to false.
final class OutlineDecoration extends StatelessWidget {
  const OutlineDecoration({
    Key? key,
    this.child,
    this.showTop = true,
    this.showBottom = true,
    this.showLeft = true,
    this.showRight = true,
  }) : super(key: key);

  factory OutlineDecoration.onlyBottom({required Widget? child}) =>
      OutlineDecoration(
        showTop: false,
        showLeft: false,
        showRight: false,
        child: child,
      );

  factory OutlineDecoration.onlyTop({required Widget? child}) =>
      OutlineDecoration(
        showBottom: false,
        showLeft: false,
        showRight: false,
        child: child,
      );

  factory OutlineDecoration.onlyLeft({required Widget? child}) =>
      OutlineDecoration(
        showBottom: false,
        showTop: false,
        showRight: false,
        child: child,
      );

  factory OutlineDecoration.onlyRight({required Widget? child}) =>
      OutlineDecoration(
        showBottom: false,
        showTop: false,
        showLeft: false,
        child: child,
      );

  final bool showTop;
  final bool showBottom;
  final bool showLeft;
  final bool showRight;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).focusColor;
    final border = BorderSide(color: color);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: showLeft ? border : BorderSide.none,
          right: showRight ? border : BorderSide.none,
          top: showTop ? border : BorderSide.none,
          bottom: showBottom ? border : BorderSide.none,
        ),
      ),
      child: child,
    );
  }
}

/// [BorderSide] styled with the DevTools default color palette.
BorderSide defaultBorderSide(ThemeData theme) {
  return BorderSide(color: theme.focusColor);
}

/// Convenience [Divider] with [Padding] that provides a good divider in forms.
final class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    Key? key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  }) : super(key: key);

  const PaddedDivider.thin({super.key})
      : padding = const EdgeInsets.only(bottom: 4.0);

  const PaddedDivider.noPadding({super.key}) : padding = EdgeInsets.zero;

  PaddedDivider.vertical({super.key, double padding = densePadding})
      : padding = EdgeInsets.symmetric(vertical: padding);

  /// The padding to place around the divider.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Divider(thickness: 1.0),
    );
  }
}

/// A button with default DevTools styling and analytics handling.
///
/// * `onPressed`: The callback to be called upon pressing the button.
/// * `minScreenWidthForTextBeforeScaling`: The minimum width the button can be before the text is
///    omitted.
class DevToolsButton extends StatelessWidget {
  const DevToolsButton({
    Key? key,
    required this.onPressed,
    this.icon,
    this.label,
    this.tooltip,
    this.color,
    this.minScreenWidthForTextBeforeScaling,
    this.elevated = false,
    this.outlined = true,
    this.tooltipPadding,
  })  : assert(
          label != null || icon != null,
          'Either icon or label must be specified.',
        ),
        super(key: key);

  factory DevToolsButton.iconOnly({
    required IconData icon,
    String? tooltip,
    VoidCallback? onPressed,
    bool outlined = true,
  }) {
    return DevToolsButton(
      icon: icon,
      outlined: outlined,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  final IconData? icon;

  final String? label;

  final String? tooltip;

  final Color? color;

  final VoidCallback? onPressed;

  final double? minScreenWidthForTextBeforeScaling;

  /// Whether this icon label button should use an elevated button style.
  final bool elevated;

  /// Whether this icon label button should use an outlined button style.
  final bool outlined;

  final EdgeInsetsGeometry? tooltipPadding;

  @override
  Widget build(BuildContext context) {
    var tooltip = this.tooltip;

    if (label == null) {
      return SizedBox(
        // This is required to force the button size.
        height: defaultButtonHeight,
        width: defaultButtonHeight,
        child: maybeWrapWithTooltip(
          tooltip: tooltip,
          tooltipPadding: tooltipPadding,
          child: outlined
              ? IconButton.outlined(
                  onPressed: onPressed,
                  iconSize: defaultIconSize,
                  icon: Icon(icon),
                )
              : IconButton(
                  onPressed: onPressed,
                  iconSize: defaultIconSize,
                  icon: Icon(
                    icon,
                  ),
                ),
        ),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    var textColor = color;
    if (textColor == null && elevated) {
      textColor =
          onPressed == null ? colorScheme.onSurface : colorScheme.onPrimary;
    }
    final iconLabel = MaterialIconLabel(
      label: label!,
      iconData: icon,
      minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
      color: textColor,
    );

    // If we hid the label due to a small screen width and the button does not
    // have a tooltip, use the label as a tooltip.
    final labelHidden =
        !isScreenWiderThan(context, minScreenWidthForTextBeforeScaling);
    if (labelHidden && tooltip == null) {
      tooltip = label;
    }

    if (elevated) {
      return SizedBox(
        // This is required to force the button size.
        height: defaultButtonHeight,
        child: maybeWrapWithTooltip(
          tooltip: tooltip,
          tooltipPadding: tooltipPadding,
          child: ElevatedButton(
            onPressed: onPressed,
            child: iconLabel,
          ),
        ),
      );
    }
    // TODO(kenz): this SizedBox wrapper should be unnecessary once
    // https://github.com/flutter/flutter/issues/79894 is fixed.
    return maybeWrapWithTooltip(
      tooltip: tooltip,
      tooltipPadding: tooltipPadding,
      child: SizedBox(
        height: defaultButtonHeight,
        width: !isScreenWiderThan(context, minScreenWidthForTextBeforeScaling)
            ? buttonMinWidth
            : null,
        child: outlined
            ? OutlinedButton(
                style: denseAwareOutlinedButtonStyle(
                  context,
                  minScreenWidthForTextBeforeScaling,
                ),
                onPressed: onPressed,
                child: iconLabel,
              )
            : TextButton(
                onPressed: onPressed,
                style: denseAwareTextButtonStyle(
                  context,
                  minScreenWidthForTextBeforeScaling:
                      minScreenWidthForTextBeforeScaling,
                ),
                child: iconLabel,
              ),
      ),
    );
  }
}

/// A widget, commonly used for icon buttons, that provides a tooltip with a
/// common delay before the tooltip is shown.
final class DevToolsTooltip extends StatelessWidget {
  const DevToolsTooltip({
    Key? key,
    this.message,
    this.richMessage,
    required this.child,
    this.waitDuration = tooltipWait,
    this.preferBelow = false,
    this.padding = const EdgeInsets.all(defaultSpacing),
    this.decoration,
    this.textStyle,
  })  : assert((message == null) != (richMessage == null)),
        super(key: key);

  final String? message;
  final InlineSpan? richMessage;
  final Widget child;
  final Duration waitDuration;
  final bool preferBelow;
  final EdgeInsetsGeometry? padding;
  final Decoration? decoration;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    TextStyle? style = textStyle;
    if (richMessage == null) {
      style ??= TextStyle(
        color: Theme.of(context).colorScheme.tooltipTextColor,
        fontSize: defaultFontSize,
      );
    }
    return Tooltip(
      message: message,
      richMessage: richMessage,
      waitDuration: waitDuration,
      preferBelow: preferBelow,
      padding: padding,
      textStyle: style,
      decoration: decoration,
      child: child,
    );
  }
}

final class DevToolsToggleButtonGroup extends StatelessWidget {
  const DevToolsToggleButtonGroup({
    Key? key,
    required this.children,
    required this.selectedStates,
    required this.onPressed,
    this.fillColor,
    this.selectedColor,
    this.borderColor,
  }) : super(key: key);

  final List<Widget> children;

  final List<bool> selectedStates;

  final void Function(int)? onPressed;

  final Color? fillColor;

  final Color? selectedColor;

  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: defaultButtonHeight,
      child: ToggleButtons(
        borderRadius: defaultBorderRadius,
        fillColor: fillColor,
        selectedColor: selectedColor,
        borderColor: borderColor,
        textStyle: theme.textTheme.bodySmall,
        constraints: BoxConstraints(
          minWidth: defaultButtonHeight,
          minHeight: defaultButtonHeight,
        ),
        isSelected: selectedStates,
        onPressed: onPressed,
        children: children,
      ),
    );
  }
}

final class DevToolsToggleButton extends StatelessWidget {
  const DevToolsToggleButton({
    Key? key,
    required this.onPressed,
    required this.isSelected,
    required this.message,
    required this.icon,
    this.outlined = true,
    this.label,
    this.shape,
  }) : super(key: key);

  final String message;

  final VoidCallback onPressed;

  final bool isSelected;

  final IconData icon;

  final String? label;

  final OutlinedBorder? shape;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return DevToolsToggleButtonGroup(
      borderColor: outlined || isSelected
          ? Theme.of(context).focusColor
          : Colors.transparent,
      selectedStates: [isSelected],
      onPressed: (_) => onPressed(),
      children: [
        DevToolsTooltip(
          message: message,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
            child: MaterialIconLabel(
              iconData: icon,
              label: label,
            ),
          ),
        ),
      ],
    );
  }
}

/// A group of buttons that share a common border.
///
/// This widget ensures the buttons are displayed with proper borders on the
/// interior and exterior of the group. The attirbutes for each button can be
/// defined by [ButtonGroupItemData] and included in [items].
final class RoundedButtonGroup extends StatelessWidget {
  const RoundedButtonGroup({
    super.key,
    required this.items,
    this.minScreenWidthForTextBeforeScaling,
  });

  final List<ButtonGroupItemData> items;
  final double? minScreenWidthForTextBeforeScaling;

  @override
  Widget build(BuildContext context) {
    Widget buildButton(int index) {
      final itemData = items[index];
      Widget button = _ButtonGroupButton(
        buttonData: itemData,
        roundedLeftBorder: index == 0,
        roundedRightBorder: index == items.length - 1,
        minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
      );
      if (index != 0) {
        button = Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(context).focusColor,
              ),
            ),
          ),
          child: button,
        );
      }
      return button;
    }

    return SizedBox(
      height: defaultButtonHeight,
      child: RoundedOutlinedBorder(
        child: Row(
          children: [
            for (int i = 0; i < items.length; i++) buildButton(i),
          ],
        ),
      ),
    );
  }
}

final class _ButtonGroupButton extends StatelessWidget {
  const _ButtonGroupButton({
    required this.buttonData,
    this.roundedLeftBorder = false,
    this.roundedRightBorder = false,
    this.minScreenWidthForTextBeforeScaling,
  });

  final ButtonGroupItemData buttonData;
  final bool roundedLeftBorder;
  final bool roundedRightBorder;
  final double? minScreenWidthForTextBeforeScaling;

  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: buttonData.tooltip,
      child: OutlinedButton(
        autofocus: buttonData.autofocus,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: densePadding),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              left: roundedLeftBorder ? defaultRadius : Radius.zero,
              right: roundedRightBorder ? defaultRadius : Radius.zero,
            ),
          ),
        ),
        onPressed: buttonData.onPressed,
        child: MaterialIconLabel(
          label: buttonData.label,
          iconData: buttonData.icon,
          minScreenWidthForTextBeforeScaling:
              minScreenWidthForTextBeforeScaling,
        ),
      ),
    );
  }
}

final class ButtonGroupItemData {
  const ButtonGroupItemData({
    this.label,
    this.icon,
    String? tooltip,
    this.onPressed,
    this.autofocus = false,
  })  : tooltip = tooltip ?? label,
        assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool autofocus;
}

final class DevToolsFilterButton extends StatelessWidget {
  const DevToolsFilterButton({
    Key? key,
    required this.onPressed,
    required this.isFilterActive,
    this.message = 'Filter',
    this.outlined = true,
  }) : super(key: key);

  final VoidCallback onPressed;
  final bool isFilterActive;
  final String message;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return DevToolsToggleButton(
      onPressed: onPressed,
      isSelected: isFilterActive,
      message: message,
      icon: Icons.filter_list,
      outlined: outlined,
    );
  }
}

/// Label including an image icon and optional text.
final class ImageIconLabel extends StatelessWidget {
  const ImageIconLabel(
    this.icon,
    this.text, {
    super.key,
    this.unscaledMinIncludeTextWidth,
  });

  final Widget icon;
  final String text;
  final double? unscaledMinIncludeTextWidth;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      children: [
        icon,
        // TODO(jacobr): animate showing and hiding the text.
        if (isScreenWiderThan(context, unscaledMinIncludeTextWidth))
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(text),
          ),
      ],
    );
  }
}

final class MaterialIconLabel extends StatelessWidget {
  const MaterialIconLabel({
    super.key,
    required this.label,
    required this.iconData,
    this.color,
    this.minScreenWidthForTextBeforeScaling,
  }) : assert(
          label != null || iconData != null,
          'Either iconData or label must be specified.',
        );

  final IconData? iconData;
  final Color? color;
  final String? label;
  final double? minScreenWidthForTextBeforeScaling;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconData != null)
          Icon(
            iconData,
            size: defaultIconSize,
            color: color,
          ),
        // TODO(jacobr): animate showing and hiding the text.
        if (label != null &&
            isScreenWiderThan(context, minScreenWidthForTextBeforeScaling))
          Padding(
            padding: EdgeInsets.only(
              left: iconData != null ? densePadding : 0.0,
            ),
            child: Text(
              label!,
              style: Theme.of(context).regularTextStyleWithColor(color),
            ),
          ),
      ],
    );
  }
}

/// Helper that will wrap [child] in a [DevToolsTooltip] widget if [tooltip] is
/// non-null.
Widget maybeWrapWithTooltip({
  required String? tooltip,
  EdgeInsetsGeometry? tooltipPadding,
  required Widget child,
}) {
  if (tooltip != null && tooltip.isNotEmpty) {
    return DevToolsTooltip(
      message: tooltip,
      padding: tooltipPadding,
      child: child,
    );
  }
  return child;
}

/// Displays a [json] map as selectable, formatted text.
final class FormattedJson extends StatelessWidget {
  const FormattedJson({
    super.key,
    this.json,
    this.formattedString,
    this.useSubtleStyle = false,
  }) : assert((json == null) != (formattedString == null));

  static const encoder = JsonEncoder.withIndent('  ');

  final Map<String, dynamic>? json;

  final String? formattedString;

  final bool useSubtleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SelectableText(
      json != null ? encoder.convert(json) : formattedString!,
      style: useSubtleStyle ? theme.subtleFixedFontStyle : theme.fixedFontStyle,
    );
  }
}

/// An extension on [ScrollController] to facilitate having the scrolling widget
/// auto scroll to the bottom on new content.
extension ScrollControllerAutoScroll on ScrollController {
// TODO(devoncarew): We lose dock-to-bottom when we receive content when we're
// off screen.

  /// Return whether the view is currently scrolled to the bottom.
  bool get atScrollBottom {
    final pos = position;
    return pos.pixels == pos.maxScrollExtent;
  }

  /// Scroll the content to the bottom using the app's default animation
  /// duration and curve..
  Future<void> autoScrollToBottom() async {
    await animateTo(
      position.maxScrollExtent,
      duration: rapidDuration,
      curve: defaultCurve,
    );

    // Scroll again if we've received new content in the interim.
    if (hasClients) {
      final pos = position;
      if (pos.pixels != pos.maxScrollExtent) {
        jumpTo(pos.maxScrollExtent);
      }
    }
  }
}
