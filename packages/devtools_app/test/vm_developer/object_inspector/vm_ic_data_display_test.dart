// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_ic_data_display.dart';
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
  late MockICDataObject mockICDataObject;

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

    mockICDataObject = MockICDataObject();

    mockVmObject(mockICDataObject);
    when(mockICDataObject.obj).thenReturn(
      ICData(
        id: 'ic-data-id',
        owner: ClassRef(
          id: 'cls-id',
          name: 'func',
        ),
        selector: 'foo',
        size: 64,
        argumentsDescriptor: Instance(id: 'inst-1', length: 0, elements: []),
        entries: Instance(id: 'inst-2', length: 0, elements: []),
        classRef: ClassRef(id: 'cls-id-2', name: 'ICData'),
        json: {},
      ),
    );
  });

  group('IC data display test', () {
    testWidgetsWithWindowSize(
      'basic layout',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            VmICDataDisplay(
              icData: mockICDataObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
        expect(find.byType(VMInfoCard), findsOneWidget);
        expect(find.text('General Information'), findsOneWidget);
        expect(find.text('Object Class:'), findsOneWidget);
        expect(find.text('ICData'), findsOneWidget);
        expect(find.text('Shallow Size:'), findsOneWidget);
        expect(find.text('Retained Size:'), findsOneWidget);
        expect(find.text('Selector:'), findsOneWidget);
        expect(find.text('foo'), findsOneWidget);

        expect(find.text('64 B'), findsOneWidget);
        expect(find.text('Owner:'), findsOneWidget);
        expect(find.text('func', findRichText: true), findsOneWidget);

        expect(find.byType(RequestableSizeWidget), findsNWidgets(2));
        expect(find.byType(RetainingPathWidget), findsOneWidget);
        expect(find.byType(InboundReferencesTree), findsOneWidget);
        expect(find.byType(ExpansionTileInstanceList), findsNWidgets(2));
      },
    );
  });
}
