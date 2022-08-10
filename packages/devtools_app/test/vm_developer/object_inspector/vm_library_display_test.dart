// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_library_display.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late MockLibraryObject mockLibraryObject;

  const windowSize = Size(4000.0, 4000.0);

  late Library testLibCopy;

  setUp(() {
    setGlobal(IdeTheme, IdeTheme());

    mockLibraryObject = MockLibraryObject();

    final json = testLib.toJson();
    testLibCopy = Library.parse(json)!;

    testLibCopy.size = 1024;

    mockVmObject(mockLibraryObject);
    when(mockLibraryObject.obj).thenReturn(testLibCopy);
    when(mockLibraryObject.vmName).thenReturn('fooDartLibrary');
  });

  group('test build library display', () {
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

  group('test LibraryDependencies widget', () {
    //TODO
  });
}
