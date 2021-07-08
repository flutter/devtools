// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/inspector/inspector_service.dart';
import 'package:devtools_app/src/inspector/inspector_tree.dart';
import 'package:devtools_app/src/inspector/inspector_tree_flutter.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Fake;
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';
import 'support/wrappers.dart';

void main() {
  FakeServiceManager fakeServiceManager;
  group('InspectorTreeController', () {
    setUp(() {
      fakeServiceManager = FakeServiceManager();
      when(fakeServiceManager.connectedApp.isFlutterAppNow).thenReturn(true);
      when(fakeServiceManager.connectedApp.isProfileBuildNow).thenReturn(false);

      setGlobal(ServiceConnectionManager, fakeServiceManager);
      mockIsFlutterApp(serviceManager.connectedApp);
    });

    testWidgets('Row with negative index regression test',
        (WidgetTester tester) async {
      final controller = InspectorTreeControllerFlutter()
        ..config = InspectorTreeConfig(
          summaryTree: false,
          treeType: FlutterTreeType.widget,
          onNodeAdded: (_, __) {},
          onClientActiveChange: (_) {},
        );
      await tester.pumpWidget(wrap(InspectorTree(controller: controller)));

      expect(controller.getRow(const Offset(0, -100.0)), isNull);
      expect(controller.getRowOffset(-1), equals(0));

      expect(controller.getRow(const Offset(0, 0.0)), isNull);
      expect(controller.getRowOffset(0), equals(0));

      controller.root = InspectorTreeNode()..appendChild(InspectorTreeNode());
      await tester.pumpWidget(wrap(InspectorTree(controller: controller)));

      expect(controller.getRow(const Offset(0, -20)), isNull);
      expect(controller.getRowOffset(-1), equals(0));
      expect(controller.getRow(const Offset(0, 0.0)), isNotNull);
      expect(controller.getRowOffset(0), equals(0));

      // This operation would previously throw an exception in debug builds
      // and infinite loop in release builds.
      controller.scrollToRect(const Rect.fromLTWH(0, -20, 100, 100));
    });
  });
}
