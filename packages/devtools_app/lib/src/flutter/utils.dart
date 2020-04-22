// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:ansi_up/ansi_up.dart';

import 'notifications.dart';

Future<void> launchUrl(String url, BuildContext context) async {
  if (await url_launcher.canLaunch(url)) {
    await url_launcher.launch(url);
  } else {
    Notifications.of(context).push('Unable to open $url.');
  }
}

List<TextSpan> maybeConvertToAnsiText(String input, TextStyle defaultStyle) {
  return decodeAnsiColorEscapeCodes(input, AnsiUp())
      .map((entry) => TextSpan(
            text: entry.text,
            style: entry.style.isEmpty
                ? defaultStyle
                : TextStyle(
                    color: entry.fgColor != null && entry.fgColor.length > 2
                        ? Color.fromRGBO(
                            entry.fgColor[0],
                            entry.fgColor[1],
                            entry.fgColor[2],
                            1,
                          )
                        : null,
                    backgroundColor:
                        entry.bgColor != null && entry.bgColor.length > 2
                            ? Color.fromRGBO(
                                entry.bgColor[0],
                                entry.bgColor[1],
                                entry.bgColor[2],
                                1,
                              )
                            : null,
                    fontWeight:
                        entry.bold ? FontWeight.bold : FontWeight.normal,
                  ),
          ))
      .toList();
}
