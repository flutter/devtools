// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_simple_list_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late MockSubtypeTestCacheObject mockSubtypeTestCacheObject;

  const windowSize = Size(4000.0, 4000.0);

  setUp(() {
    setUpMockScriptManager();
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());

    mockSubtypeTestCacheObject = MockSubtypeTestCacheObject();

    mockVmObject(mockSubtypeTestCacheObject);
    final cache = Instance(id: 'inst-2', length: 0, elements: []);
    when(mockSubtypeTestCacheObject.obj).thenReturn(
      SubtypeTestCache(
        id: 'subtype-test-cache-id',
        size: 64,
        cache: cache,
        classRef: ClassRef(id: 'cls-id-2', name: 'SubtypeTestCache'),
        json: {},
      ),
    );
    when(mockSubtypeTestCacheObject.elementsAsInstance).thenReturn(cache);
  });

  group('Subtype test cache display test', () {
    testWidgetsWithWindowSize(
      'basic layout',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            VmSimpleListDisplay(
              vmObject: mockSubtypeTestCacheObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
        expect(find.byType(VMInfoCard), findsOneWidget);
        expect(find.text('General Information'), findsOneWidget);
        expect(find.text('Object Class:'), findsOneWidget);
        expect(find.text('SubtypeTestCache'), findsOneWidget);
        expect(find.text('Shallow Size:'), findsOneWidget);
        expect(find.text('Retained Size:'), findsOneWidget);

        expect(find.text('64 B'), findsOneWidget);

        expect(find.byType(RequestableSizeWidget), findsNWidgets(2));
        expect(find.byType(RetainingPathWidget), findsOneWidget);
        expect(find.byType(InboundReferencesTree), findsOneWidget);
        expect(find.byType(ExpansionTileInstanceList), findsOneWidget);
      },
    );
  });
}
