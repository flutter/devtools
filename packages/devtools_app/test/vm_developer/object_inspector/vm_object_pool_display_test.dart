// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/inbound_references_tree.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_object_pool_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late MockObjectPoolObject mockObjectPool;

  const windowSize = Size(4000.0, 4000.0);

  group('VmObjectPoolDisplay', () {
    setUp(() {
      setUpMockScriptManager();
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(
        DevToolsEnvironmentParameters,
        ExternalDevToolsEnvironmentParameters(),
      );
      setGlobal(PreferencesController, PreferencesController());

      mockObjectPool = MockObjectPoolObject();

      final objectPoolEntries = <ObjectPoolEntry>[
        ObjectPoolEntry(
          offset: 0,
          kind: ObjectPoolEntryKind.object,
          value: InstanceRef(
            id: 'fake-inst',
            kind: InstanceKind.kList,
            length: 0,
          ),
        ),
        const ObjectPoolEntry(
          offset: 10,
          kind: ObjectPoolEntryKind.immediate,
          value: 42,
        ),
        ObjectPoolEntry(
          offset: 20,
          kind: ObjectPoolEntryKind.nativeFunction,
          value: FuncRef(id: 'func-id', name: 'Foo'),
        ),
      ];

      final testPool = ObjectPool(
        json: {
          'size': 0,
        },
        id: 'object-pool-id',
        entries: objectPoolEntries,
        length: objectPoolEntries.length,
      );
      when(mockObjectPool.obj).thenReturn(testPool);
      when(mockObjectPool.script).thenReturn(null);
      when(mockObjectPool.retainingPath).thenReturn(
        const FixedValueListenable<RetainingPath?>(null),
      );
      when(mockObjectPool.inboundReferencesTree).thenReturn(
        const FixedValueListenable<List<InboundReferencesTreeNode>>([]),
      );
      when(mockObjectPool.fetchingReachableSize).thenReturn(
        const FixedValueListenable<bool>(false),
      );
      when(mockObjectPool.fetchingRetainedSize).thenReturn(
        const FixedValueListenable<bool>(false),
      );
      when(mockObjectPool.retainedSize).thenReturn(null);
      when(mockObjectPool.reachableSize).thenReturn(null);
    });

    testWidgetsWithWindowSize(
      'displays object pool entries',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapSimple(
            VmObjectPoolDisplay(
              objectPool: mockObjectPool,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
        expect(find.byType(VMInfoCard), findsOneWidget);
        expect(find.text('General Information'), findsOneWidget);
        expect(find.text('ObjectPool'), findsOneWidget);
        expect(find.text('Shallow Size:'), findsOneWidget);
        expect(find.text('0 B'), findsOneWidget);
        expect(find.text('Reachable Size:'), findsOneWidget);
        expect(find.text('Retained Size:'), findsOneWidget);

        expect(find.byType(RetainingPathWidget), findsOneWidget);
        expect(find.byType(InboundReferencesTree), findsOneWidget);

        expect(find.byType(ObjectPoolTable), findsOneWidget);

        for (final entry in mockObjectPool.obj.entries) {
          // Includes the offset within the pool.
          expect(
            find.text(
              '[PP + 0x${entry.offset.toRadixString(16).toUpperCase()}]',
              findRichText: true,
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              VmServiceObjectLink.defaultTextBuilder(entry.value) ??
                  entry.value.toString(),
              findRichText: true,
            ),
            findsOneWidget,
          );
        }
      },
    );
  });
}
