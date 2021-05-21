// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/debugger_model.dart';
import 'package:devtools_app/src/debugger/evaluate.dart';
import 'package:devtools_app/src/ui/search.dart';
import 'package:flutter/widgets.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';

void main() {
  MockDebuggerController debuggerController;

  setUp(() async {
    debuggerController = MockDebuggerController();

    when(debuggerController.selectedStackFrame).thenReturn(
      ValueNotifier(
        StackFrameAndSourcePosition(
          Frame(
            index: 0,
            location: SourceLocation(
                script: ScriptRef(id: 'some-script-loc', uri: ''), tokenPos: 0),
          ),
        ),
      ),
    );
    when(debuggerController.variables).thenReturn(
      ValueNotifier(
        [
          Variable.create(
            BoundVariable(
              name: 'foo',
              value: null,
              declarationTokenPos: 0,
              scopeStartTokenPos: 0,
              scopeEndTokenPos: 0,
            ),
          ),
          Variable.create(
            BoundVariable(
              name: 'foobar',
              value: null,
              declarationTokenPos: 0,
              scopeStartTokenPos: 0,
              scopeEndTokenPos: 0,
            ),
          ),
          Variable.create(
            BoundVariable(
              name: 'bar',
              value: null,
              declarationTokenPos: 0,
              scopeStartTokenPos: 0,
              scopeEndTokenPos: 0,
            ),
          ),
          Variable.create(
            BoundVariable(
              name: 'baz',
              value: null,
              declarationTokenPos: 0,
              scopeStartTokenPos: 0,
              scopeEndTokenPos: 0,
            ),
          ),
        ],
      ),
    );
    when(debuggerController.evalAtCurrentFrame(any)).thenAnswer(
      (_) async =>
          InstanceRef(kind: '', identityHashCode: 0, classRef: null, id: ''),
    );
    when(debuggerController.getObject(any)).thenAnswer((inv) async {
      final obj = inv.positionalArguments.first;
      if (obj is ClassRef) {
        return Class(
          fields: [
            FieldRef(
              name: 'field1',
              owner: null,
              declaredType: null,
              isConst: false,
              isFinal: false,
              isStatic: false,
              id: '',
            ),
            FieldRef(
              name: 'field2',
              owner: null,
              declaredType: null,
              isConst: false,
              isFinal: false,
              isStatic: false,
              id: '',
            ),
          ],
          functions: [
            FuncRef(
              name: 'func1',
              owner: null,
              isStatic: false,
              isConst: false,
              id: '',
            ),
            FuncRef(
              name: 'func2',
              owner: null,
              isStatic: false,
              isConst: false,
              id: '',
            ),
            FuncRef(
              name: 'funcStatic',
              owner: null,
              isStatic: true,
              isConst: false,
              id: '',
            ),
            FuncRef(
              name: '>=',
              owner: null,
              isStatic: true,
              isConst: false,
              id: '',
            ),
            FuncRef(
              name: '==',
              owner: null,
              isStatic: true,
              isConst: false,
              id: '',
            ),
          ],
          id: '',
          interfaces: [],
          isAbstract: null,
          isConst: null,
          library: null,
          name: 'FooClass',
          subclasses: [],
          traceAllocations: null,
        );
      }
      if (obj is InstanceRef) {
        return Instance(
          classRef: ClassRef(id: '', name: 'FooClass'),
          id: '',
          fields: [
            BoundField(
              decl: FieldRef(
                name: 'fieldBound1',
                owner: null,
                declaredType: null,
                isConst: false,
                isFinal: false,
                isStatic: false,
                id: '',
              ),
              value: null,
            ),
            BoundField(
              decl: FieldRef(
                name: '_privateFieldBound',
                owner: null,
                declaredType: null,
                isConst: false,
                isFinal: false,
                isStatic: false,
                id: '',
              ),
              value: null,
            ),
          ],
          identityHashCode: null,
          kind: '',
        );
      }
      return null;
    });
  });
  test('returns scoped variables when EditingParts is not a field', () async {
    expect(
        await autoCompleteResultsFor(
          EditingParts(
            activeWord: 'foo',
            leftSide: '',
            rightSide: '',
          ),
          debuggerController,
        ),
        equals(['foo', 'foobar']));
    expect(
        await autoCompleteResultsFor(
          EditingParts(
            activeWord: 'b',
            leftSide: '',
            rightSide: '',
          ),
          debuggerController,
        ),
        equals(['bar', 'baz']));
  });

  test('returns filtered members when EditingParts is a field ', () async {
    expect(
        await autoCompleteResultsFor(
          EditingParts(
            activeWord: 'f',
            leftSide: 'foo.',
            rightSide: '',
          ),
          debuggerController,
        ),
        equals(['field1', 'field2', 'fieldBound1', 'func1', 'func2']));
    expect(
        await autoCompleteResultsFor(
          EditingParts(
            activeWord: 'fu',
            leftSide: 'foo.',
            rightSide: '',
          ),
          debuggerController,
        ),
        equals(['func1', 'func2']));
  });
}
