// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'theme.dart';

const _dialogDefaultContext = 'dialog';

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
    this.actions,
  });

  static const contentPadding = 24.0;

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Column(
        children: [
          title,
          const PaddedDivider(
            padding: EdgeInsets.only(bottom: denseRowSpacing),
          ),
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

/// A FlatButton used to close a containing dialog (Close).
class DialogCloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FlatButton(
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop('dialog');
      },
      child: const Text('CLOSE'),
    );
  }
}

/// A FlatButton used to close a containing dialog (Cancel).
class DialogCancelButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FlatButton(
      onPressed: () {
        Navigator.of(context).pop(_dialogDefaultContext);
      },
      child: const Text('CANCEL'),
    );
  }
}

/// A FlatButton used to close a containing dialog (APPLY).
class DialogApplyButton extends StatelessWidget {
  const DialogApplyButton({@required this.onPressed}) : super();

  final Function onPressed;

  @override
  Widget build(BuildContext context) {
    return FlatButton(
      onPressed: () {
        if (onPressed != null) onPressed();
        Navigator.of(context).pop(_dialogDefaultContext);
      },
      child: const Text('APPLY'),
    );
  }
}
