// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/profiler/panes/method_table/method_table_model.dart';
import 'package:devtools_app/src/shared/utils/profiler_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('$MethodTableGraphNode', () {
    final node1 = MethodTableGraphNode(
      name: 'node 1',
      packageUri: 'uri_1',
      sourceLine: 1,
      totalCount: 2,
      selfCount: 1,
      profileMetaData: ProfileMetaData(
        sampleCount: 10,
        samplePeriod: 250,
        time:
            TimeRange()
              ..start = Duration.zero
              ..end = const Duration(seconds: 1),
      ),
      stackFrameIds: {'1'},
    );
    final node2 = MethodTableGraphNode(
      name: 'node 1',
      packageUri: 'uri_1',
      sourceLine: 1,
      totalCount: 4,
      selfCount: 4,
      profileMetaData: ProfileMetaData(
        sampleCount: 10,
        samplePeriod: 250,
        time:
            TimeRange()
              ..start = Duration.zero
              ..end = const Duration(seconds: 1),
      ),
      stackFrameIds: {'2'},
    );
    final node3 = MethodTableGraphNode(
      name: 'node 1',
      packageUri: 'different_uri',
      sourceLine: 1,
      totalCount: 3,
      selfCount: 2,
      profileMetaData: ProfileMetaData(
        sampleCount: 10,
        samplePeriod: 250,
        time:
            TimeRange()
              ..start = Duration.zero
              ..end = const Duration(seconds: 1),
      ),
      stackFrameIds: {'3'},
    );
    final node4 = MethodTableGraphNode(
      name: 'different_name',
      packageUri: 'uri_1',
      sourceLine: 1,
      totalCount: 3,
      selfCount: 3,
      profileMetaData: ProfileMetaData(
        sampleCount: 10,
        samplePeriod: 250,
        time:
            TimeRange()
              ..start = Duration.zero
              ..end = const Duration(seconds: 1),
      ),
      stackFrameIds: {'4'},
    );

    test('shallowEquals ', () {
      expect(node1.shallowEquals(node2), isTrue);
      expect(node1.shallowEquals(node3), isFalse);
      expect(node1.shallowEquals(node4), isFalse);

      expect(node2.shallowEquals(node1), isTrue);
      expect(node2.shallowEquals(node3), isFalse);
      expect(node2.shallowEquals(node4), isFalse);

      expect(node3.shallowEquals(node1), isFalse);
      expect(node3.shallowEquals(node2), isFalse);
      expect(node3.shallowEquals(node4), isFalse);

      expect(node4.shallowEquals(node1), isFalse);
      expect(node4.shallowEquals(node2), isFalse);
      expect(node4.shallowEquals(node3), isFalse);
    });

    test('merge ', () {
      // Make a copy so that we do not modify the original nodes.
      final node1Copy = node1.copy();

      expect(node1Copy.totalCount, 2);
      expect(node1Copy.selfCount, 1);

      // Attempt the unsuccessful merges first and verify nothing is changed.
      node1Copy.merge(node3, mergeTotalTime: true);
      expect(node1Copy.totalCount, 2);
      expect(node1Copy.selfCount, 1);
      node1Copy.merge(node3, mergeTotalTime: true);
      expect(node1Copy.totalCount, 2);
      expect(node1Copy.selfCount, 1);

      expect(node2.totalCount, 4);
      expect(node2.selfCount, 4);
      node1Copy.merge(node2, mergeTotalTime: true);
      expect(node1Copy.totalCount, 6);
      expect(node1Copy.selfCount, 5);
    });

    test('merge without total time', () {
      // Make a copy so that we do not modify the original nodes.
      final node1Copy = node1.copy();

      expect(node1Copy.totalCount, 2);
      expect(node1Copy.selfCount, 1);
      expect(node2.totalCount, 4);
      expect(node2.selfCount, 4);

      node1Copy.merge(node2, mergeTotalTime: false);
      expect(node1Copy.totalCount, 2);
      expect(node1Copy.selfCount, 5);
    });
  });
}
