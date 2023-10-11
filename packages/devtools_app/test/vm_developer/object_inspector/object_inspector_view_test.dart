// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/object_inspector_view.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/object_viewport.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late ObjectInspectorView objectInspector;

  late FakeServiceConnectionManager fakeServiceConnection;

  late MockScriptManager scriptManager;

  const windowSize = Size(2560.0, 1338.0);

  setUp(() {
    objectInspector = ObjectInspectorView();
    fakeServiceConnection = FakeServiceConnectionManager();
    scriptManager = MockScriptManager();

    when(scriptManager.sortedScripts).thenReturn(
      ValueNotifier(<ScriptRef>[testScript]),
    );
    // ignore: discarded_futures, test code.
    when(scriptManager.retrieveAndSortScripts(any)).thenAnswer(
      (_) => Future.value([testScript]),
    );
    when(fakeServiceConnection.serviceManager.connectedApp!.isProfileBuildNow)
        .thenReturn(false);
    when(fakeServiceConnection.serviceManager.connectedApp!.isDartWebAppNow)
        .thenReturn(false);

    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(ScriptManager, scriptManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());

    VmServiceWrapper.enablePrivateRpcs = true;
  });

  testWidgetsWithWindowSize(
    'builds screen',
    windowSize,
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(
            builder: objectInspector.build,
          ),
          vmDeveloperTools: VMDeveloperToolsController(
            objectInspectorViewController: ObjectInspectorViewController(
              classHierarchyController: TestClassHierarchyExplorerController(),
            ),
          ),
        ),
      );
      expect(find.byType(Split), findsNWidgets(2));
      expect(find.byType(ProgramExplorer), findsOneWidget);
      expect(find.byType(ObjectViewport), findsOneWidget);
      expect(find.text('Program Explorer'), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('No object selected.'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);
    },
  );
}
