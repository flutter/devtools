// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/primitives/listenable.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/flex_split_column.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late MockProgramExplorerController mockProgramExplorerController;

  setUp(() {
    final fakeServiceManager = FakeServiceManager();
    mockConnectedApp(
      fakeServiceManager.connectedApp!,
      isFlutterApp: true,
      isProfileBuild: false,
      isWebApp: false,
    );
    mockProgramExplorerController =
        createMockProgramExplorerControllerWithDefaults();
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ServiceConnectionManager, fakeServiceManager);
  });

  testWidgets('builds when not initialized', (WidgetTester tester) async {
    when(mockProgramExplorerController.initialized)
        .thenReturn(const FixedValueListenable(false));
    await tester.pumpWidget(
      wrap(
        ProgramExplorer(controller: mockProgramExplorerController),
      ),
    );
    expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
  });

  testWidgets('builds when initialized', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        ProgramExplorer(controller: mockProgramExplorerController),
      ),
    );
    expect(find.byType(AreaPaneHeader), findsNWidgets(2));
    expect(find.text('File Explorer'), findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);
    expect(find.byType(FlexSplitColumn), findsOneWidget);
  });

  // TODO(https://github.com/flutter/devtools/issues/4227): write more thorough
  // tests for the ProgramExplorer widget.
}
