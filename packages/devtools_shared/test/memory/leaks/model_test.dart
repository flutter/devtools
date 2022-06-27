import 'package:devtools_shared/src/memory/leaks/model.dart';

import 'package:test/test.dart';

void main() {
  final report = LeakReport(
    token: 'token',
    type: 'type',
    creationLocation: 'creationLocation',
    code: 123,
  );

  test('$LeakReport.fromJson does not lose information', () {
    final json = report.toJson();
    final copy = LeakReport.fromJson(json);

    expect(copy.token, report.token);
    expect(copy.type, report.type);
    expect(copy.creationLocation, report.creationLocation);
    expect(copy.code, report.code);
  });

  test('$LeakReport.toJson does not lose information.', () {
    final json = report.toJson();
    expect(json, LeakReport.fromJson(json).toJson());
  });
}
