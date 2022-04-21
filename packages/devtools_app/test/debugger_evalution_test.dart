// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/evaluate.dart';
import 'package:devtools_app/src/shared/eval_on_dart_library.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/ui/search.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_infra/flutter_test_driver.dart';
import 'test_infra/flutter_test_environment.dart';

void main() {
  final FlutterTestEnvironment env = FlutterTestEnvironment(
    const FlutterRunConfiguration(withDebugger: true),
  );

  final DebuggerController debuggerController = TestDebuggerController();

  late Disposable isAlive;
  late EvalOnDartLibrary eval;

  setUp(() async {
    isAlive = Disposable();
    await env.setupEnvironment();
    eval = EvalOnDartLibrary(
      'package:flutter_app/src/autocomplete.dart',
      serviceManager.service!,
      disableBreakpoints: false,
    );
  });

  tearDown(() async {
    await debuggerController.resume();
    isAlive.dispose();
    debuggerController.dispose();
    await env.tearDownEnvironment();
  });

  tearDownAll(() async {
    await env.tearDownEnvironment(force: true);
  });

  Future<void> runMethodAndWaitForPause(String method) async {
    unawaited(eval.eval(method, isAlive: isAlive));

    await whenMatches(debuggerController.selectedStackFrame, (f) => f != null);
  }

  group(
    'EvalOnDartLibrary',
    () {
      test(
        'returns scoped variables when EditingParts is not a field',
        () async {
          await runMethodAndWaitForPause(
            'AnotherClass().pauseWithScopedVariablesMethod()',
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'foo',
                leftSide: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals(['foo', 'foobar']),
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'b',
                leftSide: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals(['bar', 'baz']),
          );
        },
        timeout: const Timeout.factor(8),
      );

      test(
        'returns filtered members when EditingParts is a field ',
        () async {
          await runMethodAndWaitForPause(
            'AnotherClass().pauseWithScopedVariablesMethod()',
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'f',
                leftSide: 'foo.',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals(['field1', 'field2', 'func1', 'func2']),
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'fu',
                leftSide: 'foo.',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals(['func1', 'func2']),
          );
        },
        timeout: const Timeout.factor(8),
      );

      test(
        'returns filtered members when EditingParts is a class name ',
        () async {
          await runMethodAndWaitForPause(
            'AnotherClass().pauseWithScopedVariablesMethod()',
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                leftSide: 'FooClass.',
                activeWord: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals([
              'staticField1',
              'staticField2',
              'namedConstructor',
              'factory1',
              'staticMethod'
            ]),
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'fa',
                leftSide: 'FooClass.',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals(['factory1']),
          );
        },
        timeout: const Timeout.factor(8),
      );
      test(
        'returns privates only from library',
        () async {
          await runMethodAndWaitForPause(
            'AnotherClass().pauseWithScopedVariablesMethod()',
          );
          expect(
            collectionEquals(
              await autoCompleteResultsFor(
                EditingParts(
                  activeWord: '_',
                  leftSide: '',
                  rightSide: '',
                ),
                debuggerController,
              ),
              [
                '_privateField2',
                '_privateField1',
                '_PrivateClass',
              ],
              ordered: false,
            ),
            isTrue,
          );
        },
        timeout: const Timeout.factor(8),
      );
      test(
        'returns exported members from import',
        () async {
          await runMethodAndWaitForPause(
            'AnotherClass().pauseWithScopedVariablesMethod()',
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'exportedField',
                leftSide: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals([
              'exportedField',
            ]),
          );

          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'ExportedClass',
                leftSide: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals([
              'ExportedClass',
            ]),
          );

          // Privates are not exported
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: '_privateExportedField',
                leftSide: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals([]),
          );

          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: '_PrivateExportedClass',
                leftSide: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals([]),
          );
        },
        timeout: const Timeout.factor(8),
      );

      test(
        'returns prefixes of libraries imported',
        () async {
          await runMethodAndWaitForPause(
            'AnotherClass().pauseWithScopedVariablesMethod()',
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'developer',
                leftSide: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals([
              'developer',
            ]),
          );

          expect(
            await autoCompleteResultsFor(
              EditingParts(
                activeWord: 'math',
                leftSide: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals([
              'math',
            ]),
          );
        },
        timeout: const Timeout.factor(8),
      );

      test(
        'returns no operators for int',
        () async {
          await runMethodAndWaitForPause(
            'AnotherClass().pauseWithScopedVariablesMethod()',
          );
          expect(
            await autoCompleteResultsFor(
              EditingParts(
                leftSide: '7.',
                activeWord: '',
                rightSide: '',
              ),
              debuggerController,
            ),
            equals(
              [
                'hashCode',
                'bitLength',
                'toString',
                'remainder',
                'abs',
                'sign',
                'isEven',
                'isOdd',
                'isNaN',
                'isNegative',
                'isInfinite',
                'isFinite',
                'toUnsigned',
                'toSigned',
                'compareTo',
                'round',
                'floor',
                'ceil',
                'truncate',
                'roundToDouble',
                'floorToDouble',
                'ceilToDouble',
                'truncateToDouble',
                'clamp',
                'toInt',
                'toDouble',
                'toStringAsFixed',
                'toStringAsExponential',
                'toStringAsPrecision',
                'toRadixString',
                'modPow',
                'modInverse',
                'gcd',
                'noSuchMethod',
                'runtimeType'
              ],
            ),
          );
        },
        timeout: const Timeout.factor(8),
      );
    },
  );
}
