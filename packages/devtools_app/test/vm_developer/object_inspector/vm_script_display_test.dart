// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_script_display.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late MockScriptObject mockScriptObject;

  const windowSize = Size(4000.0, 4000.0);

  late Script testScriptCopy;

  setUp(() {
    setGlobal(IdeTheme, IdeTheme());

    mockScriptObject = MockScriptObject();

    final json = testScript.toJson();
    testScriptCopy = Script.parse(json)!;

    testScriptCopy.size = 1024;

    mockVmObject(mockScriptObject);
    when(mockScriptObject.obj).thenReturn(testScriptCopy);
  });

  testWidgetsWithWindowSize('builds script display', windowSize,
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(VmScriptDisplay(script: mockScriptObject)));

    expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
    expect(find.byType(VMInfoCard), findsOneWidget);
    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.text('Library:'), findsOneWidget);
    expect(find.text('fooLib'), findsOneWidget);
    expect(find.text('URI:'), findsOneWidget);
    expect(find.text('fooScript.dart'), findsOneWidget);
    expect(find.text('Load time:'), findsOneWidget);
    expect(find.text('2022-08-10 06:30:00.000'), findsOneWidget);

    expect(find.byType(RequestableSizeWidget), findsNWidgets(2));

    expect(find.byType(RetainingPathWidget), findsOneWidget);

    expect(find.byType(InboundReferencesWidget), findsOneWidget);
  });
}
