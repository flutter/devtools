// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/diagnostics/dart_object_node.dart';
import 'package:devtools_app/src/shared/diagnostics/tree_builder.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

const isolateId = '1';
const objectId = '123';

final isolateRef = IsolateRef(
  id: isolateId,
  number: '2',
  name: 'main',
  isSystemIsolate: false,
);

void main() {
  late ServiceConnectionManager manager;

  setUp(() {
    final service = createMockVmServiceWrapperWithDefaults();

    manager = FakeServiceConnectionManager(service: service);
    setGlobal(ServiceConnectionManager, manager);
  });

  test('Creates bound variables for Uint8ClampedList instance', () async {
    final bytes = Uint8ClampedList.fromList([0, 1, 2, 3]);
    final instance = Instance(
      kind: InstanceKind.kUint8ClampedList,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );
    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );

    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 1),
      matchesVariable(name: '[2]', value: 2),
      matchesVariable(name: '[3]', value: 3),
    ]);
  });

  test('Creates bound variables for Uint8List instance', () async {
    final bytes = Uint8List.fromList([0, 1, 2, 3]);
    final instance = Instance(
      kind: InstanceKind.kUint8List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );
    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 1),
      matchesVariable(name: '[2]', value: 2),
      matchesVariable(name: '[3]', value: 3),
    ]);
  });

  test('Creates bound variables for Uint16List instance', () async {
    final bytes = Uint16List.fromList([0, 513, 514, 515]);
    final instance = Instance(
      kind: InstanceKind.kUint16List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );
    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 513),
      matchesVariable(name: '[2]', value: 514),
      matchesVariable(name: '[3]', value: 515),
    ]);
  });

  test('Creates bound variables for Uint32List instance', () async {
    final bytes = Uint32List.fromList([0, 131072, 131073, 131074]);
    final instance = Instance(
      kind: InstanceKind.kUint32List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );
    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 131072),
      matchesVariable(name: '[2]', value: 131073),
      matchesVariable(name: '[3]', value: 131074),
    ]);
  });

  test(
    'Creates bound variables for Uint64List instance',
    () async {
      final bytes =
          Uint64List.fromList([0, 4294967296, 4294967297, 4294967298]);
      final instance = Instance(
        kind: InstanceKind.kUint64List,
        id: objectId,
        bytes: base64.encode(bytes.buffer.asUint8List()),
        length: 4,
      );
      final variable = DartObjectNode.create(
        BoundVariable(
          name: 'test',
          value: instance,
        ),
        isolateRef,
      );
      when(manager.serviceManager.service!.getObject(isolateId, objectId))
          .thenAnswer((_) async {
        return instance;
      });

      await buildVariablesTree(variable);

      expect(variable.children, [
        matchesVariable(name: '[0]', value: 0),
        matchesVariable(name: '[1]', value: 4294967296),
        matchesVariable(name: '[2]', value: 4294967297),
        matchesVariable(name: '[3]', value: 4294967298),
      ]);
    },
    skip: kIsWeb,
  );

  test('Creates bound variables for Int8List instance', () async {
    final bytes = Int8List.fromList([0, 1, -2, 3]);
    final instance = Instance(
      kind: InstanceKind.kInt8List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );
    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 1),
      matchesVariable(name: '[2]', value: -2),
      matchesVariable(name: '[3]', value: 3),
    ]);
  });

  test('Creates bound variables for Int16List instance', () async {
    final bytes = Int16List.fromList([0, 513, -514, 515]);
    final instance = Instance(
      kind: InstanceKind.kInt16List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );
    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 513),
      matchesVariable(name: '[2]', value: -514),
      matchesVariable(name: '[3]', value: 515),
    ]);
  });

  test('Creates bound variables for Int32List instance', () async {
    final bytes = Int32List.fromList([0, 131072, -131073, 131074]);
    final instance = Instance(
      kind: InstanceKind.kInt32List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );
    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 131072),
      matchesVariable(name: '[2]', value: -131073),
      matchesVariable(name: '[3]', value: 131074),
    ]);
  });

  test(
    'Creates bound variables for Int64List instance',
    () async {
      final bytes =
          Int64List.fromList([0, 4294967296, -4294967297, 4294967298]);
      final instance = Instance(
        kind: InstanceKind.kInt64List,
        id: objectId,
        bytes: base64.encode(bytes.buffer.asUint8List()),
        length: 4,
      );
      final variable = DartObjectNode.create(
        BoundVariable(
          name: 'test',
          value: instance,
        ),
        isolateRef,
      );
      when(manager.serviceManager.service!.getObject(isolateId, objectId))
          .thenAnswer((_) async {
        return instance;
      });

      await buildVariablesTree(variable);

      expect(variable.children, [
        matchesVariable(name: '[0]', value: 0),
        matchesVariable(name: '[1]', value: 4294967296),
        matchesVariable(name: '[2]', value: -4294967297),
        matchesVariable(name: '[3]', value: 4294967298),
      ]);
    },
    skip: kIsWeb,
  ); // Int64List cannot be instantiated on the web.

  test('Creates bound variables for Float32List instance', () async {
    final bytes =
        Float32List.fromList([0, 2.2300031185150146, -4.610400199890137]);
    final instance = Instance(
      kind: InstanceKind.kFloat32List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );
    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 2.2300031185150146),
      matchesVariable(name: '[2]', value: -4.610400199890137),
    ]);
  });

  test('Creates bound variables for Float64List instance', () async {
    final bytes = Float64List.fromList([0, 5532.130793, -7532.130793]);
    final instance = Instance(
      kind: InstanceKind.kFloat64List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );

    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(variable.children, [
      matchesVariable(name: '[0]', value: 0),
      matchesVariable(name: '[1]', value: 5532.130793),
      matchesVariable(name: '[2]', value: -7532.130793),
    ]);
  });

  test('Creates bound variables for Int32x4List instance', () async {
    final bytes =
        Int32x4List.fromList([Int32x4.bool(true, false, true, false)]);
    final instance = Instance(
      kind: InstanceKind.kInt32x4List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );

    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });
    await buildVariablesTree(variable);

    expect(
      variable.children.first.displayValue,
      '[ffffffff, 00000000, ffffffff, 00000000]',
      skip: kIsWeb,
    );
    // Formatting is different on the web.
    expect(
      variable.children.first.displayValue,
      '[-1, 0, -1, 0]',
      skip: !kIsWeb,
    );
  });

  test('Creates bound variables for Float32x4List instance', () async {
    final bytes = Float32x4List.fromList(
      [Float32x4(0.0, -232.1999969482422, 2.3299999237060547, 9.0)],
    );
    final instance = Instance(
      kind: InstanceKind.kFloat32x4List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );

    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(
      variable.children.first.displayValue,
      '[0.000000, -232.199997, 2.330000, 9.000000]',
      skip: kIsWeb,
    );
    expect(
      variable.children.first.displayValue,
      '[0, -232.1999969482422, 2.3299999237060547, 9]',
      skip: !kIsWeb,
    );
  });

  test('Creates bound variables for Float64x2List instance', () async {
    final bytes = Float64x2List.fromList([Float64x2(0, -1232.222)]);
    final instance = Instance(
      kind: InstanceKind.kFloat64x2List,
      id: objectId,
      bytes: base64.encode(bytes.buffer.asUint8List()),
      length: 4,
    );

    final variable = DartObjectNode.create(
      BoundVariable(
        name: 'test',
        value: instance,
      ),
      isolateRef,
    );
    when(manager.serviceManager.service!.getObject(isolateId, objectId))
        .thenAnswer((_) async {
      return instance;
    });

    await buildVariablesTree(variable);

    expect(
      variable.children.first.displayValue,
      '[0.000000, -1232.222000]',
      skip: kIsWeb,
    );
    expect(
      variable.children.first.displayValue,
      '[0, -1232.222]',
      skip: !kIsWeb,
    );
  });

  test(
    'Creates bound variable with groupings for children for a large Uint8ClampedList instance',
    () async {
      final instance = Instance(
        kind: InstanceKind.kUint8ClampedList,
        id: objectId,
        length: 332,
      );
      final variable = DartObjectNode.create(
        BoundVariable(
          name: 'test',
          value: instance,
        ),
        isolateRef,
      );

      await buildVariablesTree(variable);

      expect(variable.children, [
        matchesVariableGroup(start: 0, end: 99),
        matchesVariableGroup(start: 100, end: 199),
        matchesVariableGroup(start: 200, end: 299),
        matchesVariableGroup(start: 300, end: 331),
      ]);
    },
  );

  test(
    'Creates groupings of exactly 100 if the length is a multiple of 100',
    () async {
      final instance = Instance(
        kind: InstanceKind.kUint8ClampedList,
        id: objectId,
        length: 300,
      );
      final variable = DartObjectNode.create(
        BoundVariable(
          name: 'test',
          value: instance,
        ),
        isolateRef,
      );

      await buildVariablesTree(variable);

      expect(variable.children, [
        matchesVariableGroup(start: 0, end: 99),
        matchesVariableGroup(start: 100, end: 199),
        matchesVariableGroup(start: 200, end: 299),
      ]);
    },
  );
}

Matcher matchesVariable({
  required String name,
  required Object value,
}) {
  return const TypeMatcher<DartObjectNode>().having(
    (v) => v,
    'boundVar',
    const TypeMatcher<DartObjectNode>()
        .having((v) => v.name, 'name', equals(name))
        .having((v) => v.ref!.value, 'value', equals(value)),
  );
}

Matcher matchesVariableGroup({
  required int start,
  required int end,
}) {
  return const TypeMatcher<DartObjectNode>().having(
    (v) => v,
    'boundVar',
    const TypeMatcher<DartObjectNode>()
        .having((v) => v.text, 'text', equals('[$start - $end]')),
  );
}
