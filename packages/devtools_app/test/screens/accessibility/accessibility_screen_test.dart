import 'package:devtools_app/src/app.dart';
import 'package:devtools_app/src/screens/accessibility/accessibility_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app/src/shared/framework/screen.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/managers/banner_messages.dart';
import 'package:devtools_app/src/shared/managers/notifications.dart';
import 'package:devtools_app/src/shared/offline/offline_data.dart';
import 'package:devtools_app/src/shared/preferences/preferences.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = ScreenMetaData.accessibility;

  group('AccessibilityScreen', () {
    late FakeServiceConnectionManager fakeServiceConnection;

    setUp(() {
      fakeServiceConnection = FakeServiceConnectionManager();
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(OfflineDataController, OfflineDataController());
      setGlobal(NotificationService, NotificationService());
      setGlobal(BannerMessagesController, BannerMessagesController());
      setGlobal(PreferencesController, PreferencesController());
      FeatureFlags.accessibility.setEnabledForTests(true);
    });

    tearDown(() {
      FeatureFlags.accessibility.setEnabledForTests(false);
    });

    testWidgets('builds its body', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(builder: (context) => AccessibilityScreen().build(context)),
        ),
      );
      expect(find.byType(AccessibilityScreenBody), findsOneWidget);
      expect(find.text('Accessibility Screen Placeholder'), findsOneWidget);
    });

    test('is included in defaultScreens when enabled', () {
      devtoolsScreens = null;
      expect(
        defaultScreens().any((s) => s.screen is AccessibilityScreen),
        isTrue,
      );
    });

    test('is invalid in defaultScreens when disabled', () {
      FeatureFlags.accessibility.setEnabledForTests(false);
      devtoolsScreens = null;
      expect(
        defaultScreens().any((s) => s.screen is AccessibilityScreen),
        isFalse,
      );
    });
  });
}
