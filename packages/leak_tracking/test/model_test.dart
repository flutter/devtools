// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:leak_tracking/src/model.dart';
import 'package:test/test.dart';

void main() {
  final report = LeakReport(
    token: 'token',
    type: 'type',
    code: 123,
    details: 'creationLocation',
  );

  test('$LeakReport.fromJson does not lose information', () {
    final json = report.toJson();
    final copy = LeakReport.fromJson(json);

    expect(copy.token, report.token);
    expect(copy.type, report.type);
    expect(copy.details, report.details);
    expect(copy.code, report.code);
  });

  test('$LeakReport.toJson does not lose information.', () {
    final json = report.toJson();
    expect(json, LeakReport.fromJson(json).toJson());
  });
}
