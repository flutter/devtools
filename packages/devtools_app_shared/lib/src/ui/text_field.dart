// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import 'common.dart';
import 'theme/theme.dart';

/// A DevTools-styled text field with a suffix action to clear the search field.
final class DevToolsClearableTextField extends StatelessWidget {
  DevToolsClearableTextField({
    super.key,
    TextEditingController? controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.additionalSuffixActions = const <Widget>[],
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled,
    this.roundedBorder = false,
  }) : controller = controller ?? TextEditingController();

  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final List<Widget> additionalSuffixActions;
  final String? labelText;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool autofocus;
  final bool? enabled;
  final bool roundedBorder;

  static const _contentVerticalPadding = 6.0;

  /// This is the default border radius used by the [OutlineInputBorder]
  /// constructor.
  static const _defaultInputBorderRadius =
      BorderRadius.all(Radius.circular(4.0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: defaultTextFieldHeight,
      child: TextField(
        autofocus: autofocus,
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: theme.regularTextStyle,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.only(
            top: _contentVerticalPadding,
            bottom: _contentVerticalPadding,
            left: denseSpacing,
            right: densePadding,
          ),
          constraints: BoxConstraints(
            minHeight: defaultTextFieldHeight,
            maxHeight: defaultTextFieldHeight,
          ),
          border: OutlineInputBorder(
            borderRadius: roundedBorder
                ? const BorderRadius.all(defaultRadius)
                : _defaultInputBorderRadius,
          ),
          labelText: labelText,
          labelStyle: theme.subtleTextStyle,
          hintText: hintText,
          hintStyle: theme.subtleTextStyle,
          prefixIcon: prefixIcon,
          suffix: SizedBox(
            height: inputDecorationElementHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...additionalSuffixActions,
                InputDecorationSuffixButton.clear(
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A DevTools-styled icon action button intended to be used as an
/// [InputDecoration.suffix] widget.
final class InputDecorationSuffixButton extends StatelessWidget {
  const InputDecorationSuffixButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  factory InputDecorationSuffixButton.clear({
    required VoidCallback? onPressed,
  }) =>
      InputDecorationSuffixButton(
        icon: Icons.clear,
        onPressed: onPressed,
        tooltip: 'Clear',
      );

  factory InputDecorationSuffixButton.close({
    required VoidCallback? onPressed,
  }) =>
      InputDecorationSuffixButton(
        icon: Icons.close,
        onPressed: onPressed,
        tooltip: 'Close',
      );

  factory InputDecorationSuffixButton.help({
    required VoidCallback? onPressed,
  }) =>
      InputDecorationSuffixButton(
        icon: Icons.question_mark,
        onPressed: onPressed,
        tooltip: 'Help',
      );

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return maybeWrapWithTooltip(
      tooltip: tooltip,
      child: SizedBox(
        height: inputDecorationElementHeight,
        width: inputDecorationElementHeight + denseSpacing,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          iconSize: defaultIconSize,
          splashRadius: defaultIconSize,
          icon: Icon(icon),
        ),
      ),
    );
  }
}
