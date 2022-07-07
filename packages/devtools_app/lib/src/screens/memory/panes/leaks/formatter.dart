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
      '${LeakReport.iterableToYaml('not-disposed', notDisposed)}'
      '${_notGCedToYaml(notGCed)}'
      '${LeakReport.iterableToYaml('gced-late', gcedLate)}';
}

String _notGCedToYaml(NotGCedAnalyzed? notGCed) {
  if (notGCed == null) return '';
  final result = StringBuffer();

  if (notGCed.byCulprits.isNotEmpty) {
    result.write('''not-gced:
  total: ${notGCed.total - notGCed.withoutPath.length}
  culprits: ${notGCed.byCulprits.length}
  victims: ${notGCed.total - notGCed.withoutPath.length - notGCed.byCulprits.length}
  objects:
''');
    result.write(
      notGCed.byCulprits.keys
          // We want more victims at the top.
          .sorted(
            (a, b) => notGCed.byCulprits[b]!.length
                .compareTo(notGCed.byCulprits[a]!.length),
          )
          .map(
            (culprit) => _culpritToYaml(
              culprit,
              notGCed.byCulprits[culprit]!,
              indent: '    ',
            ),
          )
          .join(),
    );
  }

  result.write(
    LeakReport.iterableToYaml('not-gced-without-path', notGCed.withoutPath),
  );

  return result.toString();
}

String _culpritToYaml(
  LeakReport culprit,
  List<LeakReport> victims, {
  String indent = '',
}) {
  final culpritYaml = culprit.toYaml(indent, includeDisposalStack: true);
  if (victims.isEmpty) return culpritYaml;

  return '$culpritYaml'
      '''$indent  total-victims: ${victims.length}
$indent  victims:
${victims.map((e) => e.toYaml('$indent    ')).join()}''';
}
