// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../../test_infra/utils/tree_utils.dart';

void main() {
  const windowSize = Size(2560.0, 1338.0);

  late FakeObjectInspectorViewController objectInspectorViewController;

  final lib = LibraryRef(
    id: 'lib/2',
    uri: 'foo.dart',
  );
  final objectCls = Class(
    id: 'cls/1',
    name: 'Object',
    library: LibraryRef(
      id: 'lib/0',
      uri: 'dart:core',
    ),
  );
  final superCls = Class(
    id: 'cls/2',
    name: 'Super',
    superClass: objectCls,
    library: lib,
  );
  final subCls = Class(
    id: 'cls/3',
    name: 'Sub',
    superClass: superCls,
    library: lib,
  );
  final noSubCls = Class(
    id: 'cls/4',
    name: 'NoSub',
    superClass: objectCls,
    library: lib,
  );

  final classes = <Class>[
    objectCls,
    superCls,
    subCls,
    noSubCls,
  ];

  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());

    objectInspectorViewController = FakeObjectInspectorViewController();
    objectInspectorViewController.classHierarchyController
        .buildHierarchy(classes);
  });

  test('Correctly builds class hierarchy', () {
    final controller = objectInspectorViewController.classHierarchyController;

    // The resulting class hierarchy should look like this:
    //   - Object
    //     - NoSub
    //     - Super
    //       - Sub
    final hierarchy = controller.selectedIsolateClassHierarchy.value;
    expect(hierarchy.numNodes, classes.length);
    expect(hierarchy.length, 1);

    final objNode = hierarchy.first;
    expect(objNode.children.length, 2);
    expect(objNode.isExpandable, true);
    expect(
      objNode.children.map((e) => e.cls),
      containsAllInOrder([noSubCls, superCls]),
    );
    expect(
      objNode.children.fold<int>(0, (p, e) => p + (e.isExpandable ? 1 : 0)),
      1,
    );

    final superNode = objNode.children.firstWhere(
      (element) => element.cls == superCls,
    );
    expect(superNode.children.length, 1);
    expect(superNode.children.first.cls, subCls);
    expect(superNode.children.first.isExpandable, false);
  });

  testWidgetsWithWindowSize(
    'Correctly renders class hierarchy',
    windowSize,
    (tester) async {
      final controller = objectInspectorViewController.classHierarchyController;
      await tester.pumpWidget(
        wrapSimple(
          ClassHierarchyExplorer(
            controller: objectInspectorViewController,
          ),
        ),
      );

      expect(find.text('Object', findRichText: true), findsOneWidget);

      controller.selectedIsolateClassHierarchy.value.first.expandCascading();
      (controller.selectedIsolateClassHierarchy as ValueNotifier)
          .notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text('Object', findRichText: true), findsOneWidget);
      expect(find.text('Super', findRichText: true), findsOneWidget);
      expect(find.text('Sub', findRichText: true), findsOneWidget);
      expect(find.text('NoSub', findRichText: true), findsOneWidget);

      expect(
        find.byType(VmServiceObjectLink),
        findsNWidgets(classes.length),
      );
    },
  );
}
