// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:devtools_extensions/src/template/_simulated_devtools_environment/_simulated_devtools_environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foo_devtools_extension/src/devtools_extension_api_example.dart';
import 'package:integration_test/integration_test.dart';

// To run this test:
// dart run integration_test/run_tests.dart --target=integration_test/test/simulated_environment_test.dart

const safePumpDuration = Duration(seconds: 3);
const longPumpDuration = Duration(seconds: 6);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('end to end simulated environment', (tester) async {
    runApp(
      const DevToolsExtension(
        requiresRunningApplication: false,
        child: TestDevToolsExtension(),
      ),
    );
    await tester.pump(safePumpDuration);
    expect(find.byType(DevToolsExtension), findsOneWidget);
    expect(find.byType(TestDevToolsExtension), findsOneWidget);
    expect(find.byType(SimulatedDevToolsWrapper), findsOneWidget);
    expect(find.text('Simulated DevTools Environment'), findsOneWidget);

    final simController = tester
        .state<SimulatedDevToolsWrapperState>(
          find.byType(SimulatedDevToolsWrapper),
        )
        .simController;
    expect(simController.messageLogs.value, isEmpty);

    logStatus('test ping and pong');
    await _testPingPong(tester, simController);
    logStatus('test registering a custom event handler');
    await _testRegisterEventHandler(tester, simController);
    logStatus('test toggling the theme');
    await _testToggleTheme(tester, simController);
    logStatus('test showing a notification from the extension');
    await _testShowNotification(tester, simController);
    logStatus('test showing a banner message from the extension');
    await _testShowBannerMessage(tester, simController);
    logStatus('test collapsing environment panel');
    await _testCollapseEnvironmentPanel(tester, simController);

    // NOTE: the force reload functionality cannot be tested because it will
    // make this test run in an infinite loop (it refreshes the whole window
    // that the integration test is running in).
  });
}

Future<void> _testPingPong(
  WidgetTester tester,
  SimulatedDevToolsController simController,
) async {
  final pingButtonFinder = find.descendant(
    of: find.byType(DevToolsButton),
    matching: find.text('PING'),
  );
  await tester.tap(pingButtonFinder);
  await tester.pumpAndSettle();

  expect(find.byType(LogListItem), findsNWidgets(2));
  expect(simController.messageLogs.value[0].source.name, 'devtools');
  expect(simController.messageLogs.value[0].data!['type'], 'ping');
  expect(simController.messageLogs.value[1].source.name, 'extension');
  expect(simController.messageLogs.value[1].data!['type'], 'pong');
  await _clearLogs(tester, simController);
}

Future<void> _testRegisterEventHandler(
  WidgetTester tester,
  SimulatedDevToolsController simController,
) async {
  final pingButtonFinder = find.descendant(
    of: find.byType(DevToolsButton),
    matching: find.text('PING'),
  );

  // Register a handler and verify it was called.
  int eventHandlerCalledCount = 0;
  extensionManager.registerEventHandler(
    DevToolsExtensionEventType.ping,
    (event) {
      eventHandlerCalledCount++;
    },
  );
  await tester.tap(pingButtonFinder);
  await tester.pumpAndSettle();
  expect(eventHandlerCalledCount, 1);

  // Register a different handler and verify it has replaced the original.
  int secondEventHandlerCalledCount = 0;
  extensionManager.registerEventHandler(
    DevToolsExtensionEventType.ping,
    (event) {
      secondEventHandlerCalledCount++;
    },
  );
  await tester.tap(pingButtonFinder);
  await tester.pumpAndSettle();

  // Verify the original handler was not called and that the new one was called.
  expect(eventHandlerCalledCount, 1);
  expect(secondEventHandlerCalledCount, 1);

  // Unregister the handler and verify it is no longer called.
  extensionManager.unregisterEventHandler(DevToolsExtensionEventType.ping);
  await tester.tap(pingButtonFinder);
  await tester.pumpAndSettle();
  expect(eventHandlerCalledCount, 1);
  expect(secondEventHandlerCalledCount, 1);

  await _clearLogs(tester, simController);
}

