// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansi_up/ansi_up.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import 'notifications.dart';

Future<void> launchUrl(String url, BuildContext context) async {
  if (await url_launcher.canLaunch(url)) {
    await url_launcher.launch(url);
  } else {
    Notifications.of(context).push('Unable to open $url.');
  }
}

/// Attempts to copy a String of `data` to the clipboard.
///
/// Shows a `successMessage` [Notification] on the passed in `context`.
Future<void> copyToClipboard(
  String data,
  String successMessage,
  BuildContext context,
) async {
  await Clipboard.setData(ClipboardData(
    text: data,
  ));

  if (successMessage != null) {
    Notifications.of(context)?.push(successMessage);
  }
}

List<TextSpan> processAnsiTerminalCodes(String input, TextStyle defaultStyle) {
  if (input == null) {
    return [];
  }
  return decodeAnsiColorEscapeCodes(input, AnsiUp())
      .map(
        (entry) => TextSpan(
          text: entry.text,
          style: entry.style.isEmpty
              ? defaultStyle
              : TextStyle(
                  color: entry.fgColor != null
                      ? colorFromAnsi(entry.fgColor)
                      : null,
                  backgroundColor: entry.bgColor != null
                      ? colorFromAnsi(entry.bgColor)
                      : null,
                  fontWeight: entry.bold ? FontWeight.bold : FontWeight.normal,
                ),
        ),
      )
      .toList();
}

Color colorFromAnsi(List<int> ansiInput) {
  assert(ansiInput.length == 3, 'Ansi color list should contain 3 elements');
  return Color.fromRGBO(ansiInput[0], ansiInput[1], ansiInput[2], 1);
}

/// An extension on [LogicalKeySet] to provide user-facing names for key
/// bindings.
extension LogicalKeySetExtension on LogicalKeySet {
  static final Set<LogicalKeyboardKey> _modifiers = {
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.shift,
  };

  static final Map<LogicalKeyboardKey, String> _modifierNames = {
    LogicalKeyboardKey.alt: 'Alt',
    LogicalKeyboardKey.control: 'Control',
    LogicalKeyboardKey.meta: 'Meta',
    LogicalKeyboardKey.shift: 'Shift',
  };

  /// Return a user-facing name for the [LogicalKeySet].
  String describeKeys({bool isMacOS = false}) {
    // Put the modifiers first. If it has a synonym, then it's something like
    // shiftLeft, altRight, etc.
    final List<LogicalKeyboardKey> sortedKeys = keys.toList()
      ..sort((a, b) {
        final aIsModifier = a.synonyms.isNotEmpty || _modifiers.contains(a);
        final bIsModifier = b.synonyms.isNotEmpty || _modifiers.contains(b);
        if (aIsModifier && !bIsModifier) {
          return -1;
        } else if (bIsModifier && !aIsModifier) {
          return 1;
        }
        return a.keyLabel.compareTo(b.keyLabel);
      });

    return sortedKeys.map((key) {
      if (_modifiers.contains(key)) {
        if (isMacOS && key == LogicalKeyboardKey.meta) {
          return '⌘';
        }
        return '${_modifierNames[key]}-';
      } else {
        return key.keyLabel.toUpperCase();
      }
    }).join();
  }
}
