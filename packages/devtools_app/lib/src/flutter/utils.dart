// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansi_up/ansi_up.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../utils.dart';
import 'notifications.dart';

Future<void> launchUrl(String url, BuildContext context) async {
  if (await url_launcher.canLaunch(url)) {
    await url_launcher.launch(url);
  } else {
    Notifications.of(context).push('Unable to open $url.');
  }
}

/// Attempts to copy a bunch of `lines` to the clipboard.
Future<void> copyToClipboard(List<String> lines, BuildContext context) async {
  await Clipboard.setData(ClipboardData(
    text: lines.join('\n'),
  ));

  final numLines = lines.length;
  Notifications.of(context)?.push(
    'Copied $numLines ${pluralize('line', numLines)}.',
  );
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
