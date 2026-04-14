// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'package:dart_skills_lint/dart_skills_lint.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  test('Validate DevTools Skills', () async {
    final Level oldLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final StreamSubscription<LogRecord> subscription = Logger.root.onRecord.listen((record) {
      print(record.message);
    });

    try {
      // Update test to use dart_skills_lint.yaml for config when available.
      // See https://github.com/flutter/skills/issues/85.
      final bool isValid = await validateSkills(
        skillDirPaths: ['../.agents/skills'],
        resolvedRules: {
          'check-relative-paths': AnalysisSeverity.error,
          'check-absolute-paths': AnalysisSeverity.error,
          'check-trailing-whitespace': AnalysisSeverity.error,
        },
      );
      expect(isValid, isTrue, reason: 'Skills validation failed. See above for details.');
    } finally {
      Logger.root.level = oldLevel;
      await subscription.cancel();
    }
  });
}
