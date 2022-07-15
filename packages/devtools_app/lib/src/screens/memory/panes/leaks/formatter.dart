// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';

import 'diagnostics/model.dart';
import 'instrumentation/model.dart';

const linkToGuidance =
    'https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/screens/memory/panes/leaks/LEAK_TRACKING.md';

String analyzedLeaksToYaml({
  required List<LeakReport>? gcedLate,
  required List<LeakReport>? notDisposed,
  required NotGCedAnalyzed? notGCed,
}) {
  return '# For memory leaks troubleshooting tips see\n'
      '# $linkToGuidance\n\n'
      '${LeakReport.iterableToYaml('not-disposed', notDisposed as List<LeakReport>?)}'
      '${_notGCedToYaml(notGCed)}'
      '${LeakReport.iterableToYaml('gced-late', gcedLate as List<LeakReport>?)}';
}

String _notGCedToYaml(NotGCedAnalyzed? notGCed) {
  if (notGCed == null) return '';
  final result = StringBuffer();

  if (notGCed.leaksByCulprits.isNotEmpty) {
    result.write('''not-gced:
  total: ${notGCed.totalLeaks - notGCed.leaksWithoutRetainingPath.length}
  culprits: ${notGCed.leaksByCulprits.length}
  victims: ${notGCed.totalLeaks - notGCed.leaksWithoutRetainingPath.length - notGCed.leaksByCulprits.length}
  objects:
''');
    result.write(
      notGCed.leaksByCulprits.keys
          // We want more victims at the top.
          .sorted(
            (a, b) => notGCed.leaksByCulprits[b]!.length
                .compareTo(notGCed.leaksByCulprits[a]!.length),
          )
          .map(
            (culprit) => _culpritToYaml(
              culprit,
              notGCed.leaksByCulprits[culprit]!,
              indent: '    ',
            ),
          )
          .join(),
    );
  }

  result.write(
    LeakReport.iterableToYaml(
      'not-gced-without-path',
      notGCed.leaksWithoutRetainingPath as List<LeakReport>?,
    ),
  );

  return result.toString();
}

String _culpritToYaml(
  LeakReport culprit,
  List<LeakReport> victims, {
  String indent = '',
}) {
  final culpritYaml = culprit.toYaml(indent);
  if (victims.isEmpty) return culpritYaml;

  return '$culpritYaml'
      '''$indent  total-victims: ${victims.length}
$indent  victims:
${victims.map((e) => e.toYaml('$indent    ')).join()}''';
}
