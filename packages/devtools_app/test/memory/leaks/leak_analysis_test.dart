import 'package:devtools_app/src/screens/memory/panes/leaks/leak_analysis.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_tools/src/model.dart';

void main() {
  test('Culprits are found as expected.', () {
    final culprit1 = _createReport('culprit1', '/1/2/');
    final culprit2 = _createReport('culprit1', '/1/7/');

    final notGCed = [
      culprit1,
      _createReport('victim11', '/1/2/3/4/5/'),
      _createReport('victim12', '/1/2/3/'),
      culprit2,
      _createReport('victim21', '/1/7/3/4/5/'),
      _createReport('victim22', '/1/7/3/'),
    ];

    final culprits = findCulprits(notGCed);

    expect(culprits, hasLength(2));
    expect(culprits.keys, contains(culprit1));
    expect(culprits[culprit1], hasLength(2));
    expect(culprits.keys, contains(culprit2));
    expect(culprits[culprit2], hasLength(2));
  });
}

ObjectReport _createReport(String token, String path) => ObjectReport(
    token: token, type: '', creationLocation: '', theIdentityHashCode: 0)
  ..retainingPath = path;
