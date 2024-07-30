// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../globals.dart';
import '../../utils.dart';
import '_copy_to_clipboard_desktop.dart'
    if (dart.library.js_interop) '_copy_to_clipboard_web.dart';

final _log = Logger('copy_to_clipboard');

/// Attempts to copy a String of `data` to the clipboard.
///
/// Shows a `successMessage` [Notification] on the passed in `context`, if the
/// copy is successfully done using the [Clipboard.setData] api. Otherwise it
/// attempts to post the [data] to the parent frame where the parent frame will
/// try to complete the copy (this fallback will only work in VSCode).
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
    if (isEmbedded()) {
      _log.warning(
        'DevTools copy failed. This may be as a result of a known bug in VSCode. '
        'See https://github.com/Dart-Code/Dart-Code/issues/4540 for more '
        'information. DevTools will now attempt to use a fallback method of '
        'copying the contents.',
      );
      // Trying to use Clipboard.setData to copy in vscode will not work as a
      // result of a bug. So we should fallback to `copyToClipboardVSCode` which
      // delegates the copy to the frame above DevTools.
      // Sending this message in other environments will just have no effect.
      // See https://github.com/Dart-Code/Dart-Code/issues/4540 for more
      // information.
      copyToClipboardVSCode(data);
    } else {
      rethrow;
    }
  }
}
