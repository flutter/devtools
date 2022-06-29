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

void main() {
  final objectInspector = ObjectInspectorView();

  const windowSize = Size(4000.0, 4000.0);
  const smallWindowSize = Size(1100.0, 1100.0);

  final fakeServiceManager = FakeServiceManager();
  when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
  when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());

  testWidgets('builds screen', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(Builder(builder: objectInspector.build)));
    expect(find.bySubtype<Split>(), findsNWidgets(2));
    expect(find.bySubtype<ProgramExplorer>(), findsOneWidget);
    expect(find.bySubtype<ObjectViewport>(), findsOneWidget);
    expect(find.text('Program Explorer'), findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);
    expect(find.text('No object selected.'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });
}
