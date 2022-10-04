// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../shared/globals.dart';
import '_launch_url_stub.dart'
    if (dart.library.html) '_launch_url_web.dart'
    if (dart.library.io) '_launch_url_desktop.dart';

Future<void> launchUrl(String url, BuildContext context) async {
  final parsedUrl = Uri.tryParse(url);

  if (parsedUrl != null && await url_launcher.canLaunchUrl(parsedUrl)) {
    await url_launcher.launchUrl(parsedUrl);
  } else {
    notificationService.push('Unable to open $url.');
  }

  // When embedded in VSCode, url_launcher will silently fail, so we send a
  // command to DartCode to launch the URL. This will do nothing when not
  // embedded in VSCode.
  launchUrlVSCode(url);
}
