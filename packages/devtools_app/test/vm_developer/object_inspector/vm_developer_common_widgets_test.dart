// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);

  late MockClassObject mockClassObject;

  late InstanceRef requestedSize;

  final retainingPathNotifier = ValueNotifier<RetainingPath?>(null);

  final inboundRefsNotifier = ValueNotifier<InboundReferences?>(null);

  setUp(() {
    setGlobal(IdeTheme, IdeTheme());

    mockClassObject = MockClassObject();

    final json = testInstance.toJson();
    requestedSize = Instance.parse(json)!;

    when(mockClassObject.reachableSize).thenReturn(requestedSize);

    when(mockClassObject.requestReachableSize()).thenAnswer((_) async {
      requestedSize.valueAsString = '1024';
    });

    when(mockClassObject.retainingPath).thenReturn(retainingPathNotifier);

    when(mockClassObject.requestRetainingPath()).thenAnswer((_) async {
      retainingPathNotifier.value = testRetainingPath;
    });

    when(mockClassObject.inboundReferences).thenReturn(inboundRefsNotifier);

    when(mockClassObject.requestInboundsRefs()).thenAnswer((_) async {
      inboundRefsNotifier.value = testInboundRefs;
    });
  });

  testWidgets('test RequestableSizeWidget with null data',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RequestableSizeWidget(
          requestedSize: null,
          requestFunction: mockClassObject.requestReachableSize,
        ),
      ),
    );

    expect(find.byType(RequestDataButton), findsOneWidget);

    await tester.tap(find.byType(RequestDataButton));

    expect(requestedSize.valueAsString, '1024');
  });

  testWidgets('test RequestableSizeWidget with data',
      (WidgetTester tester) async {
    requestedSize.valueAsString = '128';

    final sizeNotifier = ValueNotifier<InstanceRef?>(requestedSize);

    await tester.pumpWidget(
      wrap(
        ValueListenableBuilder(
          valueListenable: sizeNotifier,
          builder: (context, size, _) {
            return RequestableSizeWidget(
              requestedSize: requestedSize,
              requestFunction: () {
                mockClassObject.requestReachableSize();
                sizeNotifier.notifyListeners();
              },
            );
          },
        ),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
    expect(find.text('128 B'), findsOneWidget);
    expect(find.byType(ToolbarRefresh), findsOneWidget);

    await tester.tap(find.byType(ToolbarRefresh));

    await tester.pumpAndSettle();

    expect(find.text('1 KB'), findsOneWidget);
  });

  testWidgetsWithWindowSize(
      'test RetainingPathWidget with null data', windowSize,
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RetainingPathWidget(
          retainingPath: mockClassObject.retainingPath,
          onExpanded: (bool) => null,
        ),
      ),
    );

    expect(find.byType(AreaPaneHeader), findsOneWidget);

    expect(find.text('Retaining Path'), findsOneWidget);

    await tester.tap(find.byType(AreaPaneHeader));

    await tester.pump();

    expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
  });

  testWidgetsWithWindowSize(
      'test RetainingPathWidget with fetched data', windowSize,
      (WidgetTester tester) async {
    retainingPathNotifier.value = null;

    await tester.pumpWidget(
      wrap(
        RetainingPathWidget(
          retainingPath: mockClassObject.retainingPath,
          onExpanded: (bool) {
            mockClassObject.requestRetainingPath();
          },
        ),
      ),
    );

    await tester.tap(find.byType(AreaPaneHeader));

    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsNWidgets(5));
    expect(find.text('FooClass'), findsOneWidget);
    expect(
      find.text('Retained by element [1] of <parentListName>'),
      findsOneWidget,
    );
    expect(
      find.text('Retained by element at [fooField] of <parentMapName>'),
      findsOneWidget,
    );
    expect(
      find.text('Retained by fooParentField of Field fooField of fooLib'),
      findsOneWidget,
    );
    expect(
      find.text('Retained by a GC root of type class table'),
      findsOneWidget,
    );
  });

  testWidgetsWithWindowSize(
      'test InboundReferencesWidget with null data', windowSize,
      (WidgetTester tester) async {
    inboundRefsNotifier.value = null;

    await tester.pumpWidget(
      wrap(
        InboundReferencesWidget(
          inboundReferences: mockClassObject.inboundReferences,
          onExpanded: (bool) => null,
        ),
      ),
    );

    expect(find.byType(AreaPaneHeader), findsOneWidget);

    expect(find.text('Inbound References'), findsOneWidget);

    await tester.tap(find.byType(AreaPaneHeader));

    await tester.pump();

    expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
  });

  testWidgetsWithWindowSize(
      'test InboundReferencesWidget with data', windowSize,
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        InboundReferencesWidget(
          inboundReferences: mockClassObject.inboundReferences,
          onExpanded: (bool) => mockClassObject.requestInboundsRefs(),
        ),
      ),
    );

    await tester.tap(find.byType(AreaPaneHeader));

    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsNWidgets(3));
    expect(
      find.text('Referenced by fooFunction'),
      findsOneWidget,
    );
    expect(
      find.text('Referenced by fooParentField of Field fooField of fooLib'),
      findsOneWidget,
    );
    expect(
      find.text('Referenced by element [1] of <parentListName>'),
      findsOneWidget,
    );
  });
}
