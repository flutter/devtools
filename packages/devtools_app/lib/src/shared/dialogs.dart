// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import 'globals.dart';
import 'utils.dart';

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
              () =>
                          notificationService.push('Error details copied to clipboard'),
            ),
          ),
        ),
        DialogTextButton(
          child: const Text('Create issue'),
          onPressed: () => unawaited(
            launchUrlWithErrorHandling(
              devToolsEnvironmentParameters
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
