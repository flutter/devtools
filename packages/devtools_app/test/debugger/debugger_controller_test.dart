// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/codeview_controller.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/console/primitives/eval_history.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());

  group('ScriptsHistory', () {
    late ScriptsHistory history;

    final ref1 = ScriptRef(uri: 'package:foo/foo.dart', id: 'id-1');
    final ref2 = ScriptRef(uri: 'package:bar/bar.dart', id: 'id-2');
    final ref3 = ScriptRef(uri: 'package:baz/baz.dart', id: 'id-3');

    setUp(() {
      history = ScriptsHistory();
    });

    test('initial values', () {
      expect(history.hasNext, false);
      expect(history.hasPrevious, false);
      expect(history.current.value, isNull);
      expect(history.hasScripts, false);
    });

    test('moveBack', () {
      history.pushEntry(ref1);
      history.pushEntry(ref2);
      history.pushEntry(ref3);

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
      history.pushEntry(ref1);
      history.pushEntry(ref2);

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

      expect(history.current.value, ref2);
      history.moveBack();
      expect(history.current.value, ref1);
      history.moveBack();
      expect(history.current.value, ref2);
      history.moveBack();
      expect(history.current.value, ref1);
    });

    test('pushEntry removes next entries', () {
      history.pushEntry(ref1);
      history.pushEntry(ref2);

      expect(history.current.value, ref2);
      expect(history.hasNext, isFalse);
      history.moveBack();
      expect(history.current.value, ref1);
      expect(history.hasNext, isTrue);
      history.pushEntry(ref3);
      expect(history.current.value, ref3);
      expect(history.hasNext, isFalse);
    });
  });

  group('EvalHistory', () {
    late EvalHistory evalHistory;

    setUp(() {
      evalHistory = EvalHistory();
    });

    test('starts empty', () {
      expect(evalHistory.evalHistory, <Object?>[]);
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

  group('search', () {
    late CodeViewController debuggerController;

    setUp(() {
      debuggerController = TestCodeViewController();
      debuggerController.parsedScript.value = ParsedScript(
        script: testScript,
        highlighter: mockSyntaxHighlighter,
        executableLines: const {},
        sourceReport: const ProcessedSourceReport.empty(),
      );
    });

    test('matchesForSearch', () {
      expect(
        debuggerController.matchesForSearch('import').toString(),
        equals('[0:0-6, 1:0-6, 2:0-6]'),
      );
      expect(
        debuggerController.matchesForSearch('foo').toString(),
        equals('[1:8-11, 2:8-11]'),
      );
      expect(
        debuggerController.matchesForSearch('bar').toString(),
        equals('[0:8-11, 2:11-14]'),
      );
      expect(
        debuggerController.matchesForSearch('hello world').toString(),
        equals('[5:28-39, 6:9-20]'),
      );
      expect(
        debuggerController.matchesForSearch('').toString(),
        equals('[]'),
      );
    });
  });
}

final testScript = Script(
  source: '''
import 'bar.dart';
import 'foo.dart';
import 'foobar.dart';

void main() {
  // This is a comment in a hello world app.
  print('hello world');
}
''',
  id: 'test-script',
  uri: 'debugger/test/script.dart',
  library: LibraryRef(
    id: 'debugger-test-lib',
    name: 'debugger-test',
    uri: 'debugger/test',
  ),
);
