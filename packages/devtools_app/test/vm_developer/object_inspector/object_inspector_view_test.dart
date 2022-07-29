// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector_view.dart';
import 'package:devtools_app/src/screens/vm_developer/object_viewport.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  late final ObjectInspectorView objectInspector;

  late final FakeServiceManager fakeServiceManager;

  late MockScriptManager scriptManager;

  setUp(() {
    objectInspector = ObjectInspectorView();

    fakeServiceManager = FakeServiceManager();

    scriptManager = MockScriptManager();
    when(scriptManager.sortedScripts).thenReturn(ValueNotifier(<ScriptRef>[]));

    when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);

    setGlobal(ServiceConnectionManager, fakeServiceManager);

    setGlobal(ScriptManager, scriptManager);

    setGlobal(IdeTheme, IdeTheme());
  });

  testWidgets('builds screen', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(Builder(builder: objectInspector.build)));
    expect(find.byType(Split), findsNWidgets(2));
    expect(find.byType(ProgramExplorer), findsOneWidget);
    expect(find.byType(ObjectViewport), findsOneWidget);
    expect(find.text('Program Explorer'), findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('No object selected.'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });
}
