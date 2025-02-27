// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_app_shared/web_utils.dart';
import 'package:web/web.dart' hide Storage;

import '../../../service/service_manager.dart';
import '../../globals.dart';
import '../../primitives/storage.dart';
import '../../server/server.dart' as server;
import '../../server/server_api_client.dart';

/// Return the url the application is launched from.
Future<String> initializePlatform() async {
  // Clear out the unneeded HTML from index.html.
  document.body!
      .querySelectorAll('.legacy-dart')
      .forEach(
        (Node element) {
          if (element.parentNode != null) {
            element.parentNode!.removeChild(element);
          }
        }.toJS,
      );

  // TODO(kenz): this server connection initialized listeners that are never
  // disposed, so this is likely leaking resources.
  // Here, we try and initialize the connection between the DevTools web app and
  // its local server. DevTools can be launched without the server however, so
  // establishing this connection is a best-effort.
  // TODO(kenz): investigate it we can remove the DevToolsServerConnection
  // code in general. We do not appear to be using the SSE connection.
  final connection = await DevToolsServerConnection.connect();
  if (connection != null) {
    setGlobal(Storage, server.ServerConnectionStorage());
  } else {
    setGlobal(Storage, BrowserStorage());
  }

  // Prevent the browser default behavior for specific keybindings we'll later
  // handle in the app. This is a workaround for
  // https://github.com/flutter/flutter/issues/58119.
  window.onKeyDown.listen((event) {
    _sendKeyPressToParent(event);

    // Here, we're just trying to match the '⌘P' keybinding on macos.
    if (!event.metaKey) {
      return;
    }
    if (!window.navigator.userAgent.contains('Macintosh')) {
      return;
    }

    if (event.key == 'p') {
      event.preventDefault();
    }
  });

  return '${window.location}';
}

void _sendKeyPressToParent(KeyboardEvent event) {
  // When DevTools is embedded inside IDEs in iframes, it will capture all
  // keypresses, preventing IDE shortcuts from working. To fix this, keypresses
  // will need to be posted up to the parent
  // https://github.com/flutter/devtools/issues/2775

  // Check we have a connection and we appear to be embedded somewhere expected
  // because we can't use targetOrigin in postMessage as only the scheme is fixed
  // for VS Code (vscode-webview://[some guid]).
  if (globals.containsKey(ServiceConnectionManager) &&
      !serviceConnection.serviceManager.connectedState.value.connected) {
    return;
  }
  if (!window.navigator.userAgent.contains('Electron')) return;

  final data = {
    'altKey': event.altKey,
    'code': event.code,
    'ctrlKey': event.ctrlKey,
    'isComposing': event.isComposing,
    'key': event.key,
    'location': event.location,
    'metaKey': event.metaKey,
    'repeat': event.repeat,
    'shiftKey': event.shiftKey,
  };
  window.parent?.postMessage(
    {'command': 'keydown', 'data': data}.jsify(),
    '*'.toJS,
  );
}

class BrowserStorage implements Storage {
  @override
  Future<String?> getValue(String key) async {
    return window.localStorage.getItem(key);
  }

  @override
  Future<void> setValue(String key, String value) async {
    window.localStorage.setItem(key, value);
  }
}
