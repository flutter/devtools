// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:devtools_app/src/shared/primitives/history_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('HistoryManager', () {
    late HistoryManager history;

    final ref1 = ScriptRef(uri: 'package:foo/foo.dart', id: 'id-1');
    final ref2 = ScriptRef(uri: 'package:bar/bar.dart', id: 'id-2');
    final ref3 = ScriptRef(uri: 'package:baz/baz.dart', id: 'id-3');

    setUp(() {
      history = HistoryManager<ScriptRef>();
    });

    test('initial values', () {
      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
      expect(history.current.value, isNull);
    });

    test('moveBack', () {
      history.push(ref1);
      history.push(ref2);
      history.push(ref3);

      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.current.value, ref3);

      history.moveBack();

      expect(history.hasNext, true);
      expect(history.hasPrevious, true);
      expect(history.current.value, ref2);

      history.moveBack();

      expect(history.hasNext, true);
      expect(history.hasPrevious, false);
      expect(history.current.value, ref1);
    });

    test('moveForward', () {
      history.push(ref1);
      history.push(ref2);

      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.current.value, ref2);

      history.moveBack();

      expect(history.hasNext, true);
      expect(history.hasPrevious, false);
      expect(history.current.value, ref1);

      history.moveForward();

      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.current.value, ref2);
    });

    test('ref can be in history twice', () {
      history.push(ref1);
      history.push(ref2);
      history.push(ref1);
      history.push(ref2);

      expect(history.current.value, ref2);
      history.moveBack();
      expect(history.current.value, ref1);
      history.moveBack();
      expect(history.current.value, ref2);
      history.moveBack();
      expect(history.current.value, ref1);
    });

    test('pop entries', () {
      history.push(ref1);
      history.push(ref2);
      history.push(ref3);

      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.current.value, ref3);

      history.pop();
      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.current.value, ref2);

      history.pop();
      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
      expect(history.current.value, ref1);

      history.pop();
      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
      expect(history.current.value, null);
    });

    test('replaceCurrent empty history', () {
      expect(history.current.value, null);
      history.replaceCurrent(ref1);
      expect(history.current.value, ref1);
      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
    });

    test('replaceCurrent at the top of the stack', () {
      history.push(ref1);
      history.push(ref2);
      history.push(ref3);

      expect(history.current.value, ref3);
      expect(history.hasNext, false);
      expect(history.hasPrevious, true);

      history.replaceCurrent(ref1);
      expect(history.current.value, ref1);
      expect(history.hasNext, false);
      expect(history.hasPrevious, true);

      history.moveBack();
      expect(history.current.value, ref2);
      expect(history.hasNext, true);
      expect(history.hasPrevious, true);

      history.moveBack();
      expect(history.current.value, ref1);
      expect(history.hasNext, true);
      expect(history.hasPrevious, false);
    });

    test('replaceCurrent in the middle of the stack', () {
      history.push(ref1);
      history.push(ref2);
      history.push(ref3);

      history.moveBack();
      expect(history.current.value, ref2);
      expect(history.hasNext, true);
      expect(history.hasPrevious, true);

      history.replaceCurrent(ref3);
      expect(history.current.value, ref3);
      expect(history.hasNext, true);
      expect(history.hasPrevious, true);

      history.moveBack();
      expect(history.current.value, ref1);
      expect(history.hasNext, true);
      expect(history.hasPrevious, false);

      history.moveForward();
      history.moveForward();
      expect(history.current.value, ref3);
      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
    });

    test('replaceCurrent at the bottom of the stack', () {
      history.push(ref1);
      history.push(ref2);
      history.push(ref3);

      history.moveBack();
      history.moveBack();
      expect(history.current.value, ref1);
      expect(history.hasNext, true);
      expect(history.hasPrevious, false);

      history.replaceCurrent(ref3);
      expect(history.current.value, ref3);
      expect(history.hasNext, true);
      expect(history.hasPrevious, false);

      history.moveForward();
      expect(history.current.value, ref2);
      expect(history.hasNext, true);
      expect(history.hasPrevious, true);

      history.moveForward();
      expect(history.current.value, ref3);
      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
    });
  });
}
