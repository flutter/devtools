// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/flutter/initializer.dart';
import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mocks.dart';

void main() {
  group('Initializer', () {
    DisconnectableMockServiceManager serviceManager;
    MaterialApp app;
    const Key connectKey = Key('connect');
    const Key initializedKey = Key('initialized');
    setUp(() async {
      serviceManager = DisconnectableMockServiceManager();
      await serviceManager.ensureInspectorDependencies();
      setGlobal(ServiceConnectionManager, serviceManager);

      app = MaterialApp(
        routes: {
          '/connect': (_) => const SizedBox(key: connectKey),
          '/': (_) => Initializer(
                builder: (_) => const SizedBox(key: initializedKey),
              ),
        },
      );
    });

    testWidgets('navigates to the connection page when uninitialized',
        (WidgetTester tester) async {
      serviceManager._hasConnection = false;
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byKey(connectKey), findsOneWidget);
      expect(find.byKey(initializedKey), findsNothing);
    });

    testWidgets('builds contents when initialized',
        (WidgetTester tester) async {
      serviceManager._hasConnection = true;
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.byKey(connectKey), findsNothing);
      expect(find.byKey(initializedKey), findsOneWidget);
    });
  });
}

class DisconnectableMockServiceManager extends MockServiceManager {
  bool _hasConnection = false;
  @override
  bool get hasConnection => _hasConnection;
}
