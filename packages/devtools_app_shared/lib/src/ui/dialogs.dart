// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'common.dart';
import 'theme/theme.dart';

const dialogDefaultContext = 'dialog';

/// A standardized dialog for use in DevTools.
///
/// It normalizes dialog layout, spacing, and look and feel.
final class DevToolsDialog extends StatelessWidget {
  const DevToolsDialog({
    super.key,
    Widget? title,
    required this.content,
    this.includeDivider = true,
    this.scrollable = true,
    this.actions,
    this.actionsAlignment,
  }) : titleContent = title ?? const SizedBox();

  static const contentPadding = 24.0;

  final Widget titleContent;
  final Widget content;
  final bool includeDivider;
  final bool scrollable;
  final List<Widget>? actions;
  final MainAxisAlignment? actionsAlignment;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AlertDialog(
        scrollable: scrollable,
        title: Column(
          children: [
            titleContent,
            includeDivider
                ? const PaddedDivider(
                    padding: EdgeInsets.only(bottom: denseRowSpacing),
                  )
                : const SizedBox(height: defaultSpacing),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          contentPadding,
          0,
          contentPadding,
          contentPadding,
        ),
        content: content,
        actions: actions,
        actionsAlignment: actionsAlignment,
        buttonPadding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      ),
    );
  }
}

/// A [Text] widget styled for dialog titles.
final class DialogTitleText extends StatelessWidget {
  const DialogTitleText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

List<Widget> dialogSubHeader(ThemeData theme, String titleText) {
  return [
    Text(titleText, style: theme.textTheme.titleMedium),
    const PaddedDivider(padding: EdgeInsets.only(bottom: denseRowSpacing)),
  ];
}

final dialogTextFieldDecoration = InputDecoration(
  border: OutlineInputBorder(
    borderRadius: defaultBorderRadius,
  ),
);

/// A standardized dialog with help text and buttons `Reset to default`,
/// `APPLY` and `CANCEL`.
final class StateUpdateDialog extends StatelessWidget {
  const StateUpdateDialog({
    super.key,
    required this.title,
    required this.child,
    required this.onResetDefaults,
    required this.onApply,
    this.onCancel,
    this.dialogWidth,
    this.helpText,
    this.helpBuilder,
  });

  final String title;
  final String? helpText;
  final Widget Function(BuildContext)? helpBuilder;
  final VoidCallback? onResetDefaults;
  final VoidCallback? onApply;
  final VoidCallback? onCancel;
  final Widget child;
  final double? dialogWidth;

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: _StateUpdateDialogTitle(
        title: title,
        onResetDefaults: onResetDefaults,
      ),
      content: Container(
        padding: const EdgeInsets.only(
          left: defaultSpacing,
          right: defaultSpacing,
          bottom: defaultSpacing,
        ),
        width: dialogWidth ?? defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child,
            if (helpText != null) ...[
              const SizedBox(height: defaultSpacing),
              DialogHelpText(helpText: helpText!),
            ],
            if (helpBuilder != null) ...[
              const SizedBox(height: defaultSpacing),
              helpBuilder!.call(context),
            ],
          ],
        ),
      ),
      actions: [
        DialogApplyButton(onPressed: onApply ?? () {}),
        DialogCancelButton(cancelAction: onCancel),
      ],
    );
  }
}

final class _StateUpdateDialogTitle extends StatelessWidget {
  const _StateUpdateDialogTitle({required this.title, this.onResetDefaults});

  final String title;
  final VoidCallback? onResetDefaults;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DialogTitleText(title),
        TextButton(
          onPressed: onResetDefaults,
          child: const MaterialIconLabel(
            label: 'Reset to default',
            iconData: Icons.replay,
          ),
        ),
      ],
    );
  }
}

final class DialogHelpText extends StatelessWidget {
  const DialogHelpText({super.key, required this.helpText});

  static TextStyle? textStyle(BuildContext context) =>
      Theme.of(context).subtleTextStyle;

  final String helpText;

  @override
  Widget build(BuildContext context) {
    return Text(
      helpText,
      style: textStyle(context),
    );
  }
}

/// A TextButton used to close a containing dialog (Close).
final class DialogCloseButton extends StatelessWidget {
  const DialogCloseButton({super.key, this.onClose, this.label = 'CLOSE'});

  final VoidCallback? onClose;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DialogTextButton(
      onPressed: () {
        onClose?.call();
        Navigator.of(context, rootNavigator: true).pop('dialog');
      },
      child: Text(label),
    );
  }
}

/// A TextButton used to close a containing dialog (Cancel).
final class DialogCancelButton extends StatelessWidget {
  const DialogCancelButton({super.key, this.cancelAction});

  final VoidCallback? cancelAction;

  @override
  Widget build(BuildContext context) {
    return DialogTextButton(
      onPressed: () {
        if (cancelAction != null) cancelAction!();
        Navigator.of(context).pop(dialogDefaultContext);
      },
      child: const Text('CANCEL'),
    );
  }
}

/// A TextButton used to close a containing dialog (APPLY).
final class DialogApplyButton extends StatelessWidget {
  const DialogApplyButton({super.key, required this.onPressed});

  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return DialogTextButton(
      onPressed: () {
        onPressed();
        Navigator.of(context).pop(dialogDefaultContext);
      },
      child: const Text('APPLY'),
    );
  }
}

final class DialogTextButton extends StatelessWidget {
  const DialogTextButton({super.key, this.onPressed, required this.child});

  final VoidCallback? onPressed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: child,
    );
  }
}
