// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/breakpoint_manager.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector_view_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_class_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late MockClassObject mockClassObject;

  const windowSize = Size(4000.0, 4000.0);

  late Class testClassCopy;

  setUp(() {
    setUpMockScriptManager();
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ServiceConnectionManager, FakeServiceManager());
    mockClassObject = MockClassObject();

    final json = testClass.toJson();
    testClassCopy = Class.parse(json)!;

    testClassCopy.size = 1024;

    mockVmObject(mockClassObject);
    when(mockClassObject.obj).thenReturn(testClassCopy);
  });

  testWidgetsWithWindowSize('builds class display', windowSize,
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        VmClassDisplay(
          clazz: mockClassObject,
          controller: ObjectInspectorViewController(),
        ),
      ),
    );

    expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
    expect(find.byType(VMInfoCard), findsOneWidget);
    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.text('fooLib'), findsOneWidget);
    expect(find.text('fooScript.dart:10:4'), findsOneWidget);
    expect(find.text('fooSuperClass'), findsOneWidget);
    expect(find.text('fooSuperType'), findsOneWidget);
    expect(find.text('Currently allocated instances:'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    expect(find.byType(RequestableSizeWidget), findsNWidgets(2));

    expect(find.byType(RetainingPathWidget), findsOneWidget);

    expect(find.byType(InboundReferencesWidget), findsOneWidget);

    // TODO(mtaylee): test ClassInstancesWidget when implemented
  });
}
