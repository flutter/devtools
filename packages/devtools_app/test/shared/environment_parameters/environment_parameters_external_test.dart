// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/src/shared/environment_parameters/environment_parameters_external.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newDevToolsGitHubIssueUriLengthSafe cuts details', () {
    const tail = 'tail';
    final additionalInfo =
        Iterable.generate(maxGitHubUriLength, (_) => 'v').join() + tail;
    final uri = newDevToolsGitHubIssueUriLengthSafe(
      additionalInfo: additionalInfo,
      environment: [],
    );
    expect(uri.toString().contains(tail), false);
    expect(uri.toString().length, maxGitHubUriLength);
  });

  test(
    'newDevToolsGitHubIssueUriLengthSafe includes title and additional info',
    () {
      final uri = newDevToolsGitHubIssueUriLengthSafe(
        issueTitle: 'Issue title',
        additionalInfo: 'Some additional info',
        environment: [],
      );
      expect(uri.toString(), contains('title=Issue+title'));
      expect(uri.toString(), contains('body=Some+additional+info'));
    },
  );
}
