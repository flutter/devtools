// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/diagnostics/dart_object_node.dart';
import 'package:devtools_app/src/shared/diagnostics/tree_builder.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

const isolateId = '433';
const objectId = '123';

void main() {
  late ServiceConnectionManager manager;

  setUp(() {
    final service = createMockVmServiceWrapperWithDefaults();

    manager = FakeServiceConnectionManager(service: service);
    setGlobal(ServiceConnectionManager, manager);
  });

  test(
    'Creates bound variable for a Record with ascending positional fields before named fields',
    () async {
      final instance = Instance(
        kind: InstanceKind.kRecord,
        id: objectId,
        length: 3,
        fields: [
          BoundField(
            name: 1,
            value: InstanceRef(
              id: '5',
              kind: InstanceKind.kBool,
              valueAsString: 'true',
            ),
          ),
          BoundField(
            name: 'myNamedField',
            value: InstanceRef(
              id: '5',
              kind: InstanceKind.kString,
              valueAsString: 'hello world',
            ),
          ),
          BoundField(
            name: 0,
            value: InstanceRef(
              id: '5',
              kind: InstanceKind.kDouble,
              valueAsString: '12.34',
            ),
          ),
        ],
      );
      final isolateRef = IsolateRef(
        id: isolateId,
        number: '1',
        name: 'my-isolate',
        isSystemIsolate: false,
      );
      final recordVar = DartObjectNode.create(
        BoundVariable(
          name: 'myRecord',
          value: instance,
        ),
        isolateRef,
      );

      when(
        manager.serviceManager.service!.getObject(
          isolateId,
          objectId,
        ),
      ).thenAnswer((_) async {
        return instance;
      });

      await buildVariablesTree(recordVar);

      expect(recordVar.children, [
        matchesVariable(name: '\$1', value: '12.34'),
        matchesVariable(name: '\$2', value: 'true'),
        matchesVariable(name: 'myNamedField', value: "'hello world'"),
      ]);
    },
  );
}

Matcher matchesVariable({
  required String? name,
  required Object value,
}) {
  return const TypeMatcher<DartObjectNode>()
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
