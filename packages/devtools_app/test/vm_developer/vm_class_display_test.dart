// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_class_display.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  final mockClassObject = MockClassObject();
  final mockClass = MockClass();

  final fakelib = LibraryRef(name: 'fooLib', uri: 'fooLib.dart', id: '1234');

  final fakeClassRef = ClassRef(name: 'FooClass', library: fakelib, id: '1234');
  final fakeSuperClass =
      ClassRef(name: 'fooSuperClass', library: fakelib, id: '1234');
  final fakeSuperType = InstanceRef(
    kind: '',
    identityHashCode: null,
    classRef: null,
    id: '1234',
    name: 'fooSuperType',
  );
  final fakeScript = Script(uri: 'fooClass.dart', library: fakelib, id: '1234');
  const fakePos = SourcePosition(line: 10, column: 4);
  final fakeInstances = InstanceSet(instances: null, totalCount: 3);

  when(mockClassObject.name).thenReturn('FooClass');
  when(mockClassObject.ref).thenReturn(fakeClassRef);
  when(mockClassObject.obj).thenReturn(mockClass);
  when(mockClassObject.script).thenReturn(fakeScript);
  when(mockClassObject.instances).thenReturn(fakeInstances);
  when(mockClassObject.pos).thenReturn(fakePos);

  when(mockClass.type).thenReturn('Class');
  when(mockClass.size).thenReturn(1024);
  when(mockClass.library).thenReturn(fakelib);
  when(mockClass.superType).thenReturn(fakeSuperType);
  when(mockClass.superClass).thenReturn(fakeSuperClass);

  const windowSize = Size(4000.0, 4000.0);
  const smallWindowSize = Size(1100.0, 1100.0);

  setUp(() {
    setGlobal(IdeTheme, IdeTheme());
  });

  testWidgets('builds class display', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(VmClassDisplay(clazz: mockClassObject)));
    expect(find.bySubtype<VMInfoCard>(), findsNWidgets(2));
    expect(find.text('General Information'), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.text('fooLib'), findsOneWidget);
    expect(find.text('fooClass.dart:10:4'), findsOneWidget);
    expect(find.text('fooSuperClass'), findsOneWidget);
    expect(find.text('fooSuperType'), findsOneWidget);
    expect(find.text('Class Instances'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
