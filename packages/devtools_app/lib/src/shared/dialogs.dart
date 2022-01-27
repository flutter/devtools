// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'theme.dart';

const dialogDefaultContext = 'dialog';

Text dialogTitleText(ThemeData theme, String text) {
  return Text(text, style: theme.textTheme.headline6);
}

List<Widget> dialogSubHeader(ThemeData theme, String titleText) {
  return [
    Text(titleText, style: theme.textTheme.subtitle1),
    const PaddedDivider(padding: EdgeInsets.only(bottom: denseRowSpacing)),
  ];
}

/// A standardized dialog for use in DevTools.
///
/// It normalizes dialog layout, spacing, and look and feel.
class DevToolsDialog extends StatelessWidget {
  const DevToolsDialog({
    @required this.title,
    @required this.content,
    this.includeDivider = true,
    this.actions,
  });

  static const contentPadding = 24.0;

  final Widget title;
  final Widget content;
  final bool includeDivider;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Column(
        children: [
          title,
          includeDivider
              ? const PaddedDivider(
                  padding: EdgeInsets.only(bottom: denseRowSpacing),
                )
              : const SizedBox(height: defaultSpacing),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
          contentPadding, 0, contentPadding, contentPadding),
      content: content,
      actions: actions,
      buttonPadding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
    );
  }
}

/// A TextButton used to close a containing dialog (Close).
class DialogCloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DialogTextButton(
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop('dialog');
      },
      child: const Text('CLOSE'),
    );
  }
}

/// A TextButton used to close a containing dialog (Cancel).
class DialogCancelButton extends StatelessWidget {
  const DialogCancelButton({this.cancelAction}) : super();

  final VoidCallback cancelAction;

  @override
  Widget build(BuildContext context) {
    return DialogTextButton(
      onPressed: () {
        if (cancelAction != null) cancelAction();
        Navigator.of(context).pop(dialogDefaultContext);
      },
      child: const Text('CANCEL'),
    );
  }
}

/// A TextButton used to close a containing dialog (APPLY).
class DialogApplyButton extends StatelessWidget {
  const DialogApplyButton({@required this.onPressed}) : super();

  final Function onPressed;

  @override
  Widget build(BuildContext context) {
    return DialogTextButton(
      onPressed: () {
        if (onPressed != null) onPressed();
        Navigator.of(context).pop(dialogDefaultContext);
      },
      child: const Text('APPLY'),
    );
  }
}

class DialogTextButton extends StatelessWidget {
  const DialogTextButton({this.onPressed, this.child});

  final VoidCallback onPressed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultButtonHeight,
      child: TextButton(
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
