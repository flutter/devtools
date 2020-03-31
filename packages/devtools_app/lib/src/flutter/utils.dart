// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
