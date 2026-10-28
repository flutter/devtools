// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/scaffold/about_dialog.dart';
import 'package:devtools_app/src/framework/scaffold/settings_dialog.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test_infra/responsive_layout_utils.dart';

/// The height of the status line. It is fixed, so the overflow menu trigger is
/// clamped to it. The trigger is [actionWidgetSize] wide and this tall.
const _footerHeight = statusLineHeight + 2 * densePadding;

/// The width, in logical pixels, at and above which the video tutorial link and
/// the embedded DevTools actions are shown inline. Below it they are in the
/// overflow menu.
const _inlineSecondaryItemsMinWidth = 900.0;

/// The compact width used for menu interaction tests. The Settings dialog's
/// content overflows below this width, so Settings is tested only here; see
/// [_expectDialogOpens].
const _compactInteractionWidth = 600.0;

const _noClientConnection = 'No client connection';

/// The URL of the video tutorial for [screen], as the footer link opens it.
String _tutorialUrl(ScreenMetaData screen) {
  return 'https://youtu.be/_EYk-E29edo${screen.tutorialVideoTimestamp}';
}

Finder _inStatusLine(Finder finder) {
  return find.descendant(of: find.byType(StatusLine), matching: finder);
}

/// The footer's connection status. It is text when there is room for it, and
/// otherwise an icon with a tooltip.
Finder _connectionStatus({required bool connected}) {
  if (connected) return _inStatusLine(find.byTooltip('Connected device'));
  final icon = _inStatusLine(find.byTooltip(_noClientConnection));
  return icon.evaluate().isNotEmpty
      ? icon
      : _inStatusLine(find.text(_noClientConnection));
}

Finder _trigger() => _inStatusLine(find.byTooltip('More actions'));

/// Gives keyboard focus to the overflow menu trigger by requesting focus on the
/// focus node that the trigger's button owns. It does not press Tab, so Tab
/// traversal to the trigger is not covered by these tests.
Future<void> _focusTrigger(WidgetTester tester) async {
  final icon = find.descendant(of: _trigger(), matching: find.byType(Icon));
  final triggerFocus = Focus.of(tester.element(icon));
  triggerFocus.requestFocus();
  await tester.pump();
  expect(
    FocusManager.instance.primaryFocus,
    triggerFocus,
    reason: 'The overflow menu trigger should take keyboard focus.',
  );
}

/// Opens the overflow menu from the keyboard, as a keyboard user would.
Future<void> _openMenuWithKeyboard(WidgetTester tester) async {
  await _focusTrigger(tester);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump(const Duration(milliseconds: 300));
  expect(
    find.byType(PopupMenuItem<VoidCallback>),
    findsWidgets,
    reason: 'Enter on the focused trigger should open the menu.',
  );
}

/// The label of the menu item that has keyboard focus, if any.
String? _focusedMenuItemLabel() {
  final focus = FocusManager.instance.primaryFocus?.context;
  final item = focus
      ?.findAncestorWidgetOfExactType<PopupMenuItem<VoidCallback>>();
  final child = item?.child;
  return child is Text ? child.data : null;
}

