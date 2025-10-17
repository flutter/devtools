// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_app_shared/web_utils.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' hide Storage;

import '../../primitives/storage.dart';
import '../../server/server.dart' as server;
import '../../server/server_api_client.dart';

final _log = Logger('framework_initialize');

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

  // Check if the server API is available.
  if (await server.checkServerHttpApiAvailable()) {
    _log.info('Server HTTP API is available, using server for storage.');
    setGlobal(Storage, server.ServerConnectionStorage());

    // And also connect the legacy SSE API if necessary
    // (`DevToolsServerConnection.connect`) may short-circuit in some cases,
    // such as when embedded.

    // TODO(kenz): this server connection initialized listeners that are never
    //  disposed, so this is likely leaking resources.
    // Here, we try and initialize the connection between the DevTools web app and
    // its local server. DevTools can be launched without the server however, so
    // establishing this connection is a best-effort.
    // TODO(kenz): investigate if we can remove the DevToolsServerConnection
    //  code in general - it is currently only used for non-embedded pages to
    //  support some functionality like having VS Code reuse existing browser tabs
    //  and showing notifications if you try to launch when you already have one
    //  open.
    await DevToolsServerConnection.connect();
  } else {
    _log.info('Server HTTP API is not available, using browser for storage.');
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

  // This handling is only required for when embedded in VS Code and forks that
  // also use Dart-Code.
  if (!window.navigator.userAgent.contains('Electron')) {
    return;
  }

  // Because VS Code prevents built-in behaviour for copy/paste/etc. from
  // working (on macOS), we have to handle those specially (and do not need to
  // send them upwards).
  // https://github.com/microsoft/vscode/issues/129178
  // https://github.com/microsoft/vscode/issues/129178#issuecomment-3410886795
  if (_handleStandardShortcuts(event)) return;

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

bool _handleStandardShortcuts(KeyboardEvent event) {
  const keyInsert = 45;
  const keyA = 65;
  const keyC = 67;
  const keyV = 86;
  const keyX = 88;
  const keyZ = 90;

  final hasMeta = event.ctrlKey || event.metaKey;
  final hasShift = event.shiftKey;
  final code = event.keyCode;

  // Determine which command (if any) we should execute.
  final command = switch (code) {
    keyA when hasMeta => 'selectAll',
    keyC when hasMeta => 'copy',
    keyV when hasMeta => 'paste',
    keyInsert when hasShift => 'paste',
    keyX when hasMeta => 'cut',
    keyZ when hasMeta => 'undo',
    _ => null,
  };

  // No command, just fall back to normal handling.
  if (command == null) {
    return false;
  }

  // Otherwise, try to invoke the command and prevent the browser.
  try {
    document.execCommand(command);
    event.preventDefault();
    return true;
  } catch (_) {
    // If we failed, then also fall back to normal handling.
    return false;
  }
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
