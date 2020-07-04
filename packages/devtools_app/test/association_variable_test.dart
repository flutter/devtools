// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';

import 'package:devtools_app/src/debugger/debugger_controller.dart';
import 'package:devtools_app/src/debugger/debugger_model.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/vm_service_wrapper.dart';

void main() {
  ServiceConnectionManager manager;
  DebuggerController debuggerController;

  setUp(() {
    manager = ServiceConnectionManager();
    manager.service = MockVmServiceWrapper();
    when(manager.service.onDebugEvent).thenAnswer((_) {
      return const Stream.empty();
    });
    when(manager.service.onIsolateEvent).thenAnswer((_) {
      return const Stream.empty();
    });
    when(manager.service.onStdoutEvent).thenAnswer((_) {
      return const Stream.empty();
    });
    when(manager.service.onStderrEvent).thenAnswer((_) {
      return const Stream.empty();
    });
    globals[ServiceConnectionManager] = manager;
    debuggerController = DebuggerController();
    debuggerController.isolateRef =
        IsolateRef(id: '1', number: '2', name: 'main');
  });

  tearDown(() {
    globals[ServiceConnectionManager] = null;
  });

  test('Creates bound variables for Map with String key and Double value',
      () async {
    final instance = Instance(
      kind: InstanceKind.kMap,
      id: '123',
      classRef: null,
      associations: [
        MapAssociation(
          key: InstanceRef(
              classRef: null,
              id: '4',
              kind: InstanceKind.kString,
              valueAsString: 'Hey'),
          value: InstanceRef(
            classRef: null,
            id: '5',
            kind: InstanceKind.kDouble,
            valueAsString: '12.34',
          ),
        ),
      ],
    );
    final variable = Variable.create(BoundVariable(
      name: 'test',
      value: instance,
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ));
    when(manager.service.getObject(any, any)).thenAnswer((_) async {
      return instance;
    });

    await debuggerController.buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[\'Hey\']', value: '12.34'),
    ]);
  });

  test('Creates bound variables for Map with Int key and Double value',
      () async {
    final instance = Instance(
      kind: InstanceKind.kMap,
      id: '123',
      classRef: null,
      associations: [
        MapAssociation(
          key: InstanceRef(
              classRef: null,
              id: '4',
              kind: InstanceKind.kInt,
              valueAsString: '1'),
          value: InstanceRef(
            classRef: null,
            id: '5',
            kind: InstanceKind.kDouble,
            valueAsString: '12.34',
          ),
        ),
      ],
    );
    final variable = Variable.create(BoundVariable(
      name: 'test',
      value: instance,
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ));
    when(manager.service.getObject(any, any)).thenAnswer((_) async {
      return instance;
    });

    await debuggerController.buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[1]', value: '12.34'),
    ]);
  });

  test('Creates bound variables for Map with Object key and Double value',
      () async {
    final instance = Instance(
      kind: InstanceKind.kMap,
      id: '123',
      classRef: null,
      associations: [
        MapAssociation(
          key: InstanceRef(
            classRef: ClassRef(id: 'a', name: 'Foo'),
            id: '4',
            kind: InstanceKind.kPlainInstance,
          ),
          value: InstanceRef(
            classRef: null,
            id: '5',
            kind: InstanceKind.kDouble,
            valueAsString: '12.34',
          ),
        ),
      ],
    );
    final variable = Variable.create(BoundVariable(
      name: 'test',
      value: instance,
      declarationTokenPos: null,
      scopeEndTokenPos: null,
      scopeStartTokenPos: null,
    ));
    when(manager.service.getObject(any, any)).thenAnswer((_) async {
      return instance;
    });

    await debuggerController.buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[key]', value: 'Foo'),
      matchesVariable(name: '[value]', value: '12.34'),
    ]);
  });
}

Matcher matchesVariable({
  @required String name,
  @required Object value,
}) {
  return const TypeMatcher<Variable>()
      .having(
        (v) => v.displayValue,
        'displayValue',
        equals(value),
      )
      .having(
          (v) => v.boundVar,
          'boundVar',
          const TypeMatcher<BoundVariable>()
              .having((bv) => bv.name, 'name', equals(name)));
}

class MockVmServiceWrapper extends Mock implements VmServiceWrapper {}
