// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$RemoteDiagnosticsNode', () {
    test('equality is order agnostic', () {
      final json1 = <String, dynamic>{
        'a': 1,
        'b': <String, dynamic>{'x': 2, 'y': 3},
      };
      final json2 = <String, dynamic>{
        'b': <String, dynamic>{'y': 3, 'x': 2},
        'a': 1,
      };
      expect(
        RemoteDiagnosticsNode.jsonHashCode(json1),
        RemoteDiagnosticsNode.jsonHashCode(json2),
      );
      expect(
        RemoteDiagnosticsNode.jsonEquality(json1, json2),
        isTrue,
      );
    });

    test('equality is deep', () {
      final json1 = <String, dynamic>{
        'a': 1,
        'b': <String, dynamic>{'x': 3, 'y': 2},
      };
      final json2 = <String, dynamic>{
        'b': <String, dynamic>{'y': 3, 'x': 2},
        'a': 1,
      };
      expect(
        RemoteDiagnosticsNode.jsonEquality(json1, json2),
        isFalse,
      );
    });
  });
}
