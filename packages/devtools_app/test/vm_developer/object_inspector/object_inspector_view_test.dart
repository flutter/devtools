// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector_view.dart';
import 'package:devtools_app/src/screens/vm_developer/object_viewport.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_tools_controller.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_tools_screen.dart';
import 'package:devtools_app/src/scripts/script_manager.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/split.dart';
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
    displayObjectInspector = true;
    objectInspector = ObjectInspectorView();
    fakeServiceManager = FakeServiceManager();
    scriptManager = MockScriptManager();

    when(scriptManager.sortedScripts).thenReturn(ValueNotifier(<ScriptRef>[]));
    when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);

    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(ScriptManager, scriptManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());
  });

  tearDown(() {
    displayObjectInspector = false;
  });

  testWidgets('builds screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithControllers(
        Builder(
          builder: objectInspector.build,
        ),
        vmDeveloperTools: VMDeveloperToolsController(),
      ),
    );
    expect(find.byType(Split), findsNWidgets(2));
    expect(find.byType(ProgramExplorer), findsOneWidget);
    expect(find.byType(ObjectViewport), findsOneWidget);
    expect(find.text('Program Explorer'), findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('No object selected.'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });
}
