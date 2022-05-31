import 'package:flutter/material.dart';
import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

String analyzeAndYaml(Leaks leaks) {
  return '${ObjectReport.iterableToYaml('notDisposed', leaks.leaks[LeakType.notDisposed]!)}'
      '${ObjectReport.iterableToYaml('notGCed', leaks.leaks[LeakType.notGCed]!)}'
      '${ObjectReport.iterableToYaml('gcedLate', leaks.leaks[LeakType.gcedLate]!)}';
}

@visibleForTesting
Map<ObjectReport, List<ObjectReport>> findCulprits(List<ObjectReport> notGCed) {
  return {};
}

String pathToString(RetainingPath path) {
  return path.toString();

  final result = StringBuffer();
  for (var item in path.elements ?? <RetainingObject>[]) {
    result.write('/');
    result.write(item.value.hashCode);
  }
  // We need this last slash to avoid parent-child detection for paths where
  // codes happened to be prefix for one another (like 'ab' and 'abc').
  result.write('/');
  return result.toString();
}
