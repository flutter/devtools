// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/scaffold/scaffold.dart';
import 'package:devtools_app/src/shared/analytics/constants.dart' as gac;
import 'package:devtools_app/src/shared/framework/framework_controller.dart';
import 'package:devtools_app/src/shared/managers/survey.dart';
import 'package:devtools_app/src/shared/primitives/message_bus.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../screens/network/utils/network_test_utils.dart';

/// The viewport widths, in logical pixels, used by the responsive layout tests.
///
/// These include the realistic narrow widths from the issue (328 and 411), the
/// `MediaSize` boundaries used by the Network toolbar and the status line (600
/// and 900), and a desktop baseline.
const responsiveLayoutWidths = <double>[
  328,
  411,
  599,
  600,
  601,
  899,
  900,
  901,
  1400,
];

/// The viewport height, in logical pixels, used by the responsive layout tests.
const responsiveLayoutHeight = 900.0;

/// The tolerance, in logical pixels, used when comparing geometry.
const geometryTolerance = 0.5;

/// Creates a fake service connection to a Dart VM app, with the VM details that
/// the About dialog reads.
FakeServiceConnectionManager createLayoutServiceConnection() {
  final connection = FakeServiceConnectionManager(
    service: FakeServiceManager.createFakeService(
      socketProfile: loadSocketProfile(),
      httpProfile: loadHttpProfile(),
    ),
  );
  final vm = connection.serviceManager.vm;
  when(vm.version).thenReturn('1.9.1');
  when(vm.targetCPU).thenReturn('arm64');
  when(vm.architectureBits).thenReturn(64);
  when(vm.operatingSystem).thenReturn('android');
  mockConnectedApp(
    connection.serviceManager.connectedApp!,
    isFlutterApp: false,
  );
  for (final screenId in [
    ScreenMetaData.network.id,
    ScreenMetaData.logging.id,
  ]) {
    when(
      connection.errorBadgeManager.errorCountNotifier(screenId),
    ).thenReturn(ValueNotifier<int>(0));
  }
  return connection;
}

/// Registers the globals that a full [DevToolsScaffold] needs in tests.
void setUpLayoutGlobals(FakeServiceConnectionManager connection) {
  setGlobal(ServiceConnectionManager, connection);
  setGlobal(OfflineDataController, OfflineDataController());
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(
    DevToolsEnvironmentParameters,
    ExternalDevToolsEnvironmentParameters(),
  );
  setGlobal(PreferencesController, PreferencesController());
  setGlobal(NotificationService, NotificationService());
  setGlobal(DTDManager, MockDTDManager());
  setGlobal(FrameworkController, FrameworkController());
  setGlobal(SurveyService, SurveyService());
  setGlobal(BannerMessagesController, BannerMessagesController());
  setGlobal(BreakpointManager, BreakpointManager());
  setGlobal(MessageBus, MessageBus());
}

/// Pumps a full [DevToolsScaffold] showing the screen identified by [pageId].
///
/// The scaffold contains the real application-wide `StatusLine`, so the footer
/// and the screen body are laid out together as they are in the app.
Future<void> pumpDevToolsScaffold(
  WidgetTester tester, {
  required String pageId,
  required bool embedded,
  required bool connected,
  required FakeServiceConnectionManager connection,
  required NetworkController network,
  required LoggingController logging,
  required DebuggerController debugger,
}) async {
  final embedMode = embedded ? EmbedMode.embedOne : EmbedMode.none;
  setGlobal(IdeTheme, IdeTheme(embedMode: embedMode));
  connection.serviceManager.setConnectedState(connected);
  // The providers sit above the app so that dialogs opened from the footer can
  // read them, as they do in the app.
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AnalyticsController>.value(
          value: AnalyticsController(
            enabled: false,
            shouldShowConsentMessage: false,
            consentMessage: 'fake message',
          ),
        ),
        Provider<ReleaseNotesController>.value(value: ReleaseNotesController()),
      ],
      child: wrapWithControllers(
        DevToolsScaffold(
          screens: [NetworkScreen(), LoggingScreen()],
          page: pageId,
          embedMode: embedMode,
        ),
        network: network,
        logging: logging,
        debugger: debugger,
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

/// Runs [action] and returns the message of every [FlutterError] it reports.
///
/// Layout exceptions are reported through [FlutterError.onError]. Collecting
/// them lets tests assert on them after the handler is restored.
Future<List<String>> collectFlutterErrors(
  Future<void> Function() action,
) async {
  final errors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await action();
  } finally {
    FlutterError.onError = originalOnError;
  }
  return [for (final error in errors) error.exceptionAsString()];
}

