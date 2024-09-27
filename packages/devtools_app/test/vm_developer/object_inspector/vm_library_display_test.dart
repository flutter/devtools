// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/object_inspector/vm_library_display.dart';
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
  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(BreakpointManager, BreakpointManager());
    setGlobal(ServiceConnectionManager, FakeServiceConnectionManager());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(NotificationService, NotificationService());
  });
  group('test build library display', () {
    late Library testLibCopy;

    late MockLibraryObject mockLibraryObject;

    const windowSize = Size(4000.0, 4000.0);

    setUpAll(() {
      setUpMockScriptManager();
      mockLibraryObject = MockLibraryObject();

      final json = testLib.toJson();
      testLibCopy = Library.parse(json)!;

      testLibCopy.size = 1024;

      mockVmObject(mockLibraryObject);
      when(mockLibraryObject.obj).thenReturn(testLibCopy);
      when(mockLibraryObject.vmName).thenReturn('fooDartLibrary');
      when(mockLibraryObject.scriptRef).thenReturn(testScript);
    });

    testWidgetsWithWindowSize(
      ' - basic layout',
      windowSize,
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrap(
            VmLibraryDisplay(
              library: mockLibraryObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
        expect(find.byType(VMInfoCard), findsOneWidget);
        expect(find.text('General Information'), findsOneWidget);
        expect(find.text('1.0 KB'), findsOneWidget);
        expect(find.text('URI:'), findsOneWidget);
        expect(find.text('fooLib.dart', findRichText: true), findsOneWidget);
        expect(find.text('VM Name:'), findsOneWidget);
        expect(find.text('fooDartLibrary'), findsOneWidget);

        expect(find.byType(RequestableSizeWidget), findsNWidgets(2));

        expect(find.byType(RetainingPathWidget), findsOneWidget);

        expect(find.byType(InboundReferencesTree), findsOneWidget);

        expect(find.byType(LibraryDependencies), findsOneWidget);
      },
    );

    testWidgetsWithWindowSize(
      ' - with null dependencies',
      windowSize,
      (WidgetTester tester) async {
        testLibCopy.dependencies = null;

        await tester.pumpWidget(
          wrap(
            VmLibraryDisplay(
              library: mockLibraryObject,
              controller: ObjectInspectorViewController(),
            ),
          ),
        );

        expect(find.byType(LibraryDependencies), findsNothing);
      },
    );
  });

  group('test LibraryDependencyExtension description method: ', () {
    late Library targetLib1;
    late Library targetLib2;
    late Library targetLib3;
    late LibraryDependency dependency1;
    late LibraryDependency dependency2;
    late LibraryDependency dependency3;

    setUpAll(() {
      final libJson = testLib.toJson();

      targetLib1 = Library.parse(libJson)!;
      targetLib2 = Library.parse(libJson)!;
      targetLib3 = Library.parse(libJson)!;

      targetLib1.name = 'dart:core';
      targetLib2.name = 'dart:math';
      targetLib3.name = 'dart:collection';

      dependency1 = LibraryDependency(
        isImport: true,
        target: targetLib1,
      );

      dependency2 = LibraryDependency(
        isImport: false,
        target: targetLib2,
      );

      dependency3 = LibraryDependency(
        target: targetLib3,
      );

      dependency1.target = targetLib1;
      dependency2.target = targetLib2;
    });

    test('just the libraries', () {
      expect(dependency1.description, 'import dart:core');
      expect(dependency2.description, 'export dart:math');
      expect(dependency3.description, 'dart:collection');
    });

    test('libraries with prefix', () {
      dependency1.prefix = 'core';
      dependency2.prefix = 'math';
      dependency3.prefix = 'collection';

      expect(dependency1.description, 'import dart:core as core');
      expect(dependency2.description, 'export dart:math as math');
      expect(dependency3.description, 'dart:collection as collection');
    });

    test('libraries with prefix and deferred', () {
      dependency1.isDeferred = true;
      dependency2.isDeferred = true;
      dependency3.isDeferred = true;

      expect(dependency1.description, 'import dart:core as core deferred');
      expect(dependency2.description, 'export dart:math as math deferred');
      expect(dependency3.description, 'dart:collection as collection deferred');
    });

    test('libraries deferred', () {
      dependency1.prefix = null;
      dependency2.prefix = null;
      dependency3.prefix = null;

      expect(dependency1.description, 'import dart:core deferred');
      expect(dependency2.description, 'export dart:math deferred');
      expect(dependency3.description, 'dart:collection deferred');
    });

    test('target library is missing', () {
      dependency1.target = null;
      dependency1.prefix = 'foo';
      dependency1.isDeferred = null;

      expect(dependency1.description, 'import <Library name> as foo');
    });
  });

  group('test LibraryDependencies widget: ', () {
    late LibraryDependency dependency;

    late List<LibraryDependency> dependencies;

    setUpAll(() {
      dependency = LibraryDependency(
        isImport: true,
        target: testLib,
      );

      dependencies = [dependency, dependency, dependency];
    });

    testWidgets('builds widget', (WidgetTester tester) async {
      await tester
          .pumpWidget(wrap(LibraryDependencies(dependencies: dependencies)));

      expect(find.byType(VmExpansionTile), findsOneWidget);
      expect(find.text('Dependencies (3)'), findsOneWidget);

      await tester.tap(find.text('Dependencies (3)'));

      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsNWidgets(3));
    });
  });
}
