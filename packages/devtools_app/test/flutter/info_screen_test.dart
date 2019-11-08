// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/info/flutter/info_screen.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import '../support/mocks.dart';
import 'wrappers.dart';

void main() {
  InfoScreen screen;
  group('Info Screen', () {
    setUp(() {
      setGlobal(ServiceConnectionManager, FakeServiceManager());
      when(serviceManager.service.getFlagList()).thenAnswer((_) => null);
      when(serviceManager.connectedApp.isAnyFlutterApp)
          .thenAnswer((_) => Future.value(true));

      screen = const InfoScreen();
    });

    void mockFlags() {
      when(serviceManager.service.getFlagList()).thenAnswer((invocation) {
        return Future.value(
          FlagList()
            ..flags = [
              Flag()
                ..name = 'flag 1 name'
                ..comment = 'flag 1 comment contains some very long text '
                    'that the renderer will have to wrap around to prevent '
                    'it from overflowing the screen. This will cause a '
                    'failure if one of the two Row entries the flags lay out '
                    'in is not wrapped in an Expanded(), which tells the Row '
                    'allocate only the remaining space to the Expanded. '
                    'Without the expanded, the underlying RichTexts will try '
                    'to consume as much of the layout as they can and cause '
                    'an overflow.'
                ..valueAsString = 'flag 1 value'
                ..modified = false
            ],
        );
      });
    }

    testWidgets('builds its tab', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.buildTab)));
      expect(find.text('Info'), findsOneWidget);
    });

    testWidgets('builds with no data', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      expect(find.byType(InfoScreenBody), findsOneWidget);
      expect(find.byKey(InfoScreen.flutterVersionKey), findsNothing);
      expect(find.byKey(InfoScreen.flagListKey), findsNothing);
    });

    testWidgets('builds with flags data', (WidgetTester tester) async {
      mockFlags();
      await tester.pumpWidget(wrap(Builder(builder: screen.build)));
      await tester.pumpAndSettle();
      expect(find.byKey(InfoScreen.flutterVersionKey), findsNothing);
      expect(find.byKey(InfoScreen.flagListKey), findsOneWidget);
    });

    // There's not an easy way to mock out the flutter version retrieval,
    // so we have no tests for it.
  });
}
