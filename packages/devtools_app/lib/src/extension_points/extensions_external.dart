// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

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
  Link issueTrackerLink({String? additionalInfo, String? issueTitle}) {
    return Link(
      display: _newDevToolsIssueUriDisplay,
      url: newDevToolsGitHubIssueUriLengthSafe(
        additionalInfo: additionalInfo,
        issueTitle: issueTitle,
        environment: issueLinkDetails(),
      ).toString(),
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
  String? sourceMapsWarning() {
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
  String get perfettoIndexLocation =>
      'packages/perfetto_ui_compiled/dist/index.html';
}

const _newDevToolsIssueUriDisplay = 'github.com/flutter/devtools/issues/new';

@visibleForTesting
const maxGitHubUriLength = 8190;

@visibleForTesting
Uri newDevToolsGitHubIssueUriLengthSafe({
  required List<String> environment,
  String? additionalInfo,
  String? issueTitle,
}) {
  final fullUri = _newDevToolsGitHubIssueUri(
    additionalInfo: additionalInfo,
    issueTitle: issueTitle,
    environment: environment,
  );

  final lengthToCut = fullUri.toString().length - maxGitHubUriLength;
  if (lengthToCut <= 0) return fullUri;

  if (additionalInfo == null) {
    return Uri.parse(fullUri.toString().substring(0, maxGitHubUriLength));
  }

  // Truncate the additional info if the URL is too long:
  final truncatedInfo =
      additionalInfo.substring(0, additionalInfo.length - lengthToCut);

  final truncatedUri = _newDevToolsGitHubIssueUri(
    additionalInfo: truncatedInfo,
    issueTitle: issueTitle,
    environment: environment,
  );
  assert(truncatedUri.toString().length <= maxGitHubUriLength);
  return truncatedUri;
}

Uri _newDevToolsGitHubIssueUri({
  required List<String> environment,
  String? additionalInfo,
  String? issueTitle,
}) {
  final issueBody = [
    if (additionalInfo != null) additionalInfo,
    ...environment,
  ].join('\n');

  return Uri.parse('https://$_newDevToolsIssueUriDisplay').replace(
    queryParameters: {
      'title': issueTitle,
      'body': issueBody,
    },
  );
}
