import 'package:flutter/material.dart';
import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../shared/eval_on_dart_library.dart';
import '../../../../shared/globals.dart';

final eval = EvalOnDartLibrary(
  'package:memory_tools/app_leak_detector.dart',
  serviceManager.service!,
);

String analyzeAndYaml(Leaks leaks) {
  return '${ObjectReport.iterableToYaml('not-disposed', leaks.leaks[LeakType.notDisposed]!)}'
      '${_notGCedToYaml(leaks.leaks[LeakType.notGCed]!)}'
      '${ObjectReport.iterableToYaml('gced-late', leaks.leaks[LeakType.gcedLate]!)}';
}

String _notGCedToYaml(Iterable<ObjectReport> notGCed) {
  final withPath = notGCed.where((r) => r.retainingPath != null);
  final withoutPath = notGCed.where((r) => r.retainers != null);
  assert(
    notGCed.length == withPath.length + withoutPath.length,
    '${notGCed.length} should be ${withPath.length} + ${withoutPath.length}',
  );
  return '${_notGCedWithPathToYaml(withPath)}'
      '${ObjectReport.iterableToYaml('not-gced-without-path', withoutPath)}';
}

String _notGCedWithPathToYaml(Iterable<ObjectReport> notGCed) {
  if (notGCed.isEmpty) return '';
  final byCulprits = findCulprits(notGCed);

  final header = '''not-gced:
  total: ${byCulprits.length}
  objects:
''';

  return header +
      byCulprits.keys
          .map((culprit) => _culpritToYaml(
                culprit,
                byCulprits[culprit]!,
                indent: '    ',
              ))
          .join();
}

String _culpritToYaml(
  ObjectReport culprit,
  List<ObjectReport> victims, {
  String indent = '',
}) {
  final culpritYaml = culprit.toYaml(indent);
  if (victims.isEmpty) return culpritYaml;

  return '''$culpritYaml
$indent  total-victims: ${victims.length}
$indent  victims:
${victims.map((e) => e.toYaml('$indent    ')).join()}''';
}

@visibleForTesting
Map<ObjectReport, List<ObjectReport>> findCulprits(
    Iterable<ObjectReport> notGCed) {
  final byPath = Map<String, ObjectReport>.fromIterable(
    notGCed,
    key: (r) => r.retainingPath,
    value: (r) => r,
  );

  final result = <ObjectReport, List<ObjectReport>>{};
  String previousPath = '--- not existing path ---';
  late ObjectReport previousReport;
  for (var path in byPath.keys.toList()..sort()) {
    final report = byPath[path]!;
    final isVictim = path.startsWith(previousPath);

    if (isVictim) {
      result[previousReport]!.add(report);
    } else {
      previousPath = path;
      previousReport = report;
      result[report] = [];
    }
  }
  return result;
}
