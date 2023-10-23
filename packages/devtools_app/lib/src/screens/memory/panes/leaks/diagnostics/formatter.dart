// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:leak_tracker/devtools_integration.dart';

import 'model.dart';

const linkToGuidance = 'https://github.com/dart-lang/leak_tracker';

String analyzedLeaksToYaml({
  required List<LeakReport>? gcedLate,
  required List<LeakReport>? notDisposed,
  required NotGCedAnalyzed? notGCed,
}) {
  return '# For memory leaks troubleshooting tips see\n'
      '# $linkToGuidance\n\n'
      '${LeakReport.iterableToYaml('not-disposed', notDisposed, phasesAreTests: false)}'
      '${_notGCedToYaml(notGCed)}'
      '${LeakReport.iterableToYaml('gced-late', gcedLate, phasesAreTests: false)}';
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
      notGCed.leaksWithoutRetainingPath,
      phasesAreTests: false,
    ),
  );

  return result.toString();
}

String _culpritToYaml(
  LeakReport culprit,
  List<LeakReport> victims, {
  String indent = '',
}) {
  final culpritYaml = culprit.toYaml(indent, phasesAreTests: false);
  if (victims.isEmpty) return culpritYaml;

  return '$culpritYaml'
      '''$indent  total-victims: ${victims.length}
$indent  victims:
${victims.map((e) => e.toYaml('$indent    ', phasesAreTests: false)).join()}''';
}
