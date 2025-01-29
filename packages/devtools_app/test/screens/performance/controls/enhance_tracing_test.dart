// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/controls/enhance_tracing/enhance_tracing.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  late FakeServiceExtensionManager fakeExtensionManager;
  late MockServiceConnectionManager mockServiceConnection;
  late MockServiceManager mockServiceManager;

  setUp(() {
    mockServiceConnection = createMockServiceConnectionWithDefaults();
    mockServiceManager =
        mockServiceConnection.serviceManager as MockServiceManager;
    when(
      mockServiceManager.serviceExtensionManager,
    ).thenAnswer((realInvocation) => fakeExtensionManager);
    setGlobal(ServiceConnectionManager, mockServiceConnection);
    setGlobal(IdeTheme, getIdeTheme());
  });

  group('TraceWidgetBuildsSetting', () {
    setUp(() async {
      fakeExtensionManager = FakeServiceExtensionManager();
      await fakeExtensionManager.fakeFrame();
      await fakeExtensionManager.fakeAddServiceExtension(
        profileWidgetBuilds.extension,
      );
      await fakeExtensionManager.fakeAddServiceExtension(
        profileUserWidgetBuilds.extension,
      );
    });

    testWidgets('builds successfully', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
      await tester.pumpAndSettle();
      expect(find.byType(TraceWidgetBuildsSetting), findsOneWidget);
      expect(find.byType(TraceWidgetBuildsCheckbox), findsOneWidget);
      expect(find.byType(CheckboxSetting), findsOneWidget);
      expect(find.byType(MoreInfoLink), findsOneWidget);
      expect(find.byType(TraceWidgetBuildsScopeSelector), findsOneWidget);
      expect(find.byType(Radio<TraceWidgetBuildsScope>), findsNWidgets(2));
      final userCreatedWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
              as Radio<TraceWidgetBuildsScope>;
      expect(
        userCreatedWidgetsRadio.value,
        equals(TraceWidgetBuildsScope.userCreated),
      );
      final allWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).at(1))
              as Radio<TraceWidgetBuildsScope>;
      expect(allWidgetsRadio.value, equals(TraceWidgetBuildsScope.all));
    });

    testWidgets('builds with disabled state', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
      await tester.pumpAndSettle();

      verifyExtensionStates(
        mockServiceManager: mockServiceManager,
        traceAllWidgets: false,
        traceUserCreatedWidgets: false,
      );

      final traceWidgetBuildsCheckbox =
          tester.widget(find.byType(Checkbox)) as Checkbox;
      expect(traceWidgetBuildsCheckbox.value, isFalse);

      final userCreatedWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
              as Radio<TraceWidgetBuildsScope>;
      expect(userCreatedWidgetsRadio.groupValue, isNull);

      final allWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).at(1))
              as Radio<TraceWidgetBuildsScope>;
      expect(allWidgetsRadio.groupValue, isNull);
    });

    testWidgets('builds with profileWidgetBuilds enabled', (
      WidgetTester tester,
    ) async {
      await mockServiceManager.serviceExtensionManager.setServiceExtensionState(
        profileWidgetBuilds.extension,
        enabled: true,
        value: true,
      );
      await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
      await tester.pumpAndSettle();

      verifyExtensionStates(
        mockServiceManager: mockServiceManager,
        traceAllWidgets: true,
        traceUserCreatedWidgets: false,
      );

      final traceWidgetBuildsCheckbox =
          tester.widget(find.byType(Checkbox)) as Checkbox;
      expect(traceWidgetBuildsCheckbox.value, isTrue);

      final userCreatedWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
              as Radio<TraceWidgetBuildsScope>;
      expect(
        userCreatedWidgetsRadio.groupValue,
        equals(TraceWidgetBuildsScope.all),
      );

      final allWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).at(1))
              as Radio<TraceWidgetBuildsScope>;
      expect(allWidgetsRadio.groupValue, equals(TraceWidgetBuildsScope.all));
    });

    testWidgets('builds with profileUserWidgetBuilds enabled', (
      WidgetTester tester,
    ) async {
      await mockServiceManager.serviceExtensionManager.setServiceExtensionState(
        profileUserWidgetBuilds.extension,
        enabled: true,
        value: true,
      );
      await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
      await tester.pumpAndSettle();

      verifyExtensionStates(
        mockServiceManager: mockServiceManager,
        traceAllWidgets: false,
        traceUserCreatedWidgets: true,
      );

      final traceWidgetBuildsCheckbox =
          tester.widget(find.byType(Checkbox)) as Checkbox;
      expect(traceWidgetBuildsCheckbox.value, isTrue);

      final userCreatedWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
              as Radio<TraceWidgetBuildsScope>;
      expect(
        userCreatedWidgetsRadio.groupValue,
        equals(TraceWidgetBuildsScope.userCreated),
      );

      final allWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).at(1))
              as Radio<TraceWidgetBuildsScope>;
      expect(
        allWidgetsRadio.groupValue,
        equals(TraceWidgetBuildsScope.userCreated),
      );
    });

    testWidgets(
      'defaults to user created widgets when both service extensions are '
      'enabled',
      (WidgetTester tester) async {
        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
              profileWidgetBuilds.extension,
              enabled: true,
              value: true,
            );
        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
              profileUserWidgetBuilds.extension,
              enabled: true,
              value: true,
            );
        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          traceAllWidgets: true,
          traceUserCreatedWidgets: true,
        );

        await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          traceAllWidgets: false,
          traceUserCreatedWidgets: true,
        );

        final traceWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(traceWidgetBuildsCheckbox.value, isTrue);

        final userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
                as Radio<TraceWidgetBuildsScope>;
        expect(
          userCreatedWidgetsRadio.groupValue,
          equals(TraceWidgetBuildsScope.userCreated),
        );

        final allWidgetsRadio =
            tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).at(1))
                as Radio<TraceWidgetBuildsScope>;
        expect(
          allWidgetsRadio.groupValue,
          equals(TraceWidgetBuildsScope.userCreated),
        );
      },
    );

    testWidgets(
      'checking "Trace Widget Builds" enables profileUserWidgetBuilds',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          traceAllWidgets: false,
          traceUserCreatedWidgets: false,
        );

        var traceWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(traceWidgetBuildsCheckbox.value, isFalse);

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        traceWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(traceWidgetBuildsCheckbox.value, isTrue);

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          traceAllWidgets: false,
          traceUserCreatedWidgets: true,
        );
      },
    );

    testWidgets(
      'unchecking "Trace Widget Builds" disables both service extensions',
      (WidgetTester tester) async {
        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
              profileUserWidgetBuilds.extension,
              enabled: true,
              value: true,
            );
        await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          traceAllWidgets: false,
          traceUserCreatedWidgets: true,
        );

        var traceWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(traceWidgetBuildsCheckbox.value, isTrue);

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        traceWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(traceWidgetBuildsCheckbox.value, isFalse);

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          traceAllWidgets: false,
          traceUserCreatedWidgets: false,
        );
      },
    );

    testWidgets('can toggle trace widget builds scope', (
      WidgetTester tester,
    ) async {
      await mockServiceManager.serviceExtensionManager.setServiceExtensionState(
        profileUserWidgetBuilds.extension,
        enabled: true,
        value: true,
      );
      await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
      await tester.pumpAndSettle();

      verifyExtensionStates(
        mockServiceManager: mockServiceManager,
        traceAllWidgets: false,
        traceUserCreatedWidgets: true,
      );

      var userCreatedWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
              as Radio<TraceWidgetBuildsScope>;
      expect(
        userCreatedWidgetsRadio.groupValue,
        equals(TraceWidgetBuildsScope.userCreated),
      );

      await tester.tap(find.byType(Radio<TraceWidgetBuildsScope>).at(1));
      await tester.pumpAndSettle();

      userCreatedWidgetsRadio =
          tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
              as Radio<TraceWidgetBuildsScope>;
      expect(
        userCreatedWidgetsRadio.groupValue,
        equals(TraceWidgetBuildsScope.all),
      );

      verifyExtensionStates(
        mockServiceManager: mockServiceManager,
        traceAllWidgets: true,
        traceUserCreatedWidgets: false,
      );
    });

    testWidgets(
      'cannot toggle scope when both service extensions are disabled',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(const TraceWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          traceAllWidgets: false,
          traceUserCreatedWidgets: false,
        );

        var userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
                as Radio<TraceWidgetBuildsScope>;
        expect(userCreatedWidgetsRadio.groupValue, isNull);
        var allWidgetsRadio =
            tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).at(1))
                as Radio<TraceWidgetBuildsScope>;
        expect(allWidgetsRadio.groupValue, isNull);

        await tester.tap(find.byType(Radio<TraceWidgetBuildsScope>).first);
        await tester.pumpAndSettle();

        userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
                as Radio<TraceWidgetBuildsScope>;
        expect(userCreatedWidgetsRadio.groupValue, isNull);
        allWidgetsRadio =
            tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).at(1))
                as Radio<TraceWidgetBuildsScope>;
        expect(allWidgetsRadio.groupValue, isNull);

        await tester.tap(find.byType(Radio<TraceWidgetBuildsScope>).at(1));
        await tester.pumpAndSettle();

        userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).first)
                as Radio<TraceWidgetBuildsScope>;
        expect(userCreatedWidgetsRadio.groupValue, isNull);
        allWidgetsRadio =
            tester.widget(find.byType(Radio<TraceWidgetBuildsScope>).at(1))
                as Radio<TraceWidgetBuildsScope>;
        expect(allWidgetsRadio.groupValue, isNull);

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          traceAllWidgets: false,
          traceUserCreatedWidgets: false,
        );
      },
    );
  });

  group('TraceWidgetBuildsScope enum', () {
    test('radioDisplay', () {
      expect(
        TraceWidgetBuildsScope.all.radioDisplay,
        equals('within all code'),
      );
      expect(
        TraceWidgetBuildsScope.userCreated.radioDisplay,
        equals('within your code'),
      );
    });

    test('opposite', () {
      expect(
        TraceWidgetBuildsScope.all.opposite,
        equals(TraceWidgetBuildsScope.userCreated),
      );
      expect(
        TraceWidgetBuildsScope.userCreated.opposite,
        equals(TraceWidgetBuildsScope.all),
      );
    });

    test('extensionForScope', () {
      expect(
        TraceWidgetBuildsScope.all.extensionForScope,
        equals(profileWidgetBuilds),
      );
      expect(
        TraceWidgetBuildsScope.userCreated.extensionForScope,
        equals(profileUserWidgetBuilds),
      );
    });
  });
}

void verifyExtensionStates({
  required MockServiceManager mockServiceManager,
  required bool traceAllWidgets,
  required bool traceUserCreatedWidgets,
}) {
  expect(
    mockServiceManager.serviceExtensionManager
        .getServiceExtensionState(profileWidgetBuilds.extension)
        .value
        .enabled,
    equals(traceAllWidgets),
  );
  expect(
    mockServiceManager.serviceExtensionManager
        .getServiceExtensionState(profileUserWidgetBuilds.extension)
        .value
        .enabled,
    equals(traceUserCreatedWidgets),
  );
}
