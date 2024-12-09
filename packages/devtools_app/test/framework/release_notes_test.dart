// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('$ReleaseNotesController', () {
    late ReleaseNotesController controller;
    setUp(() {
      setGlobal(IdeTheme, IdeTheme());
      debugTestReleaseNotes = true;
      controller = ReleaseNotesController();
    });

    test('latestVersionToCheckForReleaseNotes', () {
      var version = controller.latestVersionToCheckForReleaseNotes(
        SemanticVersion.parse('2.24.5-dev.1'),
      );
      expect(version.toString(), '2.23.10');

      version = controller.latestVersionToCheckForReleaseNotes(
        SemanticVersion.parse('2.24.1'),
      );
      expect(version.toString(), '2.24.1');
    });

    test('Fails gracefully when index is unavailable', () async {
      await http.runWithClient(
        () async {
          final response = await controller.retrieveReleasesFromIndex();
          expect(response, isNull);
        },
        () => MockClient((request) async {
          expect(request.method, equalsIgnoringCase('GET'));
          expect(request.url, equals(ReleaseNotesController.releaseIndexUrl));
          // Respond with a valid release index to test the http error handling,
          // not the parsing of the returned body.
          return http.Response(_validReleaseTestIndex, 404);
        }),
      );
    });

    test('Fails gracefully when index is formatted incorrectly', () async {
      await http.runWithClient(
        () async {
          final response = await controller.retrieveReleasesFromIndex();
          expect(response, isNull);
        },
        () => MockClient((request) async {
          expect(request.method, equalsIgnoringCase('GET'));
          expect(request.url, equals(ReleaseNotesController.releaseIndexUrl));
          return http.Response(_invalidReleaseTestIndex, 200);
        }),
      );
    });

    test('Parses expected index format correctly', () async {
      await http.runWithClient(
        () async {
          final releaseIndex = await controller.retrieveReleasesFromIndex();
          expect(
            releaseIndex,
            equals({
              '2.32.0':
                  '/tools/devtools/release-notes/release-notes-2.32.0-src.md',
              '2.31.0':
                  '/tools/devtools/release-notes/release-notes-2.31.0-src.md',
            }),
          );
        },
        () => MockClient((request) async {
          expect(request.method, equalsIgnoringCase('GET'));
          expect(request.url, equals(ReleaseNotesController.releaseIndexUrl));
          return http.Response(_validReleaseTestIndex, 200);
        }),
      );
    });
  });
}

/// An invalid release index due to the `releases` field being `release`.
const _invalidReleaseTestIndex = '''
{
  "latest": "2.32.0",
  "release": {
    "2.32.0": "/tools/devtools/release-notes/release-notes-2.32.0-src.md",
    "2.31.0": "/tools/devtools/release-notes/release-notes-2.31.0-src.md"
  }
}
''';

/// A correctly formatted release index file.
const _validReleaseTestIndex = '''
{
  "latest": "2.32.0",
  "releases": {
    "2.32.0": "/tools/devtools/release-notes/release-notes-2.32.0-src.md",
    "2.31.0": "/tools/devtools/release-notes/release-notes-2.31.0-src.md"
  }
}
''';
