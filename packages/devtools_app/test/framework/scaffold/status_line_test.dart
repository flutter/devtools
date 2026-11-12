// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

@TestOn('vm')
library;

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/framework/scaffold/about_dialog.dart';
import 'package:devtools_app/src/framework/scaffold/settings_dialog.dart';
import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

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

  setUp(() {
    connection = createLayoutServiceConnection();
    setUpLayoutGlobals(connection);
  });

  /// Pumps an isolated [StatusLine] for [screen] and returns any reported
  /// [FlutterError]s.
  ///
  /// The status line is a stateless widget, so it is tested in isolation
  /// rather than through `pumpDevToolsScaffold`. The tests use
  /// [_FakeStatusScreen], whose page status needs no screen controller, so no
  /// controller is initialized and no polling timers need cleanup.
  Future<List<String>> pumpStatusLine(
    WidgetTester tester, {
    required Screen screen,
    required bool embedded,
    required bool connected,
  }) {
    final embedMode = embedded ? EmbedMode.embedOne : EmbedMode.none;
    setGlobal(IdeTheme, IdeTheme(embedMode: embedMode));
    connection.serviceManager.setConnectedState(connected);
    return collectFlutterErrors(() async {
      await tester.pumpWidget(
        // The providers sit above the app so that dialogs opened from the
        // footer can read them, as they do in the app.
        MultiProvider(
          providers: [
            Provider<AnalyticsController>.value(
              value: AnalyticsController(
                enabled: false,
                shouldShowConsentMessage: false,
                consentMessage: 'fake message',
              ),
            ),
            Provider<ReleaseNotesController>.value(
              value: ReleaseNotesController(),
            ),
          ],
          child: wrapWithControllers(
            Scaffold(
              bottomNavigationBar: StatusLine(
                currentScreen: screen,
                isEmbedded: embedded,
                isConnected: connected,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    });
  }

  group('footer layout', () {
    for (final width in responsiveLayoutWidths) {
      testWidgetsWithWindowSize(
        'Network footer (standalone, connected) has no overlap or clipping '
        'at $width',
        Size(width, responsiveLayoutHeight),
        (WidgetTester tester) async {
          final errors = await pumpStatusLine(
            tester,
            screen: const _FakeStatusScreen(),
            embedded: false,
            connected: true,
          );
          expect(errors, isEmpty, reason: errors.join('\n'));
          _expectFooterGeometry(tester, width: width, connected: true);
        },
      );
    }

    // The embedded branch only adds the secondary actions, which the overflow
    // menu tests below cover; one narrow embedded smoke test exercises it.
    testWidgetsWithWindowSize(
      'Network footer (embedded, connected) has no overlap or clipping at 328',
      const Size(328, responsiveLayoutHeight),
      (WidgetTester tester) async {
        final errors = await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(),
          embedded: true,
          connected: true,
        );
        expect(errors, isEmpty, reason: errors.join('\n'));
        _expectFooterGeometry(tester, width: 328, connected: true);
      },
    );

    // The disconnected connection status is an icon with a tooltip at
    // [MediaSize.xs] and text above it, so two representative widths cover the
    // icon-vs-text behavior.
    for (final (width, showsIcon) in [(328.0, true), (1400.0, false)]) {
      testWidgetsWithWindowSize(
        'Network footer (standalone, disconnected) has no overlap or clipping '
        'at $width',
        Size(width, responsiveLayoutHeight),
        (WidgetTester tester) async {
          final errors = await pumpStatusLine(
            tester,
            // The real screens show no page status while disconnected.
            screen: const _FakeStatusScreen(statusText: null),
            embedded: false,
            connected: false,
          );
          expect(errors, isEmpty, reason: errors.join('\n'));
          _expectFooterGeometry(tester, width: width, connected: false);
          expect(
            _inStatusLine(find.byTooltip(_noClientConnection)),
            showsIcon ? findsOneWidget : findsNothing,
            reason: 'Expected ${showsIcon ? 'icon' : 'text'} at $width',
          );
          expect(
            _inStatusLine(find.text(_noClientConnection)),
            showsIcon ? findsNothing : findsOneWidget,
            reason: 'Expected ${showsIcon ? 'no text' : 'text'} at $width',
          );
        },
      );
    }

    testWidgetsWithWindowSize(
      'footer for a screen without a page status lays out cleanly',
      const Size(328, responsiveLayoutHeight),
      (WidgetTester tester) async {
        final errors = await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(statusText: null),
          embedded: false,
          connected: true,
        );
        expect(errors, isEmpty, reason: errors.join('\n'));
        expect(find.byType(StatusLine), findsOneWidget);
        final statusLine = tester.getRect(find.byType(StatusLine));
        final connection = tester.getRect(_connectionStatus(connected: true));
        expectWithinBounds({'connection': connection}, statusLine);
      },
    );

    // The page status is wrapped in a Flexible, not an Expanded, so that it
    // keeps its natural width and the spaceBetween alignment keeps spacing the
    // footer items evenly on wide screens, as it did before this change.
    for (final embedded in [false, true]) {
      testWidgetsWithWindowSize(
        'page status keeps its natural width on a wide screen '
        '(${embedded ? 'embedded' : 'standalone'})',
        const Size(1400, responsiveLayoutHeight),
        (WidgetTester tester) async {
          final errors = await pumpStatusLine(
            tester,
            screen: const _FakeStatusScreen(),
            embedded: embedded,
            connected: true,
          );
          expect(errors, isEmpty, reason: errors.join('\n'));

          final statusText = _inStatusLine(find.textContaining(' of '));
          expect(statusText, findsOneWidget);
          final textRect = tester.getRect(statusText);
          // The nearest ancestor Row is the page status box, which also
          // holds the recording spinner.
          final boxRect = tester.getRect(
            find.ancestor(of: statusText, matching: find.byType(Row)).first,
          );
          expect(
            boxRect.width,
            lessThanOrEqualTo(
              textRect.width + denseSpacing + smallProgressSize + 8.0,
            ),
            reason:
                'The page status should hug its content on a wide screen; '
                'an Expanded wrapper would stretch it to fill the slack.',
          );

          if (!embedded) {
            // With no trailing actions, the connection status is the last
            // item and stays pinned to the right edge.
            final connection = tester.getRect(
              _connectionStatus(connected: true),
            );
            final statusLine = tester.getRect(find.byType(StatusLine));
            expect(
              statusLine.right - connection.right,
              lessThanOrEqualTo(defaultSpacing + geometryTolerance),
            );
          }
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
        await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(),
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
      },
    );

    testWidgetsWithWindowSize(
      'opens with Enter, lists every action, and closes with Escape',
      const Size(_compactInteractionWidth, responsiveLayoutHeight),
      (WidgetTester tester) async {
        await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(),
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
      },
    );

    testWidgetsWithWindowSize(
      'Settings from the menu opens the Settings dialog',
      const Size(_compactInteractionWidth, responsiveLayoutHeight),
      (WidgetTester tester) async {
        await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(),
          embedded: true,
          connected: true,
        );
        await _openMenuWithKeyboard(tester);
        final errors = await collectFlutterErrors(
          () => _activateMenuItem(tester, 'Settings'),
        );
        expect(errors, isEmpty, reason: errors.join('\n'));
        await _expectDialogOpens(tester, find.byType(SettingsDialog));
      },
    );

    testWidgetsWithWindowSize(
      'About from the menu opens the About dialog',
      const Size(_compactInteractionWidth, responsiveLayoutHeight),
      (WidgetTester tester) async {
        await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(),
          embedded: true,
          connected: true,
        );
        await _openMenuWithKeyboard(tester);
        final errors = await collectFlutterErrors(
          () => _activateMenuItem(tester, 'About DevTools'),
        );
        expect(errors, isEmpty, reason: errors.join('\n'));
        await _expectDialogOpens(tester, find.byType(DevToolsAboutDialog));
      },
    );

    testWidgetsWithWindowSize(
      'Watch tutorial from the menu opens the same video and records the same '
      'analytics event as the inline link',
      const Size(_compactInteractionWidth, responsiveLayoutHeight),
      (WidgetTester tester) async {
        final urls = UrlLaunchRecorder()..install();
        final analytics = AnalyticsRecorder()..install();
        addTearDown(() {
          urls.dispose();
          analytics.dispose();
        });
        await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(),
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
      },
    );

    testWidgetsWithWindowSize(
      'Report feedback from the menu opens the issue tracker and records the '
      'analytics event',
      const Size(_compactInteractionWidth, responsiveLayoutHeight),
      (WidgetTester tester) async {
        final urls = UrlLaunchRecorder()..install();
        final analytics = AnalyticsRecorder()..install();
        addTearDown(() {
          urls.dispose();
          analytics.dispose();
        });
        await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(),
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
          analytics.recordedSelection(screenId: 'main', item: 'feedbackButton'),
          isTrue,
        );
      },
    );

    testWidgetsWithWindowSize(
      'inline tutorial link at a wide width opens the same video',
      const Size(1400, responsiveLayoutHeight),
      (WidgetTester tester) async {
        final urls = UrlLaunchRecorder()..install();
        addTearDown(urls.dispose);
        await pumpStatusLine(
          tester,
          screen: const _FakeStatusScreen(),
          embedded: true,
          connected: true,
        );
        expect(_trigger(), findsNothing);
        await tester.tap(_inStatusLine(find.text('Watch tutorial')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(urls.launched, [_tutorialUrl(ScreenMetaData.network)]);
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

/// A lightweight [Screen] for testing [StatusLine] in isolation.
///
/// Its page status needs no screen controller, so no controller is ever
/// initialized and no polling timers need cleanup (unlike a real screen,
/// whose `buildStatus` looks up a controller and would start one).
/// [statusText] is the page status content; `null` means no page status.
class _FakeStatusScreen extends Screen {
  const _FakeStatusScreen({this.statusText = '1 of 10 requests'})
    : super(_screenId);

  static const _screenId = 'network';

  final String? statusText;

  @override
  String? get docPageId => 'network';

  @override
  Widget buildScreenBody(BuildContext context) => const SizedBox();

  @override
  Widget? buildStatus(BuildContext context) {
    final text = statusText;
    if (text == null) return null;
    // Mimics the real page status: a spinner-sized element followed by text,
    // so the Flexible wrapper's natural-width behavior is exercised.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: smallProgressSize, height: smallProgressSize),
        const SizedBox(width: denseSpacing),
        Text(text),
      ],
    );
  }
}
