import 'package:devtools_app/src/screens/memory/panes/leaks/leak_analysis.dart';
import 'package:memory_tools/src/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Culprits are found as expected.', () {
    final notGCed = [
      _createReport('culprit1', '/1/2/'),
      _createReport('victim11', '/1/2/3/4/5/'),
      _createReport('victim12', '/1/2/3/'),
      _createReport('culprit1', '/1/7/'),
      _createReport('victim11', '/1/7/3/4/5/'),
      _createReport('victim12', '/1/7/3/'),
    ];

    final culprits = findCulprits(notGCed);

    expect(culprits, hasLength(2));
    expect(culprits.keys, contains('culprit1'));
    expect(culprits.keys, contains('culprit2'));
  });
}

ObjectReport _createReport(String token, String path) => ObjectReport(
    token: token, type: '', creationLocation: '', theIdentityHashCode: 0)
  ..retainingPath = path;
