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
  return '${ObjectReport.iterableToYaml('notDisposed', leaks.leaks[LeakType.notDisposed]!)}'
      '${_notGCedToYaml(leaks.leaks[LeakType.notGCed]!)}'
      '${ObjectReport.iterableToYaml('gcedLate', leaks.leaks[LeakType.gcedLate]!)}';
}

String _notGCedToYaml(List<ObjectReport> notGCed) {
  if (notGCed.isEmpty) return '';
  final byCulprits = findCulprits(notGCed);

  final header = '''notGCed:
  total: ${byCulprits.length}
  objects:
''';

  return header +
      byCulprits.keys
          .map((culprit) => culpritToYaml(
                culprit,
                byCulprits[culprit]!,
                indent: '  ',
              ))
          .join();
}

String culpritToYaml(
  ObjectReport culprit,
  List<ObjectReport> victims, {
  String indent = '',
}) {
  final culpritYaml = culprit.toYaml(indent);
  if (victims.isEmpty) return culpritYaml;

  return '''$culpritYaml
$indent  total-victims: ${victims.length}
$indent  victims:
${victims.map((e) => e.toYaml('$indent    ')).join()}
''';
}

@visibleForTesting
Map<ObjectReport, List<ObjectReport>> findCulprits(List<ObjectReport> notGCed) {
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

// String pathToString(RetainingPath path) {
//   final result = StringBuffer();
//   final elements = path.elements ?? <RetainingObject>[];
//   for (var i = elements.length - 1; i >= 0; i--) {
//     final element = elements[i];
//     result.write('/');
//     result.write(identityHashCode(elements[i].value));
//   }
//   // We need this last slash to avoid parent-child detection for paths where
//   // codes happened to be prefix for one another (like 'ab' and 'abc').
//   result.write('/');
//   return '${result.toString()}\n${path.toString()}';
// }

// Future<void> setRetainingPath(ObjectReport info) async {
//   final objectRef = await eval
//       .safeEval('getNotGCedObject(${info.theIdentityHashCode})', isAlive: null);
//
//   const pathLimit = 1000;
//   final path = await serviceManager.service!.getRetainingPath(
//     eval.isolate!.id!,
//     objectRef.id!,
//     1000,
//   );
//
//   assert((path.elements?.length ?? 0) <= pathLimit - 1);
//
//   info.retainingPath = pathToString(path);
//   info.gcRootType = path.gcRootType;
// }
