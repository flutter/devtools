// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'common.dart';
import 'theme/theme.dart';

/// A button with default DevTools styling and analytics handling.
///
/// * `onPressed`: The callback to be called upon pressing the button.
/// * `minScreenWidthForTextBeforeScaling`: The minimum width the button can be before the text is
///    omitted.
class DevToolsButton extends StatelessWidget {
  const DevToolsButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.label,
    this.tooltip,
    this.color,
    this.minScreenWidthForTextBeforeScaling,
    this.elevated = false,
    this.outlined = true,
    this.tooltipPadding,
  }) : assert(
          label != null || icon != null,
          'Either icon or label must be specified.',
        );

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
                  icon: Icon(icon),
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

/// A DevTools-styled dropdown button.
class RoundedDropDownButton<T> extends StatelessWidget {
  const RoundedDropDownButton({
    super.key,
    this.value,
    this.onChanged,
    this.isDense = false,
    this.isExpanded = false,
    this.style,
    this.selectedItemBuilder,
    this.items,
    this.roundedCornerOptions,
  });

  final T? value;

  final ValueChanged<T?>? onChanged;

  final bool isDense;

  final bool isExpanded;

  final TextStyle? style;

  final DropdownButtonBuilder? selectedItemBuilder;

  final List<DropdownMenuItem<T>>? items;

  final RoundedCornerOptions? roundedCornerOptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.backgroundColorSelected;

    Radius selectRadius(bool show) {
      return show ? defaultRadius : Radius.zero;
    }

    final style = this.style ?? theme.regularTextStyle;
    final showTopLeft = roundedCornerOptions?.showTopLeft ?? true;
    final showTopRight = roundedCornerOptions?.showTopRight ?? true;
    final showBottomLeft = roundedCornerOptions?.showBottomLeft ?? true;
    final showBottomRight = roundedCornerOptions?.showBottomRight ?? true;

    final button = Center(
      child: SizedBox(
        height: defaultButtonHeight - 2.0, // subtract 2.0 for width of border
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            padding: const EdgeInsets.only(
              left: defaultSpacing,
              right: borderPadding,
            ),
            value: value,
            onChanged: onChanged,
            isDense: isDense,
            isExpanded: isExpanded,
            borderRadius: BorderRadius.only(
              topLeft: selectRadius(showTopLeft),
              topRight: selectRadius(showTopRight),
              bottomLeft: selectRadius(showBottomLeft),
              bottomRight: selectRadius(showBottomRight),
            ),
            style: style,
            selectedItemBuilder: selectedItemBuilder,
            items: items,
            focusColor: bgColor,
          ),
        ),
      ),
    );

    if (roundedCornerOptions == RoundedCornerOptions.empty) return button;

    return RoundedOutlinedBorder(
      showTopLeft: showTopLeft,
      showTopRight: showTopRight,
      showBottomLeft: showBottomLeft,
      showBottomRight: showBottomRight,
      child: button,
    );
  }
}
