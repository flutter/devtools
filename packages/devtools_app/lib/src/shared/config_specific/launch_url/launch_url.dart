// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../globals.dart';
import '_launch_url_stub.dart'
    if (dart.library.html) '_launch_url_web.dart'
    if (dart.library.io) '_launch_url_desktop.dart';

Future<void> launchUrl(String url) async {
  final parsedUrl = Uri.tryParse(url);

  try {
    if (parsedUrl != null && await url_launcher.canLaunchUrl(parsedUrl)) {
      await url_launcher.launchUrl(parsedUrl);
    } else {
      notificationService.push('Unable to open $url.');
    }
  } finally {
    // Always pass the request up to VS Code because we could fail both silently
    // (the usual behaviour) or with another error like
    // "Attempted to call Window.open with a null window"
    // https://github.com/flutter/devtools/issues/6105.
    //
    // In the case where we are not in VS Code, there will be nobody listening
    // to the postMessage this sends.
    launchUrlVSCode(url);
  }
}
