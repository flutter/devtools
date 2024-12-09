// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/server/server_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computes the correct api URI', () {
    const apiUriFor = DevToolsServerConnection.apiUriFor;
    test('for a root URI without trailing slash', () {
      expect(
        apiUriFor(Uri.parse('https://localhost:123?uri=x')),
        Uri.parse('https://localhost:123/api/'),
      );
    });

    test('for a root URI with trailing slash', () {
      expect(
        apiUriFor(Uri.parse('https://localhost:123/?uri=x')),
        Uri.parse('https://localhost:123/api/'),
      );
    });

    test('for a /devtools/ URI with trailing slash', () {
      expect(
        apiUriFor(Uri.parse('https://localhost:123/devtools/?uri=x')),
        Uri.parse('https://localhost:123/devtools/api/'),
      );
    });

    test('for a /devtools URI without trailing slash', () {
      expect(
        apiUriFor(Uri.parse('https://localhost:123/devtools?uri=x')),
        Uri.parse('https://localhost:123/devtools/api/'),
      );
    });

    test('for a /devtools/inspector URI', () {
      expect(
        apiUriFor(Uri.parse('https://localhost:123/devtools/inspector?uri=x')),
        Uri.parse('https://localhost:123/devtools/api/'),
      );
    });
  });
}
