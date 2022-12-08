// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../screens/debugger/codeview.dart';
import '../screens/inspector/inspector_service.dart';
import '../shared/analytics/constants.dart' as gac;
import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import '../shared/utils.dart';
import 'extensions_base.dart';

class ExternalDevToolsExtensionPoints implements DevToolsExtensionPoints {
  @override
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions() =>
      <ScriptPopupMenuOption>[];

  @override
  Link issueTrackerLink() {
    final issueBodyItems = issueLinkDetails();
    final issueBody = issueBodyItems.join('\n');
    const githubLinkDisplay = 'github.com/flutter/devtools/issues/new';
    final githubUri = Uri.parse('https://$githubLinkDisplay').replace(
      queryParameters: {
        'body': issueBody,
      },
    );
    return Link(
      display: githubLinkDisplay,
      url: githubUri.toString(),
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
}
