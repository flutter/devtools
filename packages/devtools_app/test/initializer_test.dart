// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'package:devtools_app/src/initializer.dart'
    hide ensureInspectorDependencies;
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'support/mocks.dart';

void main() {
  group('Initializer', () {
    MaterialApp app;
    const Key connectKey = Key('connect');
    const Key initializedKey = Key('initialized');
    setUp(() async {
      await ensureInspectorDependencies();
      final serviceManager = FakeServiceManager(useFakeService: true);
      when(serviceManager.connectedApp.isDartWebApp)
          .thenAnswer((_) => Future.value(false));
      setGlobal(
        ServiceConnectionManager,
        serviceManager,
      );

      app = MaterialApp(
        // This test uses a fake route of /init for the initializer but
        // in the real app it's loaded based on whether there's a ?uri= on
        // the querystring, with / loading the connect dialog.
        initialRoute: '/init',
        routes: {
          '/': (_) => const SizedBox(key: connectKey),
          '/init': (_) => Initializer(
                url: null,
                builder: (_) => const SizedBox(key: initializedKey),
              ),
        },
      );
    });

    testWidgets('navigates back to the connection page when uninitialized',
        (WidgetTester tester) async {
      setGlobal(
        ServiceConnectionManager,
        FakeServiceManager(useFakeService: true, hasConnection: false),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byKey(connectKey), findsOneWidget);
      expect(find.byKey(initializedKey), findsNothing);
    });

    testWidgets('builds contents when initialized',
        (WidgetTester tester) async {
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byKey(connectKey), findsNothing);
      expect(find.byKey(initializedKey), findsOneWidget);
    });
  });
}
