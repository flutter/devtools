// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../devtools.dart' as devtools;
import '../screens/debugger/codeview.dart';
import '../screens/inspector/inspector_service.dart';
import '../shared/common_widgets.dart';
import '../shared/device_dialog.dart';
import '../shared/globals.dart';
import 'extensions_base.dart';

class ExternalDevToolsExtensionPoints implements DevToolsExtensionPoints {
  @override
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions() =>
      <ScriptPopupMenuOption>[];

  @override
  Link issueTrackerLink() {
    final issueBodyItems = [
      '<--Please describe your problem here-->',
      '___', // This will create a separator in the rendered markdown.
      '**DevTools version**: ${devtools.version}',
    ];
    final vm = serviceManager.vm;
    final connectedApp = serviceManager.connectedApp;
    if (vm != null && connectedApp != null) {
      final Map<String, String> deviceDescriptionMap =
          generateDeviceDescription(
        vm,
        connectedApp,
        includeVmServiceConnection: false,
      );
      final deviceDescription = deviceDescriptionMap.keys
          .map((key) => '$key: ${deviceDescriptionMap[key]}');
      issueBodyItems.addAll([
        '**Connected Device**:',
        ...deviceDescription,
      ]);
    }
    final issueBody = issueBodyItems.join('\n');

    const githubLinkDisplay = 'github.com/flutter/devtools/issues/new';
    final githubUri = Uri.parse('https://$githubLinkDisplay').replace(
      queryParameters: {
        'body': issueBody,
      },
    );
    return Link(display: githubLinkDisplay, url: githubUri.toString());
  }

  @override
  String loadingAppSizeDataMessage() {
    return 'Loading app size data. Please wait...';
  }

  @override
  InspectorServiceBase? inspectorServiceProvider() =>
      serviceManager.connectedApp!.isFlutterAppNow == true
          ? InspectorService()
          : null;
}
