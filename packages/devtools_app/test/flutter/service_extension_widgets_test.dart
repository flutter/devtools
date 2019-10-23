import 'dart:async';

import 'package:devtools_app/src/globals.dart';
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/service_registrations.dart';
import 'package:devtools_app/src/ui/flutter/service_extension_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../support/mocks.dart';
import 'initializer_test.dart';
import 'wrappers.dart';

void main() {
  MockServiceManager mockServiceManager;
  setUp(() {
    mockServiceManager = MockServiceManager();
    registerServiceExtension(mockServiceManager, hotReload);
    registerServiceExtension(mockServiceManager, hotRestart);

    setGlobal(
      ServiceConnectionManager,
      mockServiceManager,
    );
  });
  group('Hot Reload Button', () {
    testWidgets('performs a hot reload when pressed',
        (WidgetTester tester) async {
      int reloads = 0;
      when(mockServiceManager.performHotReload()).thenAnswer((invocation) {
        reloads++;
        return Future<void>.value();
      });
      final button = HotReloadButton();
      await tester.pumpWidget(wrap(Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);
      await tester.pumpAndSettle();
      expect(reloads, 0);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(reloads, 1);
    });
  });

  group('Hot Restart Button', () {
    testWidgets('performs a hot restart when pressed',
        (WidgetTester tester) async {
      int restarts = 0;
      when(mockServiceManager.performHotRestart()).thenAnswer((invocation) {
        restarts++;
        return Future<void>.value();
      });
      final button = HotRestartButton();
      await tester.pumpWidget(wrap(Scaffold(body: Center(child: button))));
      expect(find.byWidget(button), findsOneWidget);
      await tester.pumpAndSettle();
      expect(restarts, 0);
      await tester.tap(find.byWidget(button));
      await tester.pumpAndSettle();
      expect(restarts, 1);
    });
  });
}

void registerServiceExtension(MockServiceManager mockServiceManager,
    RegisteredServiceDescription description) {
  when(mockServiceManager.hasRegisteredService(description.service, any))
      .thenAnswer((invocation) {
    final onData = invocation.positionalArguments[1];
    return Stream<bool>.value(true).listen(onData);
  });
}
