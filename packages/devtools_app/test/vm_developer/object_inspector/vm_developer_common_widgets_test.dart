// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/vm_developer/vm_developer_common_widgets.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_test_utils.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);

  late InstanceRef requestedSize;

  int size = 0;

  late void Function() requestFunction;

  bool fetchRetainingPath = false;

  late ValueNotifier<RetainingPath?> retainingPathNotifier;

  late void Function(bool) fetchRetainingPathFunc;

  bool fetchInboundRefs = false;

  late ValueNotifier<InboundReferences?> inboundRefsNotifier;

  late void Function(bool) fetchinboundRefsFunc;

  setUp(() {
    setGlobal(IdeTheme, IdeTheme());

    final json = testInstance.toJson();
    requestedSize = Instance.parse(json)!;
    requestedSize.valueAsString = '1024';

    requestFunction = () {
      requestedSize.valueAsString = size.toString();
      size++;
    };

    retainingPathNotifier = ValueNotifier<RetainingPath?>(null);

    fetchRetainingPathFunc = (bool) {
      if (fetchRetainingPath) {
        retainingPathNotifier.value = testRetainingPath;
      } else {
        fetchRetainingPath = true;
      }
    };

    inboundRefsNotifier = ValueNotifier<InboundReferences?>(null);

    fetchinboundRefsFunc = (bool) {
      if (fetchInboundRefs) {
        inboundRefsNotifier.value = testInboundRefs;
      } else {
        fetchInboundRefs = true;
      }
    };
  });

  testWidgets('test RequestableSizeWidget with null data',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        RequestableSizeWidget(
          requestedSize: null,
          requestFunction: requestFunction,
        ),
      ),
    );

    expect(find.byType(RequestDataButton), findsOneWidget);

    await tester.tap(find.byType(RequestDataButton));

    expect(size, 1);
  });

  testWidgets('test RequestableSizeWidget with data',
      (WidgetTester tester) async {
    size = 100;
    await tester.pumpWidget(
      wrap(
        RequestableSizeWidget(
          requestedSize: requestedSize,
          requestFunction: requestFunction,
        ),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
    expect(find.text('1 KB'), findsOneWidget);
    expect(find.byType(ToolbarRefresh), findsOneWidget);

    await tester.tap(find.byType(ToolbarRefresh));

    await tester.pumpWidget(
      wrap(
        RequestableSizeWidget(
          requestedSize: requestedSize,
          requestFunction: requestFunction,
        ),
      ),
    );

    expect(find.text('100 B'), findsOneWidget);

    expect(size, 101);
  });

  testWidgetsWithWindowSize('test RetainingPathWidget', windowSize,
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            Flexible(
              child: RetainingPathWidget(
                retainingPath: retainingPathNotifier,
                onExpanded: fetchRetainingPathFunc,
              ),
            )
          ],
        ),
      ),
    );

    expect(find.byType(AreaPaneHeader), findsOneWidget);

    expect(find.text('Retaining Path'), findsOneWidget);

    await tester.tap(find.byType(AreaPaneHeader));

    await tester.pump();

    expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);

    //collapse then expand to show the retaining path rows
    await tester.tap(find.byType(AreaPaneHeader));
    await tester.tap(find.byType(AreaPaneHeader));

    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsNWidgets(5));
    expect(find.text('fooClass'), findsOneWidget);
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

  testWidgetsWithWindowSize('test InboundReferencesWidget', windowSize,
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            Flexible(
              child: InboundReferencesWidget(
                inboundReferences: inboundRefsNotifier,
                onExpanded: fetchinboundRefsFunc,
              ),
            )
          ],
        ),
      ),
    );

    expect(find.byType(AreaPaneHeader), findsOneWidget);

    expect(find.text('Inbound References'), findsOneWidget);

    await tester.tap(find.byType(AreaPaneHeader));

    await tester.pump();

    expect(find.byType(CenteredCircularProgressIndicator), findsOneWidget);

    //collapse then expand to show the rows of inbound references
    await tester.tap(find.byType(AreaPaneHeader));
    await tester.tap(find.byType(AreaPaneHeader));

    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsNWidgets(3));
    expect(
      find.text('Referenced by fooLib.fooFunction'),
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
