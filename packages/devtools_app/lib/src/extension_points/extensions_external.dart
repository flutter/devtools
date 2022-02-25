// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import '../debugger/codeview.dart';
import '../screens/inspector/inspector_service.dart';
import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import 'extensions_base.dart';

class ExternalDevToolsExtensionPoints implements DevToolsExtensionPoints {
  @override
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions() =>
      <ScriptPopupMenuOption>[];

  @override
  Link issueTrackerLink() {
    const githubLink = 'github.com/flutter/devtools/issues/new';
    return const Link(display: githubLink, url: 'https://$githubLink');
  }

  @override
  String loadingAppSizeDataMessage() {
    return 'Loading app size data. Please wait...';
  }

  @override
  InspectorServiceBase inspectorServiceProvider() =>
      serviceManager.connectedApp.isFlutterAppNow ? InspectorService() : null;
}