/// Activates the menu item labeled [label] from the keyboard: arrow keys move
/// focus through the open menu, and Enter activates the focused item.
Future<void> _activateMenuItem(WidgetTester tester, String label) async {
  for (var i = 0; i < 10 && _focusedMenuItemLabel() != label; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
  }
  expect(
    _focusedMenuItemLabel(),
    label,
    reason: '"$label" should be reachable with the arrow keys.',
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Asserts that [dialog] is shown, then closes it with its Close button.
///
/// The Settings dialog's checkbox rows overflow below 600 pixels (224 pixels at
/// 328 pixels), in shared dialog code that is reported separately from this
/// change. The About dialog has no overflow at 328 pixels.
Future<void> _expectDialogOpens(WidgetTester tester, Finder dialog) async {
  expect(dialog, findsOneWidget);
  await tester.tap(find.text('CLOSE'));
  await tester.pump(const Duration(milliseconds: 500));
  expect(dialog, findsNothing);
}

void main() {
  setUpAll(loadFonts);

  late FakeServiceConnectionManager connection;
  late NetworkController network;
  late LoggingController logging;
  late DebuggerController debugger;

  setUp(() {
    connection = createLayoutServiceConnection();
    setUpLayoutGlobals(connection);
    network = NetworkController();
    logging = LoggingController();
    debugger = DebuggerController();
  });

  Future<List<String>> pumpFooter(
    WidgetTester tester, {
    required String pageId,
    required bool embedded,
    required bool connected,
  }) {
    return collectFlutterErrors(
      () => pumpDevToolsScaffold(
        tester,
        pageId: pageId,
        embedded: embedded,
        connected: connected,
        connection: connection,
        network: network,
        logging: logging,
        debugger: debugger,
      ),
    );
  }

  group('footer layout', () {
    for (final embedded in [false, true]) {
      for (final connected in [true, false]) {
        final mode =
            '${embedded ? 'embedded' : 'standalone'}, '
            '${connected ? 'connected' : 'disconnected'}';

        for (final width in responsiveLayoutWidths) {
          testWidgetsWithWindowSize(
            'Network footer ($mode) has no overlap or clipping at $width',
            Size(width, responsiveLayoutHeight),
            (WidgetTester tester) async {
              final errors = await pumpFooter(
                tester,
                pageId: ScreenMetaData.network.id,
                embedded: embedded,
                connected: connected,
              );
              expect(errors, isEmpty, reason: errors.join('\n'));
              _expectFooterGeometry(tester, width: width, connected: connected);
              await stopNetworkPolling(tester, network);
            },
          );
        }
      }
    }

    for (final width in [328.0, 600.0, 901.0, 1400.0]) {
      testWidgetsWithWindowSize(
        'Logging footer (embedded) has no overlap or clipping at $width',
        Size(width, responsiveLayoutHeight),
        (WidgetTester tester) async {
          final errors = await pumpFooter(
            tester,
            pageId: ScreenMetaData.logging.id,
            embedded: true,
            connected: true,
          );
          expect(errors, isEmpty, reason: errors.join('\n'));
          _expectFooterGeometry(tester, width: width, connected: true);
        },
      );
    }
  });

  group('overflow menu', () {
    testWidgetsWithWindowSize(
      'trigger is a footer-height button with an accessible name',
      const Size(_compactInteractionWidth, responsiveLayoutHeight),
      (WidgetTester tester) async {
        final handle = tester.ensureSemantics();
        await pumpFooter(
          tester,
          pageId: ScreenMetaData.network.id,
          embedded: true,
          connected: true,
        );
        final trigger = _trigger();
        expect(trigger, findsOneWidget);
        expect(tester.getSize(trigger).width, actionWidgetSize);
        expect(
          tester.getSize(trigger).height,
          lessThanOrEqualTo(_footerHeight),
        );
        expect(
          tester.getSemantics(trigger),
          matchesSemantics(
            tooltip: 'More actions',
            isButton: true,
            isEnabled: true,
            isFocusable: true,
            hasEnabledState: true,
            hasTapAction: true,
            hasFocusAction: true,
            hasExpandedState: true,
          ),
        );
        handle.dispose();
        await stopNetworkPolling(tester, network);
      },
    );

    testWidgetsWithWindowSize(
      'opens with Enter, lists every action, and closes with Escape',
      const Size(_compactInteractionWidth, responsiveLayoutHeight),
      (WidgetTester tester) async {
        await pumpFooter(
          tester,
          pageId: ScreenMetaData.network.id,
          embedded: true,
          connected: true,
        );
        await _openMenuWithKeyboard(tester);
        for (final label in [
          'Watch tutorial',
          'Settings',
          'Report feedback',
          'About DevTools',
        ]) {
          expect(
            find.widgetWithText(PopupMenuItem<VoidCallback>, label),
            findsOneWidget,
          );
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(PopupMenuItem<VoidCallback>), findsNothing);
        await stopNetworkPolling(tester, network);
      },
    );

    testWidgetsWithWindowSize(
      'Settings from the menu opens the Settings dialog',
      const Size(_compactInteractionWidth, responsiveLayoutHeight),
      (WidgetTester tester) async {
        await pumpFooter(
          tester,
          pageId: ScreenMetaData.network.id,
          embedded: true,
          connected: true,
        );
        await _openMenuWithKeyboard(tester);
        final errors = await collectFlutterErrors(
          () => _activateMenuItem(tester, 'Settings'),
        );
        expect(errors, isEmpty, reason: errors.join('\n'));
        await _expectDialogOpens(tester, find.byType(SettingsDialog));
        await stopNetworkPolling(tester, network);
      },
    );

    for (final width in [_compactInteractionWidth, 328.0]) {
      testWidgetsWithWindowSize(
        'About from the menu opens the About dialog'
        ' at $width',
        Size(width, responsiveLayoutHeight),
        (WidgetTester tester) async {
          await pumpFooter(
            tester,
            pageId: ScreenMetaData.network.id,
            embedded: true,
            connected: true,
          );
          await _openMenuWithKeyboard(tester);
          final errors = await collectFlutterErrors(
            () => _activateMenuItem(tester, 'About DevTools'),
          );
          expect(errors, isEmpty, reason: errors.join('\n'));
          await _expectDialogOpens(tester, find.byType(DevToolsAboutDialog));
          await stopNetworkPolling(tester, network);
        },
      );
    }

    for (final width in [_compactInteractionWidth, 328.0]) {
      testWidgetsWithWindowSize(
        'Watch tutorial from the menu opens the same video and records the same '
        'analytics event as the inline link'
        ' at $width',
        Size(width, responsiveLayoutHeight),
        (WidgetTester tester) async {
          final urls = UrlLaunchRecorder()..install();
          final analytics = AnalyticsRecorder()..install();
          addTearDown(() {
            urls.dispose();
            analytics.dispose();
          });
          await pumpFooter(
            tester,
            pageId: ScreenMetaData.network.id,
            embedded: true,
            connected: true,
          );
          await _openMenuWithKeyboard(tester);
          await _activateMenuItem(tester, 'Watch tutorial');
          await tester.pump(const Duration(milliseconds: 200));

          expect(urls.launched, [_tutorialUrl(ScreenMetaData.network)]);
          expect(
            analytics.recordedSelection(
              screenId: ScreenMetaData.network.id,
              item: AnalyticsRecorder.tutorialItem(ScreenMetaData.network.id),
            ),
            isTrue,
          );
          await stopNetworkPolling(tester, network);
        },
      );
    }

    for (final width in [_compactInteractionWidth, 328.0]) {
      testWidgetsWithWindowSize(
        'Report feedback from the menu opens the issue tracker and records the '
        'analytics event'
        ' at $width',
        Size(width, responsiveLayoutHeight),
        (WidgetTester tester) async {
          final urls = UrlLaunchRecorder()..install();
          final analytics = AnalyticsRecorder()..install();
          addTearDown(() {
            urls.dispose();
            analytics.dispose();
          });
          await pumpFooter(
            tester,
            pageId: ScreenMetaData.network.id,
            embedded: true,
            connected: true,
          );
          await _openMenuWithKeyboard(tester);
          await _activateMenuItem(tester, 'Report feedback');
          await tester.pump(const Duration(milliseconds: 200));

          expect(urls.launched, hasLength(1));
          expect(
            urls.launched.single,
            startsWith('https://github.com/flutter/devtools/issues/new'),
          );
          expect(
            analytics.recordedSelection(
              screenId: 'main',
              item: 'feedbackButton',
            ),
            isTrue,
          );
          await stopNetworkPolling(tester, network);
        },
      );
    }

    testWidgetsWithWindowSize(
      'inline tutorial link at a wide width opens the same video',
      const Size(1400, responsiveLayoutHeight),
      (WidgetTester tester) async {
        final urls = UrlLaunchRecorder()..install();
        addTearDown(urls.dispose);
        await pumpFooter(
          tester,
          pageId: ScreenMetaData.network.id,
          embedded: true,
          connected: true,
        );
        expect(_trigger(), findsNothing);
        await tester.tap(_inStatusLine(find.text('Watch tutorial')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(urls.launched, [_tutorialUrl(ScreenMetaData.network)]);
        await stopNetworkPolling(tester, network);
      },
    );
  });
}

/// Asserts the geometry of the footer for the given configuration.
///
/// Every footer element must lie inside the status line, must not intersect
/// another element, and must not be truncated. Each primary control must be
/// hit-testable.
void _expectFooterGeometry(
  WidgetTester tester, {
  required double width,
  required bool connected,
}) {
  final statusLine = tester.getRect(find.byType(StatusLine));
  final docs = _inStatusLine(find.byType(DocumentationLink));
  final connection = _connectionStatus(connected: connected);
  final tutorial = _inStatusLine(find.text('Watch tutorial'));
  final trigger = _trigger();

  final elements = <String, Rect>{
    'docs': tester.getRect(docs),
    'connection': tester.getRect(connection),
  };
  if (trigger.evaluate().isNotEmpty) {
    elements['trigger'] = tester.getRect(trigger);
  }
  if (tutorial.evaluate().isNotEmpty) {
    elements['tutorial'] = tester.getRect(tutorial);
  }
  expectNoIntersections(elements);
  expectWithinBounds(elements, statusLine);

  expectTextNotTruncated(
    tester,
    find.descendant(of: docs, matching: find.byType(Text)),
  );
  final connectionText = connected
      ? find.descendant(of: connection, matching: find.byType(Text))
      : _inStatusLine(find.text(_noClientConnection));
  if (connectionText.evaluate().isNotEmpty) {
    expectTextNotTruncated(tester, connectionText);
  }

  final inlineSecondary = width >= _inlineSecondaryItemsMinWidth;
  expect(trigger, inlineSecondary ? findsNothing : findsOneWidget);
  expect(tutorial, inlineSecondary ? findsWidgets : findsNothing);
  expectInteractable(docs);
  if (trigger.evaluate().isNotEmpty) {
    expect(tester.getSize(trigger).width, actionWidgetSize);
    expectInteractable(trigger);
  }
}
