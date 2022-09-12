// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/model.dart';
import 'package:devtools_app/src/screens/memory/panes/leaks/instrumentation/model.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('$NotGCedAnalyzerTask serializes.', () {
    final task = NotGCedAnalyzerTask(
      reports: [
        LeakReport(
          type: 'type',
          details: ['details'],
          code: 2,
        )
      ],
      heap: AdaptedHeap(
        [
          AdaptedHeapObject(
            className: 'class',
            references: [2, 3, 4],
            code: 6,
            library: 'library',
            shallowSize: 1,
          ),
        ],
        rootIndex: 0,
      ),
    );

    final json = task.toJson();

    expect(
      jsonEncode(json),
      jsonEncode(NotGCedAnalyzerTask.fromJson(json).toJson()),
    );
  });

  test('$AdaptedHeap serializes.', () {
    final json = AdaptedHeap(
      [
        AdaptedHeapObject(
          code: 1,
          references: [3, 4, 5],
          className: 'klass',
          library: 'library',
          shallowSize: 1,
        )
      ],
      rootIndex: 0,
    ).toJson();

    expect(json, AdaptedHeap.fromJson(json).toJson());
  });
}
