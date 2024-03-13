// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('vm')
import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/controls/performance_controls.dart';
import 'package:devtools_app/src/screens/performance/panes/timeline_events/timeline_events_view.dart';
import 'package:devtools_app/src/screens/performance/tabbed_performance_view.dart';
import 'package:devtools_app/src/shared/feature_flags.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../test_infra/test_data/performance/sample_performance_data.dart';

void main() {
  const windowSize = Size(3000.0, 1000.0);

  setUp(() {
    setGlobal(
      DevToolsEnvironmentParameters,
      ExternalDevToolsEnvironmentParameters(),
    );
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(PreferencesController, PreferencesController());
    setGlobal(OfflineModeController, OfflineModeController());
    setGlobal(NotificationService, NotificationService());
    setGlobal(BannerMessagesController, BannerMessagesController());
  });

  group('$PerformanceScreen', () {
    late PerformanceController controller;
    late FakeServiceConnectionManager fakeServiceConnection;

    Future<void> setUpServiceManagerWithTimeline() async {
      fakeServiceConnection = FakeServiceConnectionManager(
        service: FakeServiceManager.createFakeService(
          timelineData: perfettoVmTimeline,
        ),
      );
      when(
        fakeServiceConnection.errorBadgeManager
            .errorCountNotifier('performance'),
      ).thenReturn(ValueNotifier<int>(0));
      final app = fakeServiceConnection.serviceManager.connectedApp!;
      when(app.initialized).thenReturn(Completer()..complete(true));
      when(app.isDartWebAppNow).thenReturn(false);
      when(app.isFlutterAppNow).thenReturn(true);
      when(app.isProfileBuild).thenAnswer((_) => Future.value(false));
      when(app.flutterVersionNow).thenReturn(
        FlutterVersion.parse(
          (await fakeServiceConnection.serviceManager.flutterVersion).json!,
        ),
      );
      when(app.isDartCliAppNow).thenReturn(false);
      when(app.isProfileBuildNow).thenReturn(true);
      when(app.isDartWebApp).thenAnswer((_) async => false);
      when(app.isProfileBuild).thenAnswer((_) async => false);
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
    }

    Future<void> pumpPerformanceScreen(
      WidgetTester tester, {
      bool runAsync = false,
    }) async {
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(
            builder: PerformanceScreen().build,
          ),
          performance: controller,
        ),
      );
      await tester.pumpAndSettle();

      if (runAsync) {
        // Await a small delay to allow the PerformanceController to complete
        // initialization.
        await Future.delayed(const Duration(seconds: 1));
      }

      expect(find.byType(PerformanceScreenBody), findsOneWidget);
    }

    setUp(() async {
      preferences.performance.showFlutterFramesChart.value = true;
      await setUpServiceManagerWithTimeline();
      await shortDelay();
      controller = PerformanceController();
      await controller.initialized;
    });

    testWidgets('builds its tab', (WidgetTester tester) async {
      final screen = PerformanceScreen();
      await tester.pumpWidget(
        wrapWithControllers(
          Builder(builder: screen.buildTab),
          performance: controller,
        ),
      );
      expect(find.text('Performance'), findsOneWidget);
    });

    testWidgetsWithWindowSize(
      'builds initial content',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          await pumpPerformanceScreen(tester, runAsync: true);
          await tester.pumpAndSettle();
          expect(find.byType(PerformanceScreenBody), findsOneWidget);
          expect(find.byType(WebPerformanceScreenBody), findsNothing);
          expect(find.byType(PerformanceControls), findsOneWidget);
          expect(find.byType(FlutterFramesChart), findsOneWidget);
          expect(find.byType(TabbedPerformanceView), findsOneWidget);
          expect(
            find.text('Select a frame above to view analysis data.'),
            findsOneWidget,
          );
        });
      },
    );

    testWidgetsWithWindowSize(
      'builds initial content for Dart web app',
      windowSize,
      (WidgetTester tester) async {
        setEnableExperiments();
        mockConnectedApp(
          fakeServiceConnection.serviceManager.connectedApp!,
          isFlutterApp: false,
          isProfileBuild: false,
          isWebApp: true,
        );
        await tester.pumpWidget(
          wrap(
            Builder(builder: PerformanceScreen().build),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PerformanceScreenBody), findsNothing);
        expect(find.byType(WebPerformanceScreenBody), findsOneWidget);
        expect(
          markdownFinder(
            'How to use Chrome DevTools for performance profiling',
          ),
          findsOneWidget,
        );

        // Make sure NO Flutter-specific information is included:
        expect(
          markdownFinder(
            'The Flutter framework emits timeline events',
          ),
          findsNothing,
        );
      },
    );

    testWidgetsWithWindowSize(
      'builds initial content for Flutter web app',
      windowSize,
      (WidgetTester tester) async {
        setEnableExperiments();
        mockConnectedApp(
          fakeServiceConnection.serviceManager.connectedApp!,
          isFlutterApp: true,
          isProfileBuild: false,
          isWebApp: true,
        );
        await tester.pumpWidget(
          wrap(
            Builder(builder: PerformanceScreen().build),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PerformanceScreenBody), findsNothing);
        expect(find.byType(WebPerformanceScreenBody), findsOneWidget);
        expect(
          markdownFinder(
            'How to use Chrome DevTools for performance profiling',
          ),
          findsOneWidget,
        );

        // Make sure Flutter-specific information is included:
        expect(
          markdownFinder(
            'The Flutter framework emits timeline events',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgetsWithWindowSize(
      'builds initial content for non-flutter app',
      windowSize,
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          mockConnectedApp(
            fakeServiceConnection.serviceManager.connectedApp!,
            isFlutterApp: false,
            isProfileBuild: false,
            isWebApp: false,
          );
          await pumpPerformanceScreen(tester, runAsync: true);
          await tester.pumpAndSettle();
          expect(find.byType(PerformanceControls), findsOneWidget);
          expect(find.byType(FlutterFramesChart), findsNothing);
          expect(find.byType(TabbedPerformanceView), findsOneWidget);
          expect(find.byType(TimelineEventsTabView), findsOneWidget);
        });
      },
    );

    group('controls', () {
      testWidgetsWithWindowSize(
        'can expand and collapse flutter frames chart',
        windowSize,
        (WidgetTester tester) async {
          await tester.runAsync(() async {
            await pumpPerformanceScreen(tester, runAsync: true);
            await tester.pumpAndSettle();

            final chartButtonFinder = find.byType(VisibilityButton);
            expect(chartButtonFinder, findsOneWidget);

            // The flutter frames chart is visible.
            expect(find.byType(FramesChartControls), findsOneWidget);
            expect(
              preferences.performance.showFlutterFramesChart.value,
              isTrue,
            );

            await tester.tap(chartButtonFinder);
            await tester.pumpAndSettle();

            // The flutter frames chart should no longer be visible.
            expect(find.byType(FramesChartControls), findsNothing);
            expect(
              preferences.performance.showFlutterFramesChart.value,
              isFalse,
            );

            await tester.tap(chartButtonFinder);
            await tester.pumpAndSettle();

            // The flutter frames chart should be visible again.
            expect(find.byType(FramesChartControls), findsOneWidget);
            expect(
              preferences.performance.showFlutterFramesChart.value,
              isTrue,
            );
          });
        },
      );

      // testWidgetsWithWindowSize(
      //   'clears timeline on clear',
      //   windowSize,
      //   (WidgetTester tester) async {
      //     await tester.runAsync(() async {
      //       await pumpPerformanceScreen(tester, runAsync: true);
      //       await tester.pumpAndSettle();

      //       // Ensure the Timeline Events tab is selected.
      //       final timelineEventsTabFinder = find.text('Timeline Events');
      //       expect(timelineEventsTabFinder, findsOneWidget);
      //       await tester.tap(timelineEventsTabFinder);
      //       await tester.pumpAndSettle();

      //       expect(
      //         controller.timelineEventsController.allTraceEvents,
      //         isNotEmpty,
      //       );
      //       expect(find.byType(FlutterFramesChart), findsOneWidget);
      //       expect(find.byType(TimelineFlameChart), findsOneWidget);
      //       expect(
      //         find.byKey(TimelineEventsView.emptyTimelineKey),
      //         findsNothing,
      //       );
      //       expect(find.byType(EventDetails), findsOneWidget);

      //       await tester.tap(find.byIcon(Icons.block));
      //       await tester.pumpAndSettle();
      //       expect(controller.timelineEventsController.allTraceEvents, isEmpty);
      //       expect(find.byType(FlutterFramesChart), findsOneWidget);
      //       expect(find.byType(TimelineFlameChart), findsNothing);
      //       expect(
      //         find.byKey(TimelineEventsView.emptyTimelineKey),
      //         findsOneWidget,
      //       );
      //       expect(find.byType(EventDetails), findsNothing);
      //     });
      //   },
      // );

      testWidgetsWithWindowSize(
        'opens enhance tracing overlay',
        windowSize,
        (WidgetTester tester) async {
          await tester.runAsync(() async {
            await pumpPerformanceScreen(tester, runAsync: true);
            await tester.pumpAndSettle();
            expect(find.text('Enhance Tracing'), findsOneWidget);
            await tester.tap(find.text('Enhance Tracing'));
            await tester.pumpAndSettle();
            expect(
              find.richTextContaining('frame times may be negatively affected'),
              findsOneWidget,
            );
            expect(
              find.richTextContaining(
                'you will need to reproduce activity in your app',
              ),
              findsOneWidget,
            );
            expect(
              find.richTextContaining('Track widget builds'),
              findsOneWidget,
            );
            expect(find.richTextContaining('Track layouts'), findsOneWidget);
            expect(find.richTextContaining('Track paints'), findsOneWidget);
            expect(
              find.richTextContaining('Track platform channels'),
              findsOneWidget,
            );
            expect(find.byType(MoreInfoLink), findsNWidgets(4));
          });
        },
      );

      testWidgetsWithWindowSize(
        'opens more debugging options overlay',
        windowSize,
        (WidgetTester tester) async {
          await tester.runAsync(() async {
            await pumpPerformanceScreen(tester, runAsync: true);
            await tester.pumpAndSettle();
            expect(find.text('More debugging options'), findsOneWidget);
            await tester.tap(find.text('More debugging options'));
            await tester.pumpAndSettle();
            expect(
              find.richTextContaining(
                'After toggling a rendering layer on/off, '
                'reproduce the activity in your app to see the effects',
              ),
              findsOneWidget,
            );
            expect(
              find.richTextContaining('Render Clip layers'),
              findsOneWidget,
            );
            expect(
              find.richTextContaining('Render Opacity layers'),
              findsOneWidget,
            );
            expect(
              find.richTextContaining('Render Physical Shape layers'),
              findsOneWidget,
            );
            expect(
              find.richTextContaining(
                "These debugging options aren't available in profile mode. "
                'To use them, run your app in debug mode.',
              ),
              findsOneWidget,
            );
            expect(find.byType(MoreInfoLink), findsNWidgets(3));
          });
        },
      );

      testWidgetsWithWindowSize(
        'hides warning in debugging options overlay when in debug mode',
        windowSize,
        (WidgetTester tester) async {
          when(
            fakeServiceConnection
                .serviceManager.connectedApp!.isProfileBuildNow,
          ).thenReturn(false);

          await tester.runAsync(() async {
            await pumpPerformanceScreen(tester, runAsync: true);
            await tester.pumpAndSettle();
            expect(find.text('More debugging options'), findsOneWidget);
            await tester.tap(find.text('More debugging options'));
            await tester.pumpAndSettle();

            expect(
              find.richTextContaining(
                "These debugging options aren't available in profile mode. "
                'To use them, run your app in debug mode.',
              ),
              findsNothing,
            );
          });
        },
      );
    });
  });
}

Finder markdownFinder(String textMatch) => find.byWidgetPredicate(
      (widget) => widget is Markdown && widget.data.contains(textMatch),
    );
