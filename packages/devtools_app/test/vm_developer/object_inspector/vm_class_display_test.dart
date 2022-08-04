// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_class_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  late MockClassObject mockClassObject;

  const windowSize = Size(4000.0, 4000.0);

  late Class testClassCopy;

  setUp(() {
    setGlobal(IdeTheme, IdeTheme());

    mockClassObject = MockClassObject();

    final json = testClass.toJson();
    testClassCopy = Class.parse(json)!;

    testClassCopy.size = 1024;

    when(mockClassObject.outlineNode).thenReturn(null);
    when(mockClassObject.scriptRef).thenReturn(null);
    when(mockClassObject.name).thenReturn('FooClass');
    when(mockClassObject.ref).thenReturn(testClass);
    when(mockClassObject.obj).thenReturn(testClassCopy);
    when(mockClassObject.script).thenReturn(testScript);
    when(mockClassObject.instances).thenReturn(testInstances);
    when(mockClassObject.pos).thenReturn(testPos);
    when(mockClassObject.fetchingReachableSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockClassObject.reachableSize).thenReturn(ValueNotifier(null));
    when(mockClassObject.fetchingRetainedSize)
        .thenReturn(ValueNotifier<bool>(false));
    when(mockClassObject.retainedSize).thenReturn(ValueNotifier(null));
    when(mockClassObject.retainingPath).thenReturn(
      ValueNotifier<RetainingPath?>(testRetainingPath),
    );
    when(mockClassObject.inboundReferences).thenReturn(
      ValueNotifier<InboundReferences?>(testInboundRefs),
    );
  });

  testWidgetsWithWindowSize('builds class display', windowSize,
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(VmClassDisplay(clazz: mockClassObject)));

    expect(find.byType(ClassInfoWidget), findsOneWidget);
    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.text('fooLib'), findsOneWidget);
    expect(find.text('fooScript.dart:10:4'), findsOneWidget);
    expect(find.text('fooSuperClass'), findsOneWidget);
    expect(find.text('fooSuperType'), findsOneWidget);
    expect(find.text('Currently allocated instances:'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    expect(find.byType(RequestableSizeWidget), findsNWidgets(2));

    expect(find.byType(RetainingPathWidget), findsOneWidget);

    expect(find.byType(InboundReferencesWidget), findsOneWidget);

    // TODO(mtaylee): test ClassInstancesWidget when implemented
    // expect(find.byType(ClassInstancesWidget), findsOneWidget);
  });
}
