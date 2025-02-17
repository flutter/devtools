// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

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

final class DevToolsToggleButtonGroup extends StatelessWidget {
  const DevToolsToggleButtonGroup({
    super.key,
    required this.children,
    required this.selectedStates,
    required this.onPressed,
    this.fillColor,
    this.selectedColor,
    this.borderColor,
  });

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
        textStyle: theme.textTheme.bodyMedium,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        constraints: BoxConstraints(
          minWidth: defaultButtonHeight,
          minHeight: defaultButtonHeight,
          maxHeight: defaultButtonHeight,
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
    super.key,
    required this.onPressed,
    required this.isSelected,
    required this.message,
    required this.icon,
    this.outlined = true,
    this.label,
    this.shape,
    this.minScreenWidthForTextBeforeScaling,
    this.fillColor,
  });

  final String message;

  final VoidCallback onPressed;

  final bool isSelected;

  final IconData icon;

  final String? label;

  final OutlinedBorder? shape;

  final bool outlined;

  final double? minScreenWidthForTextBeforeScaling;

  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsToggleButtonGroup(
      borderColor:
          outlined || isSelected ? theme.focusColor : Colors.transparent,
      selectedStates: [isSelected],
      onPressed: (_) => onPressed(),
      fillColor: fillColor,
      children: [
        DevToolsTooltip(
          message: message,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
            child: MaterialIconLabel(
              color: isSelected ? theme.colorScheme.primary : null,
              iconData: icon,
              label: label,
              minScreenWidthForTextBeforeScaling:
                  minScreenWidthForTextBeforeScaling,
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
/// interior and exterior of the group. The attributes for each button can be
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
          iconAsset: buttonData.iconAsset,
          iconSize: buttonData.iconSize,
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
    this.iconAsset,
    this.iconSize,
    String? tooltip,
    this.onPressed,
    this.autofocus = false,
  })  : tooltip = tooltip ?? label,
        assert(
          label != null || icon != null || iconAsset != null,
          'At least one of icon, iconAsset, or label must be specified.',
        ),
        assert(
          icon == null || iconAsset == null,
          'Only one of icon and iconAsset may be specified.',
        );

  final String? label;
  final IconData? icon;
  final String? iconAsset;
  final double? iconSize;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool autofocus;
}

final class DevToolsFilterButton extends StatelessWidget {
  const DevToolsFilterButton({
    super.key,
    required this.onPressed,
    required this.isFilterActive,
    this.message = 'Filter',
    this.outlined = true,
  });

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

/// A DevTools-styled dropdown button.
final class RoundedDropDownButton<T> extends StatelessWidget {
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
            focusColor: theme.colorScheme.surface,
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
