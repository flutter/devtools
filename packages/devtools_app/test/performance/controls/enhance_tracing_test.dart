// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/controls/enhance_tracing/enhance_tracing.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
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
    when(mockServiceManager.serviceExtensionManager)
        .thenAnswer((realInvocation) => fakeExtensionManager);
    setGlobal(ServiceConnectionManager, mockServiceConnection);
    setGlobal(IdeTheme, getIdeTheme());
  });

  group('TrackWidgetBuildsSetting', () {
    setUp(() async {
      fakeExtensionManager = FakeServiceExtensionManager();
      await fakeExtensionManager.fakeFrame();
      await fakeExtensionManager
          .fakeAddServiceExtension(profileWidgetBuilds.extension);
      await fakeExtensionManager
          .fakeAddServiceExtension(profileUserWidgetBuilds.extension);
    });

    testWidgets('builds successfully', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
      await tester.pumpAndSettle();
      expect(find.byType(TrackWidgetBuildsSetting), findsOneWidget);
      expect(find.byType(TrackWidgetBuildsCheckbox), findsOneWidget);
      expect(find.byType(CheckboxSetting), findsOneWidget);
      expect(find.byType(MoreInfoLink), findsOneWidget);
      expect(find.byType(TrackWidgetBuildsScopeSelector), findsOneWidget);
      expect(find.byType(Radio<TrackWidgetBuildsScope>), findsNWidgets(2));
      final userCreatedWidgetsRadio =
          tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
              as Radio<TrackWidgetBuildsScope>;
      expect(
        userCreatedWidgetsRadio.value,
        equals(TrackWidgetBuildsScope.userCreated),
      );
      final allWidgetsRadio =
          tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).at(1))
              as Radio<TrackWidgetBuildsScope>;
      expect(allWidgetsRadio.value, equals(TrackWidgetBuildsScope.all));
    });

    testWidgets('builds with disabled state', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
      await tester.pumpAndSettle();

      verifyExtensionStates(
        mockServiceManager: mockServiceManager,
        trackAllWidgets: false,
        trackUserCreatedWidgets: false,
      );

      final trackWidgetBuildsCheckbox =
          tester.widget(find.byType(Checkbox)) as Checkbox;
      expect(trackWidgetBuildsCheckbox.value, isFalse);

      final userCreatedWidgetsRadio =
          tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
              as Radio<TrackWidgetBuildsScope>;
      expect(userCreatedWidgetsRadio.groupValue, isNull);

      final allWidgetsRadio =
          tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).at(1))
              as Radio<TrackWidgetBuildsScope>;
      expect(allWidgetsRadio.groupValue, isNull);
    });

    testWidgets(
      'builds with profileWidgetBuilds enabled',
      (WidgetTester tester) async {
        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
          profileWidgetBuilds.extension,
          enabled: true,
          value: true,
        );
        await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: true,
          trackUserCreatedWidgets: false,
        );

        final trackWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(trackWidgetBuildsCheckbox.value, isTrue);

        final userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
                as Radio<TrackWidgetBuildsScope>;
        expect(
          userCreatedWidgetsRadio.groupValue,
          equals(TrackWidgetBuildsScope.all),
        );

        final allWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).at(1))
                as Radio<TrackWidgetBuildsScope>;
        expect(
          allWidgetsRadio.groupValue,
          equals(TrackWidgetBuildsScope.all),
        );
      },
    );

    testWidgets(
      'builds with profileUserWidgetBuilds enabled',
      (WidgetTester tester) async {
        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
          profileUserWidgetBuilds.extension,
          enabled: true,
          value: true,
        );
        await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: true,
        );

        final trackWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(trackWidgetBuildsCheckbox.value, isTrue);

        final userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
                as Radio<TrackWidgetBuildsScope>;
        expect(
          userCreatedWidgetsRadio.groupValue,
          equals(TrackWidgetBuildsScope.userCreated),
        );

        final allWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).at(1))
                as Radio<TrackWidgetBuildsScope>;
        expect(
          allWidgetsRadio.groupValue,
          equals(TrackWidgetBuildsScope.userCreated),
        );
      },
    );

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
          trackAllWidgets: true,
          trackUserCreatedWidgets: true,
        );

        await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: true,
        );

        final trackWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(trackWidgetBuildsCheckbox.value, isTrue);

        final userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
                as Radio<TrackWidgetBuildsScope>;
        expect(
          userCreatedWidgetsRadio.groupValue,
          equals(TrackWidgetBuildsScope.userCreated),
        );

        final allWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).at(1))
                as Radio<TrackWidgetBuildsScope>;
        expect(
          allWidgetsRadio.groupValue,
          equals(TrackWidgetBuildsScope.userCreated),
        );
      },
    );

    testWidgets(
      'checking "Track Widget Builds" enables profileUserWidgetBuilds',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: false,
        );

        var trackWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(trackWidgetBuildsCheckbox.value, isFalse);

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        trackWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(trackWidgetBuildsCheckbox.value, isTrue);

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: true,
        );
      },
    );

    testWidgets(
      'unchecking "Track Widget Builds" disables both service extensions',
      (WidgetTester tester) async {
        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
          profileUserWidgetBuilds.extension,
          enabled: true,
          value: true,
        );
        await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: true,
        );

        var trackWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(trackWidgetBuildsCheckbox.value, isTrue);

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        trackWidgetBuildsCheckbox =
            tester.widget(find.byType(Checkbox)) as Checkbox;
        expect(trackWidgetBuildsCheckbox.value, isFalse);

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: false,
        );
      },
    );

    testWidgets(
      'can toggle track widget builds scope',
      (WidgetTester tester) async {
        await mockServiceManager.serviceExtensionManager
            .setServiceExtensionState(
          profileUserWidgetBuilds.extension,
          enabled: true,
          value: true,
        );
        await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: true,
        );

        var userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
                as Radio<TrackWidgetBuildsScope>;
        expect(
          userCreatedWidgetsRadio.groupValue,
          equals(TrackWidgetBuildsScope.userCreated),
        );

        await tester.tap(find.byType(Radio<TrackWidgetBuildsScope>).at(1));
        await tester.pumpAndSettle();

        userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
                as Radio<TrackWidgetBuildsScope>;
        expect(
          userCreatedWidgetsRadio.groupValue,
          equals(TrackWidgetBuildsScope.all),
        );

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: true,
          trackUserCreatedWidgets: false,
        );
      },
    );

    testWidgets(
      'cannot toggle scope when both service extensions are disabled',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(const TrackWidgetBuildsSetting()));
        await tester.pumpAndSettle();

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: false,
        );

        var userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
                as Radio<TrackWidgetBuildsScope>;
        expect(userCreatedWidgetsRadio.groupValue, isNull);
        var allWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).at(1))
                as Radio<TrackWidgetBuildsScope>;
        expect(allWidgetsRadio.groupValue, isNull);

        await tester.tap(find.byType(Radio<TrackWidgetBuildsScope>).first);
        await tester.pumpAndSettle();

        userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
                as Radio<TrackWidgetBuildsScope>;
        expect(userCreatedWidgetsRadio.groupValue, isNull);
        allWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).at(1))
                as Radio<TrackWidgetBuildsScope>;
        expect(allWidgetsRadio.groupValue, isNull);

        await tester.tap(find.byType(Radio<TrackWidgetBuildsScope>).at(1));
        await tester.pumpAndSettle();

        userCreatedWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).first)
                as Radio<TrackWidgetBuildsScope>;
        expect(userCreatedWidgetsRadio.groupValue, isNull);
        allWidgetsRadio =
            tester.widget(find.byType(Radio<TrackWidgetBuildsScope>).at(1))
                as Radio<TrackWidgetBuildsScope>;
        expect(allWidgetsRadio.groupValue, isNull);

        verifyExtensionStates(
          mockServiceManager: mockServiceManager,
          trackAllWidgets: false,
          trackUserCreatedWidgets: false,
        );
      },
    );
  });

  group('TrackWidgetBuildsScope enum', () {
    test('radioDisplay', () {
      expect(
        TrackWidgetBuildsScope.all.radioDisplay,
        equals('within all code'),
      );
      expect(
        TrackWidgetBuildsScope.userCreated.radioDisplay,
        equals('within your code'),
      );
    });

    test('opposite', () {
      expect(
        TrackWidgetBuildsScope.all.opposite,
        equals(TrackWidgetBuildsScope.userCreated),
      );
      expect(
        TrackWidgetBuildsScope.userCreated.opposite,
        equals(TrackWidgetBuildsScope.all),
      );
    });

    test('extensionForScope', () {
      expect(
        TrackWidgetBuildsScope.all.extensionForScope,
        equals(profileWidgetBuilds),
      );
      expect(
        TrackWidgetBuildsScope.userCreated.extensionForScope,
        equals(profileUserWidgetBuilds),
      );
    });
  });
}

void verifyExtensionStates({
  required MockServiceManager mockServiceManager,
  required bool trackAllWidgets,
  required bool trackUserCreatedWidgets,
}) {
  expect(
    mockServiceManager.serviceExtensionManager
        .getServiceExtensionState(profileWidgetBuilds.extension)
        .value
        .enabled,
    equals(trackAllWidgets),
  );
  expect(
    mockServiceManager.serviceExtensionManager
        .getServiceExtensionState(profileUserWidgetBuilds.extension)
        .value
        .enabled,
    equals(trackUserCreatedWidgets),
  );
}