Future<void> _testToggleTheme(
  WidgetTester tester,
  SimulatedDevToolsController simController,
) async {
  expect(extensionManager.darkThemeEnabled.value, isTrue);

  final toggleThemeButtonFinder = find.descendant(
    of: find.byType(DevToolsButton),
    matching: find.text('TOGGLE THEME'),
  );

  await tester.tap(toggleThemeButtonFinder);
  await tester.pumpAndSettle();
  expect(extensionManager.darkThemeEnabled.value, isFalse);
  expect(find.byType(LogListItem), findsNWidgets(1));
  expect(simController.messageLogs.value[0].source.name, 'devtools');
  expect(simController.messageLogs.value[0].data!['type'], 'themeUpdate');
  expect(
    (simController.messageLogs.value[0].data!['data']! as Map)['theme'],
    'light',
  );

  await tester.tap(toggleThemeButtonFinder);
  await tester.pumpAndSettle();
  expect(extensionManager.darkThemeEnabled.value, isTrue);
  expect(find.byType(LogListItem), findsNWidgets(2));
  expect(simController.messageLogs.value[1].source.name, 'devtools');
  expect(simController.messageLogs.value[1].data!['type'], 'themeUpdate');
  expect(
    (simController.messageLogs.value[1].data!['data']! as Map)['theme'],
    'dark',
  );
  await _clearLogs(tester, simController);
}

Future<void> _testShowNotification(
  WidgetTester tester,
  SimulatedDevToolsController simController,
) async {
  final showNotificationButtonFinder = find.descendant(
    of: find.byType(ElevatedButton),
    matching: find.text('Show DevTools notification'),
  );
  await tester.tap(showNotificationButtonFinder);
  await tester.pumpAndSettle();
  expect(find.byType(LogListItem), findsNWidgets(1));
  expect(simController.messageLogs.value[0].source.name, 'extension');
  expect(simController.messageLogs.value[0].data!['type'], 'showNotification');
  await _clearLogs(tester, simController);
}

Future<void> _testShowBannerMessage(
  WidgetTester tester,
  SimulatedDevToolsController simController,
) async {
  final showWarningButtonFinder = find
      .descendant(
        of: find.byType(ElevatedButton),
        matching: find.textContaining('Show DevTools warning'),
      )
      .first;
  await tester.tap(showWarningButtonFinder);
  await tester.pumpAndSettle();

  expect(find.byType(LogListItem), findsNWidgets(1));
  expect(simController.messageLogs.value[0].source.name, 'extension');
  expect(simController.messageLogs.value[0].data!['type'], 'showBannerMessage');
  await _clearLogs(tester, simController);
}

Future<void> _testCollapseEnvironmentPanel(
  WidgetTester tester,
  SimulatedDevToolsController simController,
) async {
  final split = tester.widget<Split>(find.byType(Split));

  final divider = find.byKey(split.dividerKey(0));
  final environmentPanel = split.children[1];

  final RenderBox environmentPanelRenderBox =
      tester.renderObject(find.byWidget(environmentPanel));
  final double environmentPanelRenderBoxWidth =
      environmentPanelRenderBox.size.width;

  // The full width of the [environmentPanel] plus the left and right padding.
  final double dragDistance =
      environmentPanelRenderBoxWidth + (2 * defaultSpacing);

  // Drag the divider to the right by the [dragDistance].
  await tester.drag(
    divider,
    Offset(
      dragDistance,
      0,
    ),
  );
  await tester.pumpAndSettle();

  final Rect simulatedDevToolsWrapperRect =
      tester.getRect(find.byType(SimulatedDevToolsWrapper));
  final Rect environmentPanelRect =
      tester.getRect(find.byWidget(environmentPanel));

  final bool simulatedDevToolsWrapperOverlapsEnvironmentPanel =
      simulatedDevToolsWrapperRect.overlaps(environmentPanelRect);

  // The environment panel is collapsed so the [SimulatedDevToolsWrapper] should
  // not overlap it.
  expect(simulatedDevToolsWrapperOverlapsEnvironmentPanel, isFalse);

  // Drag the divider to the left by the [dragDistance].
  //
  // This is to bring the 'Clear logs' button into view so it can be tapped.
  await tester.drag(
    divider,
    Offset(
      -dragDistance,
      0,
    ),
  );
  await tester.pumpAndSettle();
  await _clearLogs(tester, simController);
}

Future<void> _clearLogs(
  WidgetTester tester,
  SimulatedDevToolsController simController,
) async {
  await tester.tap(find.byTooltip('Clear logs'));
  await tester.pumpAndSettle();
  expect(simController.messageLogs.value, isEmpty);
  expect(find.byType(LogListItem), findsNothing);
}

void logStatus(String log) {
  // ignore: avoid_print, intentional print for test output
  print('TEST STATUS: $log');
}

class TestDevToolsExtension extends StatelessWidget {
  const TestDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Test DevTools Extension'),
      ),
      body: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CallingDevToolsExtensionsAPIsExample(),
        ],
      ),
    );
  }
}
