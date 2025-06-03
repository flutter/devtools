// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:dart_service_protocol_shared/dart_service_protocol_shared.dart';
import 'package:devtools_app/src/screens/dtd/services.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late ServicesController controller;
  late MockDartToolingDaemon mockDtd;

  setUp(() {
    mockDtd = MockDartToolingDaemon();
    when(mockDtd.getRegisteredServices()).thenAnswer((_) {
      return Future.value(
        RegisteredServicesResponse(
          dtdServices: [
            '${ConnectedAppServiceConstants.serviceName}.${ConnectedAppServiceConstants.getVmServices}',
            '${ConnectedAppServiceConstants.serviceName}.${ConnectedAppServiceConstants.registerVmService}',
            '${ConnectedAppServiceConstants.serviceName}.${ConnectedAppServiceConstants.unregisterVmService}',
          ],
          clientServices: [
            ClientServiceInfo('Test', {
              'foo': ClientServiceMethodInfo('foo'),
              'bar': ClientServiceMethodInfo('bar'),
            }),
          ],
        ),
      );
    });

    controller = ServicesController()..dtd = mockDtd;
  });

  tearDown(() {
    controller.dispose();
  });

  group('$ServicesController', () {
    testWidgets('init populates known services', (WidgetTester tester) async {
      expect(controller.services.value, isEmpty);
      await controller.init();
      expect(controller.services.value.length, equals(5));
    });
  });

  group('$ServicesView', () {
    setUp(() async {
      setGlobal(IdeTheme, IdeTheme());
      await controller.init();
    });

    testWidgets('displays services', (WidgetTester tester) async {
      await tester.pumpWidget(wrapSimple(ServicesView(controller: controller)));

      expect(find.text('Registered services'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(5));
      expect(
        find.text(
          '${ConnectedAppServiceConstants.serviceName}.${ConnectedAppServiceConstants.getVmServices}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '${ConnectedAppServiceConstants.serviceName}.${ConnectedAppServiceConstants.registerVmService}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '${ConnectedAppServiceConstants.serviceName}.${ConnectedAppServiceConstants.unregisterVmService}',
        ),
        findsOneWidget,
      );
      expect(find.text('Test.foo'), findsOneWidget);
      expect(find.text('Test.bar'), findsOneWidget);
    });

    testWidgets('selecting services populates $ManuallyCallService view', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapSimple(ServicesView(controller: controller)));

      expect(controller.selectedService.value, isNull);
      expect(find.byType(ManuallyCallService), findsOneWidget);
      final manuallyCallServicesState = tester.state<ManuallyCallServiceState>(
        find.byType(ManuallyCallService),
      );
      expect(manuallyCallServicesState.serviceController.text, isEmpty);
      expect(manuallyCallServicesState.methodController.text, isEmpty);
      expect(manuallyCallServicesState.paramsController.text, isEmpty);

      await tester.tap(find.text('Test.foo'));
      await tester.pumpAndSettle();

      expect(controller.selectedService.value, isNotNull);
      expect(controller.selectedService.value!.displayName, 'Test.foo');
      expect(manuallyCallServicesState.serviceController.text, 'Test');
      expect(manuallyCallServicesState.methodController.text, 'foo');
      expect(manuallyCallServicesState.paramsController.text, isEmpty);

      const dtdServiceMethod =
          '${ConnectedAppServiceConstants.serviceName}.${ConnectedAppServiceConstants.getVmServices}';
      await tester.tap(find.text(dtdServiceMethod));
      await tester.pumpAndSettle();

      expect(controller.selectedService.value, isNotNull);
      expect(controller.selectedService.value!.displayName, dtdServiceMethod);
      expect(
        manuallyCallServicesState.serviceController.text,
        ConnectedAppServiceConstants.serviceName,
      );
      expect(
        manuallyCallServicesState.methodController.text,
        ConnectedAppServiceConstants.getVmServices,
      );
      expect(manuallyCallServicesState.paramsController.text, isEmpty);
    });

    testWidgets('pressing Clear button clears the manually call service view', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapSimple(ServicesView(controller: controller)));

      final manuallyCallServicesState = tester.state<ManuallyCallServiceState>(
        find.byType(ManuallyCallService),
      );

      // Select a service to populate the fields.
      await tester.tap(find.text('Test.foo'));
      await tester.pumpAndSettle();

      expect(manuallyCallServicesState.serviceController.text, 'Test');
      expect(manuallyCallServicesState.methodController.text, 'foo');
      expect(manuallyCallServicesState.paramsController.text, isEmpty);

      // Tap the Clear button.
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Verify the fields are cleared.
      expect(manuallyCallServicesState.serviceController.text, isEmpty);
      expect(manuallyCallServicesState.methodController.text, isEmpty);
      expect(manuallyCallServicesState.paramsController.text, isEmpty);
    });
  });
}