/// Stops the polling of [network] and lets pending timers complete, so that no
/// timers are left pending when a test ends.
Future<void> stopNetworkPolling(
  WidgetTester tester,
  NetworkController network,
) async {
  await network.stopRecording();
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

/// Asserts that no two rectangles in [named] intersect.
void expectNoIntersections(Map<String, Rect> named) {
  final entries = named.entries.toList();
  for (var i = 0; i < entries.length; i++) {
    for (var j = i + 1; j < entries.length; j++) {
      final a = entries[i];
      final b = entries[j];
      expect(
        a.value
            .deflate(geometryTolerance)
            .overlaps(b.value.deflate(geometryTolerance)),
        isFalse,
        reason: '${a.key} ${a.value} intersects ${b.key} ${b.value}',
      );
    }
  }
}

/// Asserts that every rectangle in [named] lies entirely within [bounds].
///
/// A rectangle that extends past [bounds] is clipped or overflowing.
void expectWithinBounds(Map<String, Rect> named, Rect bounds) {
  for (final entry in named.entries) {
    final rect = entry.value;
    expect(
      rect.width > 0 && rect.height > 0,
      isTrue,
      reason: '${entry.key} has no size: $rect',
    );
    expect(
      rect.left >= bounds.left - geometryTolerance &&
          rect.right <= bounds.right + geometryTolerance &&
          rect.top >= bounds.top - geometryTolerance &&
          rect.bottom <= bounds.bottom + geometryTolerance,
      isTrue,
      reason: '${entry.key} $rect is not within $bounds',
    );
  }
}

/// Asserts that the text in [finder] is laid out at its full intrinsic width,
/// so that it is not ellipsized or wrapped.
void expectTextNotTruncated(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final fullWidth = paragraph.getMaxIntrinsicWidth(double.infinity);
  expect(
    paragraph.size.width + geometryTolerance >= fullWidth,
    isTrue,
    reason:
        'Text "${paragraph.text.toPlainText()}" is truncated: laid out at '
        '${paragraph.size.width}, needs $fullWidth',
  );
}

/// Records the URLs that DevTools asks the platform to open.
///
/// Launching is intercepted at the `url_launcher` method channel, so the test
/// checks the URL without opening a browser.
class UrlLaunchRecorder {
  final launched = <String>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          switch (call.method) {
            case 'canLaunch':
              return true;
            case 'launch':
              launched.add((call.arguments as Map)['url'] as String);
              return true;
          }
          return null;
        });
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }

  static const _channel = MethodChannel('plugins.flutter.io/url_launcher');
}

/// Records the analytics events that DevTools reports.
///
/// The analytics implementation used in tests logs each selection, so the
/// events are captured from the log rather than from a network request.
class AnalyticsRecorder {
  final events = <String>[];

  StreamSubscription<LogRecord>? _subscription;
  Level? _originalLevel;

  void install() {
    _originalLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    _subscription = Logger.root.onRecord.listen((record) {
      if (record.loggerName == '_analytics_stub') {
        events.add(record.message);
      }
    });
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    Logger.root.level = _originalLevel ?? Level.INFO;
  }

  /// Returns whether a selection of [item] on [screenId] was recorded.
  bool recordedSelection({required String screenId, required String item}) {
    return events.any(
      (event) => event.contains('screenName:$screenId, selectedItem:$item, '),
    );
  }

  /// The selected item description for the tutorial link on [screenId].
  static String tutorialItem(String screenId) {
    return '${gac.videoTutorialLink}-$screenId';
  }
}

/// Asserts that [finder] is hit-testable, so a user tapping its center reaches
/// it.
void expectInteractable(Finder finder) {
  expect(finder.hitTestable(), findsOneWidget);
}
