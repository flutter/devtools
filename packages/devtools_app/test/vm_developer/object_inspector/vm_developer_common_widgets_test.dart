// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);

  late MockClassObject mockClassObject;

  late TestObjectInspectorViewController testObjectInspectorViewController;

  late FakeServiceManager fakeServiceManager;

  late InstanceRef requestedSize;

  final fetchingSizeNotifier = ValueNotifier<bool>(false);

  final retainingPathNotifier = ValueNotifier<RetainingPath?>(null);

  final inboundRefsNotifier = ValueNotifier<InboundReferences?>(null);

  setUp(() {
    fakeServiceManager = FakeServiceManager();

    setUpMockScriptManager();
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(PreferencesController, PreferencesController());

    mockClassObject = MockClassObject();

    testObjectInspectorViewController = TestObjectInspectorViewController();

    final json = testInstance.toJson();
    requestedSize = Instance.parse(json)!;

    when(mockClassObject.reachableSize).thenReturn(null);
    when(mockClassObject.retainedSize).thenReturn(null);

    // Intentionally unawaited.
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

    // Intentionally unawaited.
    // ignore: discarded_futures
    when(mockClassObject.requestRetainingPath()).thenAnswer((_) async {
      retainingPathNotifier.value = testRetainingPath;
    });

    when(mockClassObject.inboundReferences).thenReturn(inboundRefsNotifier);

    // Intentionally unawaited.
    // ignore: discarded_futures
    when(mockClassObject.requestInboundsRefs()).thenAnswer((_) async {
      inboundRefsNotifier.value = testInboundRefs;
    });
  });

  testWidgets(
    'test RequestableSizeWidget while fetching data',
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
    },
  );

  testWidgets('test RequestableSizeWidget', (WidgetTester tester) async {
    when(mockClassObject.reachableSize).thenReturn(requestedSize);
    await tester.pumpWidget(
      wrap(
        RequestableSizeWidget(
          fetching: fetchingSizeNotifier,
          sizeProvider: () => mockClassObject.reachableSize,
          requestFunction: mockClassObject.requestReachableSize,
        ),
      ),
    );

    expect(find.byIcon(Icons.refresh), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh));

    await tester.pumpAndSettle();

    expect(requestedSize.valueAsString, '1024');
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.byType(ToolbarRefresh), findsOneWidget);

    await tester.tap(find.byType(ToolbarRefresh));

    await tester.pumpAndSettle();

    expect(requestedSize.valueAsString, '1536');
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(find.byType(ToolbarRefresh), findsOneWidget);
  });

  testWidgetsWithWindowSize(
    'test RetainingPathWidget with null data',
    windowSize,
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          RetainingPathWidget(
            controller: testObjectInspectorViewController,
            retainingPath: mockClassObject.retainingPath,
            onExpanded: (bool _) {},
          ),
        ),
      );

      expect(find.byType(RetainingPathWidget), findsOneWidget);

      expect(find.text('Retaining Path'), findsOneWidget);

      await tester.tap(find.text('Retaining Path'));

      await tester.pump();

      expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'test RetainingPathWidget with fetched data',
    windowSize,
    (WidgetTester tester) async {
      retainingPathNotifier.value = null;

      await tester.pumpWidget(
        wrap(
          RetainingPathWidget(
            controller: testObjectInspectorViewController,
            retainingPath: mockClassObject.retainingPath,
            onExpanded: (bool _) {
              mockClassObject.requestRetainingPath();
            },
          ),
        ),
      );

      await tester.tap(find.text('Retaining Path'));

      await tester.pumpAndSettle();
      expect(find.text('FooClass', findRichText: true), findsOneWidget);
      expect(
        find.text(
          'Retained by element [1] of fooSuperClass',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text('Retained by \$1 of Record', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Retained by fooParentField of Record', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text(
          'Retained by element at [fooField] of fooSuperClass',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Retained by fooParentField of FooClass fooField of fooLib',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Retained by a GC root of type: class table',
          findRichText: true,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgetsWithWindowSize(
    'test InboundReferencesWidget with null data',
    windowSize,
    (WidgetTester tester) async {
      inboundRefsNotifier.value = null;

      await tester.pumpWidget(
        wrap(
          InboundReferencesWidget(
            inboundReferences: mockClassObject.inboundReferences,
            onExpanded: (bool _) {},
          ),
        ),
      );

      expect(find.text('Inbound References'), findsOneWidget);

      await tester.tap(find.text('Inbound References'));

      await tester.pump();

      expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgetsWithWindowSize(
    'test InboundReferencesWidget with data',
    windowSize,
    (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          InboundReferencesWidget(
            inboundReferences: mockClassObject.inboundReferences,
            onExpanded: (bool _) => mockClassObject.requestInboundsRefs(),
          ),
        ),
      );

      await tester.tap(find.text('Inbound References'));

      await tester.pumpAndSettle();
      expect(
        find.text('Referenced by fooFunction'),
        findsOneWidget,
      );
      expect(
        find.text('Referenced by fooParentField of fooType fooField of fooLib'),
        findsOneWidget,
      );
      expect(
        find.text('Referenced by fooParentField of fooRecord'),
        findsOneWidget,
      );
      expect(
        find.text('Referenced by \$1 of fooRecord'),
        findsOneWidget,
      );
      expect(
        find.text('Referenced by element [1] of fooSuperClass'),
        findsOneWidget,
      );
    },
  );
}
