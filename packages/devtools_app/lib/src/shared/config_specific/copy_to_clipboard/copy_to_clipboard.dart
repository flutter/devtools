// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../globals.dart';
import '_copy_to_clipboard_stub.dart'
    if (dart.library.js_interop) '_copy_to_clipboard_web.dart'
    if (dart.library.io) '_copy_to_clipboard_desktop.dart';

final _log = Logger('copy_to_clipboard');

/// Attempts to copy a String of `data` to the clipboard.
///
/// Shows a `successMessage` [Notification] on the passed in `context`.
Future<void> copyToClipboard(
  String data,
  String? successMessage,
) async {
  try {
    await Clipboard.setData(
      ClipboardData(
        text: data,
      ),
    );

    if (successMessage != null) notificationService.push(successMessage);
  } catch (e) {
    _log.warning(
      'DevTools copy failed. This may be as a result of a known bug in VSCode. '
      'See https://github.com/Dart-Code/Dart-Code/issues/4540 for more '
      'information. DevTools will now attempt to use a fallback method of '
      'copying the contents.',
    );
    // Trying to use Clipboard.setData to copy in vscode will not work as a
    // result of a bug. So we should fallback to `copyToClipboardVSCode` which
    // delegates the copy to the frame above DevTools.
    // See https://github.com/Dart-Code/Dart-Code/issues/4540 for more
    // information.
    copyToClipboardVSCode(data);
  }
}
