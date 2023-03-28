// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../devtools.dart' as devtools;
import 'globals.dart';
import 'utils.dart';

const newDevToolsIssueUriDisplay = 'github.com/flutter/devtools/issues/new';

Uri newDevToolsIssueUri({String? issueDetails}) {
  final issueBodyItems = issueLinkDetails();
  if (issueDetails != null) issueBodyItems.insert(0, issueDetails);
  final issueBody = issueBodyItems.join('\n');

  return Uri.parse('https://$newDevToolsIssueUriDisplay').replace(
    queryParameters: {
      'body': issueBody,
    },
  );
}

List<String> issueLinkDetails() {
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
