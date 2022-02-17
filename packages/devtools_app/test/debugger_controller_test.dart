// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_app/src/debugger/debugger_controller.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  group('stdio', () {
    setUp(() {
      final service = MockVmService();
      when(service.onDebugEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onVMEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onIsolateEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onStdoutEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onStderrEvent).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onStdoutEventWithHistory).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onStderrEventWithHistory).thenAnswer((_) {
        return const Stream.empty();
      });
      when(service.onExtensionEventWithHistory).thenAnswer((_) {
        return const Stream.empty();
      });
      final manager = FakeServiceManager(service: service);
      setGlobal(ServiceConnectionManager, manager);
      manager.consoleService.ensureServiceInitialized();
    });

    test('ignores trailing new lines', () {
      serviceManager.consoleService.appendStdio('1\n');
      expect(serviceManager.consoleService.stdio.value.length, 1);
    });

    test('has an item for each line', () {
      serviceManager.consoleService
        ..appendStdio('1\n')
        ..appendStdio('2\n')
        ..appendStdio('3\n')
        ..appendStdio('4\n');
      expect(serviceManager.consoleService.stdio.value.length, 4);
    });

    test('preserves additional newlines', () {
      serviceManager.consoleService
        ..appendStdio('1\n\n')
        ..appendStdio('2\n\n')
        ..appendStdio('3\n\n')
        ..appendStdio('4\n\n');
      expect(serviceManager.consoleService.stdio.value.length, 8);
    });
  });

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

  group('search', () {
    DebuggerController debuggerController;

    setUp(() {
      debuggerController = TestDebuggerController(
        initialSwitchToIsolate: false,
      );
      debuggerController.parsedScript.value = ParsedScript(
        script: testScript,
        highlighter: null,
        executableLines: {},
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
      expect(
        debuggerController.matchesForSearch(null).toString(),
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
