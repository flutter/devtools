// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_library_display.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
  });
  group('test build library display', () {
    late Library testLibCopy;

    late MockLibraryObject mockLibraryObject;

    const windowSize = Size(4000.0, 4000.0);

    setUpAll(() {
      mockLibraryObject = MockLibraryObject();

      final json = testLib.toJson();
      testLibCopy = Library.parse(json)!;

      testLibCopy.size = 1024;

      mockVmObject(mockLibraryObject);
      when(mockLibraryObject.obj).thenReturn(testLibCopy);
      when(mockLibraryObject.vmName).thenReturn('fooDartLibrary');
    });

    testWidgetsWithWindowSize(' - basic layout', windowSize,
        (WidgetTester tester) async {
      await tester
          .pumpWidget(wrap(VmLibraryDisplay(library: mockLibraryObject)));

      expect(find.byType(VmObjectDisplayBasicLayout), findsOneWidget);
      expect(find.byType(VMInfoCard), findsOneWidget);
      expect(find.text('General Information'), findsOneWidget);
      expect(find.text('1 KB'), findsOneWidget);
      expect(find.text('URI:'), findsOneWidget);
      expect(find.text('fooLib.dart'), findsOneWidget);
      expect(find.text('VM Name:'), findsOneWidget);
      expect(find.text('fooDartLibrary'), findsOneWidget);

      expect(find.byType(RequestableSizeWidget), findsNWidgets(2));

      expect(find.byType(RetainingPathWidget), findsOneWidget);

      expect(find.byType(InboundReferencesWidget), findsOneWidget);

      expect(find.byType(LibraryDependencies), findsOneWidget);
    });

    testWidgetsWithWindowSize(' - with null dependencies', windowSize,
        (WidgetTester tester) async {
      testLibCopy.dependencies = null;

      await tester
          .pumpWidget(wrap(VmLibraryDisplay(library: mockLibraryObject)));

      expect(find.byType(LibraryDependencies), findsNothing);
    });
  });

  group('test LibraryDependencies widget: ', () {
    late Library targetLib1;
    late Library targetLib2;
    late Library targetLib3;
    late LibraryDependency dependency1;
    late LibraryDependency dependency2;
    late LibraryDependency dependency3;

    late List<LibraryDependency> dependencies;

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

      dependencies = [
        dependency1,
        dependency2,
        dependency3,
      ];
    });

    testWidgets('just the libraries', (WidgetTester tester) async {
      await tester
          .pumpWidget(wrap(LibraryDependencies(dependencies: dependencies)));

      expect(find.text('Dependencies (3)'), findsOneWidget);

      await tester.tap(find.byType(AreaPaneHeader));

      await tester.pumpAndSettle();

      expect(find.text('import dart:core'), findsOneWidget);
      expect(find.text('export dart:math'), findsOneWidget);
      expect(find.text('dart:collection'), findsOneWidget);
    });

    testWidgets('libraries with prefix', (WidgetTester tester) async {
      dependency1.prefix = 'core';
      dependency2.prefix = 'math';
      dependency3.prefix = 'collection';

      await tester
          .pumpWidget(wrap(LibraryDependencies(dependencies: dependencies)));

      expect(find.text('Dependencies (3)'), findsOneWidget);

      await tester.tap(find.byType(AreaPaneHeader));

      await tester.pumpAndSettle();

      expect(find.text('import dart:core as core'), findsOneWidget);
      expect(find.text('export dart:math as math'), findsOneWidget);
      expect(find.text('dart:collection as collection'), findsOneWidget);
    });

    testWidgets('libraries with prefix and deferred',
        (WidgetTester tester) async {
      dependency1.isDeferred = true;
      dependency2.isDeferred = true;
      dependency3.isDeferred = true;

      await tester
          .pumpWidget(wrap(LibraryDependencies(dependencies: dependencies)));

      expect(find.text('Dependencies (3)'), findsOneWidget);

      await tester.tap(find.byType(AreaPaneHeader));

      await tester.pumpAndSettle();

      expect(find.text('import dart:core as core deferred'), findsOneWidget);
      expect(find.text('export dart:math as math deferred'), findsOneWidget);
      expect(
          find.text('dart:collection as collection deferred'), findsOneWidget);
    });

    testWidgets('libraries deferred', (WidgetTester tester) async {
      dependency1.prefix = null;
      dependency2.prefix = null;
      dependency3.prefix = null;

      await tester
          .pumpWidget(wrap(LibraryDependencies(dependencies: dependencies)));

      expect(find.text('Dependencies (3)'), findsOneWidget);

      await tester.tap(find.byType(AreaPaneHeader));

      await tester.pumpAndSettle();

      expect(find.text('import dart:core deferred'), findsOneWidget);
      expect(find.text('export dart:math deferred'), findsOneWidget);
      expect(find.text('dart:collection deferred'), findsOneWidget);
    });

    testWidgets('target library is missing', (WidgetTester tester) async {
      dependency1.target = null;
      dependency1.prefix = 'foo';
      dependency1.isDeferred = null;

      await tester
          .pumpWidget(wrap(LibraryDependencies(dependencies: [dependency1])));

      expect(find.text('Dependencies (1)'), findsOneWidget);

      await tester.tap(find.byType(AreaPaneHeader));

      await tester.pumpAndSettle();

      expect(find.text('import <Library name> as foo'), findsOneWidget);
    });
  });
}
