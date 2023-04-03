// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/extension_points/extensions_external.dart';
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
}
