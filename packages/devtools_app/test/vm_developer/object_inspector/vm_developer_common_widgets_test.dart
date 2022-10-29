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

  final fetchingSizeNotifier = ValueNotifier<bool>(false);

  final retainingPathNotifier = ValueNotifier<RetainingPath?>(null);

  final inboundRefsNotifier = ValueNotifier<InboundReferences?>(null);

  setUp(() {
    setGlobal(IdeTheme, IdeTheme());

    mockClassObject = MockClassObject();

    final json = testInstance.toJson();
    requestedSize = Instance.parse(json)!;

    when(mockClassObject.reachableSize).thenReturn(null);
    when(mockClassObject.retainedSize).thenReturn(null);

    // Intebtionally unwaited.
    // ignore: discarded_futures
    when(mockClassObject.requestReachableSize()).thenAnswer((_) async {
      fetchingSizeNotifier.value = true;

      if (requestedSize.valueAsString == null) {
        requestedSize.valueAsString = '1024';
      } else {
        int value = int.parse(requestedSize.valueAsString!);
        value += 512;
        requestedSize.valueAsString = value.toString();
      }

      fetchingSizeNotifier.value = false;
    });

    when(mockClassObject.retainingPath).thenReturn(retainingPathNotifier);

    // Intebtionally unwaited.
    // ignore: discarded_futures
    when(mockClassObject.requestRetainingPath()).thenAnswer((_) async {
      retainingPathNotifier.value = testRetainingPath;
    });

    when(mockClassObject.inboundReferences).thenReturn(inboundRefsNotifier);

    // Intebtionally unwaited.
    // ignore: discarded_futures
    when(mockClassObject.requestInboundsRefs()).thenAnswer((_) async {
      inboundRefsNotifier.value = testInboundRefs;
    });
  });

  testWidgets('test RequestableSizeWidget while fetching data',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RequestableSizeWidget(
          fetching: ValueNotifier(true),
          sizeProvider: () => mockClassObject.reachableSize,
          requestFunction: mockClassObject.requestReachableSize,
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('test RequestableSizeWidget', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RequestableSizeWidget(
          fetching: fetchingSizeNotifier,
          sizeProvider: () => mockClassObject.reachableSize,
          requestFunction: mockClassObject.requestReachableSize,
        ),
      ),
    );

    expect(find.byType(RequestDataButton), findsOneWidget);

    when(mockClassObject.reachableSize).thenReturn(requestedSize);

    await tester.tap(find.byType(RequestDataButton));

    await tester.pumpAndSettle();

    expect(requestedSize.valueAsString, '1024');
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.byType(ToolbarRefresh), findsOneWidget);

    await tester.tap(find.byType(ToolbarRefresh));

    await tester.pumpAndSettle();

    expect(requestedSize.valueAsString, '1536');
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(find.byType(ToolbarRefresh), findsOneWidget);
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
