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
  const _maxGitHubUriLength = 8190;

  final issueBody = [
    if (issueDetails != null) issueDetails,
    ...issueLinkDetails(),
  ].join('\n');

  final result = Uri.parse('https://$_newDevToolsIssueUriDisplay').replace(
    queryParameters: {
      'body': issueBody,
    },
  );

  if (result.toString().length <= _maxGitHubUriLength) return result;
  return Uri.parse(result.toString().substring(0, _maxGitHubUriLength - 1));
}
