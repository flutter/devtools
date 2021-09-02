// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'utils.dart';

/// The type of data provider function used by the CopyToClipboard Control.
typedef ClipboardDataProvider = String Function();

/// A Call Stack Control that copies `data` to the clipboard.
///
/// If it succeeds, it displays a notification with `successMessage`.
class CopyToClipboardControl extends StatelessWidget {
  const CopyToClipboardControl({
    this.dataProvider,
    this.successMessage = 'Copied to clipboard.',
    this.tooltip = 'Copy to clipboard',
    this.buttonKey,
  });

  final ClipboardDataProvider dataProvider;
  final String successMessage;
  final String tooltip;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final disabled = dataProvider == null;
    return ToolbarAction(
      icon: Icons.content_copy,
      tooltip: tooltip,
      onPressed: disabled
          ? null
          : () => copyToClipboard(dataProvider(), successMessage, context),
      key: buttonKey,
    );
  }
}
