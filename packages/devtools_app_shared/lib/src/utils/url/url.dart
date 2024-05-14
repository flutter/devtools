// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '_launch_url_vs_code_stub.dart'
    if (dart.library.js_interop) '_launch_url_vs_code_web.dart';

export '_url_stub.dart' if (dart.library.js_interop) '_url_web.dart';

/// Launches [url] in the browser.
///
/// This method has special handling for launching URLs when in an embedded
/// VS Code view.
///
/// An optional callback [onError] will be called if [url] cannot be launched.
Future<void> launchUrl(String url, {void Function()? onError}) async {
  final parsedUrl = Uri.tryParse(url);

  try {
    if (parsedUrl != null && await url_launcher.canLaunchUrl(parsedUrl)) {
      await url_launcher.launchUrl(parsedUrl);
    } else {
      onError?.call();
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
