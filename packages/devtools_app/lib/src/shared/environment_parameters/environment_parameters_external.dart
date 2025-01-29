// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../screens/debugger/codeview.dart';
import '../analytics/constants.dart' as gac;
import '../diagnostics/inspector_service.dart';
import '../globals.dart';
import '../ui/common_widgets.dart';
import '../utils/utils.dart';
import 'environment_parameters_base.dart';

class ExternalDevToolsEnvironmentParameters
    implements DevToolsEnvironmentParameters {
  @override
  List<ScriptPopupMenuOption> buildExtraDebuggerScriptPopupMenuOptions() =>
      <ScriptPopupMenuOption>[];

  @override
  GaLink issueTrackerLink({String? additionalInfo, String? issueTitle}) {
    return GaLink(
      display: _newDevToolsIssueUriDisplay,
      url:
          newDevToolsGitHubIssueUriLengthSafe(
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
  GaLink? enableSourceMapsLink() {
    // This should always return a null value for 3p users.
    return null;
  }

  @override
  String loadingAppSizeDataMessage() {
    return 'Loading app size data. Please wait...';
  }

  @override
  InspectorServiceBase? inspectorServiceProvider() =>
      serviceConnection.serviceManager.connectedApp!.isFlutterAppNow == true
          ? InspectorService()
          : null;

  @override
  String get perfettoIndexLocation =>
      'packages/perfetto_ui_compiled/dist/index.html';

  @override
  String? chrome115BreakpointBug() {
    // This should always return a null value for 3p users.
    return null;
  }

  @override
  List<TextSpan>? recommendedDebuggers(
    BuildContext context, {
    required bool isFlutterApp,
  }) {
    return [
      GaLinkTextSpan(
        context: context,
        link: const GaLink(
          display: 'VS Code',
          url: 'https://dart.dev/tools/vs-code',
        ),
      ),
      const TextSpan(text: ' or '),
      GaLinkTextSpan(
        context: context,
        link: const GaLink(
          display: 'IntelliJ & Android Studio',
          url: 'https://dart.dev/tools/jetbrains-plugin',
        ),
      ),
    ];
  }
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
  final truncatedInfo = additionalInfo.substring(
    0,
    additionalInfo.length - lengthToCut,
  );

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

  return Uri.parse(
    'https://$_newDevToolsIssueUriDisplay',
  ).replace(queryParameters: {'title': issueTitle, 'body': issueBody});
}
