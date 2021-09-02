// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/debugger_model.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'support/mocks.dart';

final libraryRef = LibraryRef(
  name: 'some library',
  uri: 'package:foo/foo.dart',
  id: 'lib-id-1',
);

void main() {
  ServiceConnectionManager manager;

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
    manager = FakeServiceManager(service: service);
    setGlobal(ServiceConnectionManager, manager);
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
            valueAsString: 'Hey',
            identityHashCode: null,
          ),
          value: InstanceRef(
            classRef: null,
            id: '5',
            kind: InstanceKind.kDouble,
            valueAsString: '12.34',
            identityHashCode: null,
          ),
        ),
      ],
      identityHashCode: null,
    );
    final isolateRef = IsolateRef(
      id: '433',
      number: '1',
      name: 'my-isolate',
      isSystemIsolate: false,
    );
    final variable = Variable.create(
      BoundVariable(
        name: 'test',
        value: instance,
        declarationTokenPos: null,
        scopeEndTokenPos: null,
        scopeStartTokenPos: null,
      ),
      isolateRef,
    );
    when(manager.service.getObject(any, any)).thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children.first.children, [
      matchesVariable(name: '[key]', value: '\'Hey\''),
      matchesVariable(name: '[value]', value: '12.34'),
    ]);

    expect(variable.children, [
      matchesVariable(name: null, value: '[Entry 0]'),
    ]);
  });

  test('Creates bound variables for Map with Int key and Double value',
      () async {
    final isolateRef = IsolateRef(
      id: '433',
      number: '1',
      name: 'my-isolate',
      isSystemIsolate: false,
    );
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
            valueAsString: '1',
            identityHashCode: null,
          ),
          value: InstanceRef(
            classRef: null,
            id: '5',
            kind: InstanceKind.kDouble,
            valueAsString: '12.34',
            identityHashCode: null,
          ),
        ),
      ],
      identityHashCode: null,
    );
    final variable = Variable.create(
      BoundVariable(
        name: 'test',
        value: instance,
        declarationTokenPos: null,
        scopeEndTokenPos: null,
        scopeStartTokenPos: null,
      ),
      isolateRef,
    );
    when(manager.service.getObject(any, any)).thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: null, value: '[Entry 0]'),
    ]);
    expect(variable.children.first.children, [
      matchesVariable(name: '[key]', value: '1'),
      matchesVariable(name: '[value]', value: '12.34'),
    ]);
  });

  test('Creates bound variables for Map with Object key and Double value',
      () async {
    final isolateRef = IsolateRef(
      id: '433',
      number: '1',
      name: 'my-isolate',
      isSystemIsolate: false,
    );
    final instance = Instance(
      kind: InstanceKind.kMap,
      id: '123',
      classRef: null,
      associations: [
        MapAssociation(
          key: InstanceRef(
            classRef: ClassRef(id: 'a', name: 'Foo', library: libraryRef),
            id: '4',
            kind: InstanceKind.kPlainInstance,
            identityHashCode: null,
          ),
          value: InstanceRef(
            classRef: null,
            id: '5',
            kind: InstanceKind.kDouble,
            valueAsString: '12.34',
            identityHashCode: null,
          ),
        ),
      ],
      identityHashCode: null,
    );
    final variable = Variable.create(
      BoundVariable(
        name: 'test',
        value: instance,
        declarationTokenPos: null,
        scopeEndTokenPos: null,
        scopeStartTokenPos: null,
      ),
      isolateRef,
    );
    when(manager.service.getObject(any, any)).thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: null, value: '[Entry 0]'),
    ]);
    expect(variable.children.first.children, [
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
        (v) => v.name,
        'name',
        equals(name),
      );
}
