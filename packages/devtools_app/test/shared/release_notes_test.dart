// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
