// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../shared/config_specific/launch_url/launch_url.dart';
import 'common_widgets.dart';
import 'globals.dart';
import 'theme.dart';
import 'ui/label.dart';
import 'utils.dart';

const dialogDefaultContext = 'dialog';

class DialogTitleText extends StatelessWidget {
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
    borderRadius: BorderRadius.circular(defaultBorderRadius),
  ),
);

/// A dialog, that reports unexpected error and allows to copy details and create issue.
class UnexpectedErrorDialog extends StatelessWidget {
  const UnexpectedErrorDialog({
    super.key,
    required this.additionalInfo,
  });

  final String additionalInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DevToolsDialog(
      title: const Text('Unexpected Error'),
      content: Text(
        additionalInfo,
        style: theme.fixedFontStyle,
      ),
      actions: [
        DialogTextButton(
          child: const Text('Copy details'),
          onPressed: () => unawaited(
            copyToClipboard(
              additionalInfo,
              'Error details copied to clipboard',
            ),
          ),
        ),
        DialogTextButton(
          child: const Text('Create issue'),
          onPressed: () => unawaited(
            launchUrl(
              devToolsExtensionPoints
                  .issueTrackerLink(additionalInfo: additionalInfo)
                  .url,
            ),
          ),
        ),
        const DialogCloseButton(),
      ],
    );
  }
}

/// A standardized dialog with help text and buttons `Reset to default`,
/// `APPLY` and `CANCEL`.
class StateUpdateDialog extends StatelessWidget {
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

class _StateUpdateDialogTitle extends StatelessWidget {
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

class DialogHelpText extends StatelessWidget {
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

/// A standardized dialog for use in DevTools.
///
/// It normalizes dialog layout, spacing, and look and feel.
class DevToolsDialog extends StatelessWidget {
  const DevToolsDialog({super.key, 
    Widget? title,
    required this.content,
    this.includeDivider = true,
    this.scrollable = true,
    this.actions,
  }) : titleContent = title ?? const SizedBox();

  static const contentPadding = 24.0;

  final Widget titleContent;
  final Widget content;
  final bool includeDivider;
  final bool scrollable;
  final List<Widget>? actions;

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
        buttonPadding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      ),
    );
  }
}

/// A TextButton used to close a containing dialog (Close).
class DialogCloseButton extends StatelessWidget {
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
class DialogCancelButton extends StatelessWidget {
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
class DialogApplyButton extends StatelessWidget {
  const DialogApplyButton({super.key, required this.onPressed});

  final Function onPressed;

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

class DialogTextButton extends StatelessWidget {
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
