// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.



import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../shared/notifications.dart';
import '_launch_url_stub.dart'
    if (dart.library.html) '_launch_url_web.dart'
    if (dart.library.io) '_launch_url_desktop.dart';

Future<void> launchUrl(String url, BuildContext context) async {
  if (await url_launcher.canLaunch(url)) {
    await url_launcher.launch(url);
  } else {
    Notifications.of(context)!.push('Unable to open $url.');
  }

  // When embedded in VSCode, url_launcher will silently fail, so we send a
  // command to DartCode to launch the URL. This will do nothing when not
  // embedded in VSCode.
  launchUrlVSCode(url);
}
