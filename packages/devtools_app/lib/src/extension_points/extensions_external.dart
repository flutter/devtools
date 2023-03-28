// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../devtools.dart' as devtools;
import '../screens/debugger/codeview.dart';
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/diagnostics/inspector_service.dart';
import '../shared/globals.dart';
import '../shared/utils.dart';
import 'extensions_base.dart';

class ExternalDevToolsExtensionPoints implements DevToolsExtensionPoints {
  @override
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions() =>
      <ScriptPopupMenuOption>[];

  @override
  Link issueTrackerLink({String? issueDetails}) {
    return Link(
      display: _newDevToolsIssueUriDisplay,
      url: _newDevToolsGitHubIssueUri(issueDetails: issueDetails).toString(),
      gaScreenName: gac.devToolsMain,
      gaSelectedItemDescription: gac.feedbackLink,
    );
  }

  @override
  String? username() {
    // This should always return a null value for 3p users.
    return null;
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

  @override
  bool get defaultIsDarkTheme => true;
}

const _newDevToolsIssueUriDisplay = 'github.com/flutter/devtools/issues/new';

Uri _newDevToolsGitHubIssueUri({String? issueDetails}) {
  final issueBody = [
    if (issueDetails != null) issueDetails,
    ..._issueLinkDetails(),
  ].join('\n');

  return Uri.parse('https://github.com/flutter/devtools/issues/new').replace(
    queryParameters: {
      'body': issueBody,
    },
  );
}

List<String> _issueLinkDetails() {
  final issueDescriptionItems = [
    '<-- Please describe your problem here. Be sure to include repro steps. -->',
    '___', // This will create a separator in the rendered markdown.
    '**DevTools version**: ${devtools.version}',
  ];
  final vm = serviceManager.vm;
  final connectedApp = serviceManager.connectedApp;
  if (vm != null && connectedApp != null) {
    final descriptionEntries = generateDeviceDescription(
      vm,
      connectedApp,
      includeVmServiceConnection: false,
    );
    final deviceDescription = descriptionEntries
        .map((entry) => '${entry.title}: ${entry.description}');
    issueDescriptionItems.addAll([
      '**Connected Device**:',
      ...deviceDescription,
    ]);
  }
  return issueDescriptionItems;
}
