// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/debugger_controller.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('ScriptsHistory', () {
    ScriptsHistory history;

    final ScriptRef ref1 = ScriptRef(uri: 'package:foo/foo.dart', id: 'id-1');
    final ScriptRef ref2 = ScriptRef(uri: 'package:bar/bar.dart', id: 'id-2');
    final ScriptRef ref3 = ScriptRef(uri: 'package:baz/baz.dart', id: 'id-3');

    setUp(() {
      history = ScriptsHistory();
    });

    test('initial values', () {
      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
      expect(history.currentScript, isNull);
      expect(history.hasScripts, false);
    });

    test('moveBack', () {
      history.pushEntry(ref1);
      history.pushEntry(ref2);
      history.pushEntry(ref3);

      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.currentScript, ref3);

      history.moveBack();

      expect(history.hasNext, true);
      expect(history.hasPrevious, true);
      expect(history.currentScript, ref2);

      history.moveBack();

      expect(history.hasNext, true);
      expect(history.hasPrevious, false);
      expect(history.currentScript, ref1);
    });

    test('moveBack', () {
      history.pushEntry(ref1);
      history.pushEntry(ref2);

      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.currentScript, ref2);

      history.moveBack();

      expect(history.hasNext, true);
      expect(history.hasPrevious, false);
      expect(history.currentScript, ref1);

      history.moveForward();

      expect(history.hasNext, false);
      expect(history.hasPrevious, true);
      expect(history.currentScript, ref2);
    });

    test('openedScripts', () {
      history.pushEntry(ref1);
      history.pushEntry(ref2);
      history.pushEntry(ref3);

      expect(history.openedScripts, orderedEquals([ref3, ref2, ref1]));

      // verify that pushing re-orders
      history.pushEntry(ref2);
      expect(history.openedScripts, orderedEquals([ref2, ref3, ref1]));
    });

    test('ref can be in history twice', () {
      history.pushEntry(ref1);
      history.pushEntry(ref2);
      history.pushEntry(ref1);
      history.pushEntry(ref2);

      expect(history.currentScript, ref2);
      history.moveBack();
      expect(history.currentScript, ref1);
      history.moveBack();
      expect(history.currentScript, ref2);
      history.moveBack();
      expect(history.currentScript, ref1);
    });

    test('pushEntry removes next entries', () {
      history.pushEntry(ref1);
      history.pushEntry(ref2);

      expect(history.currentScript, ref2);
      expect(history.hasNext, isFalse);
      history.moveBack();
      expect(history.currentScript, ref1);
      expect(history.hasNext, isTrue);
      history.pushEntry(ref3);
      expect(history.currentScript, ref3);
      expect(history.hasNext, isFalse);
    });
  });

  group('EvalHistory', () {
    EvalHistory evalHistory;

    setUp(() {
      evalHistory = EvalHistory();
    });

    test('starts empty', () {
      expect(evalHistory.evalHistory, []);
      expect(evalHistory.currentText, null);
      expect(evalHistory.canNavigateDown, false);
      expect(evalHistory.canNavigateUp, false);
    });

    test('pushEvalHistory', () {
      evalHistory.pushEvalHistory('aaa');
      evalHistory.pushEvalHistory('bbb');
      evalHistory.pushEvalHistory('ccc');

      expect(evalHistory.currentText, null);
      evalHistory.navigateUp();
      expect(evalHistory.currentText, 'ccc');
      evalHistory.navigateUp();
      expect(evalHistory.currentText, 'bbb');
      evalHistory.navigateUp();
      expect(evalHistory.currentText, 'aaa');
    });

    test('navigateUp', () {
      expect(evalHistory.canNavigateUp, false);
      expect(evalHistory.currentText, null);

      evalHistory.pushEvalHistory('aaa');
      evalHistory.pushEvalHistory('bbb');

      expect(evalHistory.canNavigateUp, true);
      expect(evalHistory.currentText, null);

      evalHistory.navigateUp();
      expect(evalHistory.canNavigateUp, true);
      expect(evalHistory.currentText, 'bbb');

      evalHistory.navigateUp();
      expect(evalHistory.canNavigateUp, false);
      expect(evalHistory.currentText, 'aaa');

      evalHistory.navigateUp();
      expect(evalHistory.currentText, 'aaa');
    });

    test('navigateDown', () {
      expect(evalHistory.canNavigateDown, false);
      expect(evalHistory.currentText, null);

      evalHistory.pushEvalHistory('aaa');
      evalHistory.pushEvalHistory('bbb');
      expect(evalHistory.canNavigateDown, false);

      evalHistory.navigateUp();
      evalHistory.navigateUp();

      expect(evalHistory.canNavigateDown, true);
      expect(evalHistory.currentText, 'aaa');

      evalHistory.navigateDown();
      expect(evalHistory.canNavigateDown, true);
      expect(evalHistory.currentText, 'bbb');

      evalHistory.navigateDown();
      expect(evalHistory.canNavigateDown, false);
      expect(evalHistory.currentText, null);

      evalHistory.navigateDown();
      expect(evalHistory.canNavigateDown, false);
      expect(evalHistory.currentText, null);
    });

    test('pushEvalHistory reset position', () {
      evalHistory.pushEvalHistory('aaa');
      evalHistory.pushEvalHistory('bbb');
      expect(evalHistory.currentText, null);
      expect(evalHistory.canNavigateDown, false);

      evalHistory.navigateUp();
      expect(evalHistory.currentText, 'bbb');
      expect(evalHistory.canNavigateDown, true);

      evalHistory.pushEvalHistory('ccc');
      expect(evalHistory.currentText, null);
      expect(evalHistory.canNavigateDown, false);
    });
  });
}
