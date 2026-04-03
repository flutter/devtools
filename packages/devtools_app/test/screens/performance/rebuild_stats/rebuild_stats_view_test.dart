// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/performance/panes/rebuild_stats/rebuild_stats.dart';
import 'package:devtools_app/src/screens/performance/panes/rebuild_stats/rebuild_stats_model.dart';
import 'package:devtools_app/src/screens/performance/panes/flutter_frames/flutter_frame_model.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:devtools_test/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('RebuildStatsView', () {
    late FakeServiceConnectionManager fakeServiceConnection;
    late RebuildCountModel model;
    late ValueNotifier<FlutterFrame?> selectedFrame;

    setUp(() {
      fakeServiceConnection = FakeServiceConnectionManager();
      final app = fakeServiceConnection.serviceManager.connectedApp!;
      when(app.initialized).thenReturn(Completer()..complete(true));
      when(app.isDartWebAppNow).thenReturn(false);
      when(app.isFlutterAppNow).thenReturn(true);
      when(app.isDartCliAppNow).thenReturn(false);
      when(app.isDartWebApp).thenAnswer((_) async => false);
      when(app.isProfileBuild).thenAnswer((_) async => false);
      setGlobal(ServiceConnectionManager, fakeServiceConnection);
      setGlobal(IdeTheme, IdeTheme());
      setGlobal(NotificationService, NotificationService());
      setGlobal(BannerMessagesController, BannerMessagesController());
      setGlobal(PreferencesController, PreferencesController());
      setGlobal(OfflineDataController, OfflineDataController());
      model = RebuildCountModel();
      selectedFrame = ValueNotifier<FlutterFrame?>(null);
    });

    testWidgets(
      'shows message when running in profile mode',
      (WidgetTester tester) async {
        final app = fakeServiceConnection.serviceManager.connectedApp!;
        when(app.isProfileBuildNow).thenReturn(true);

        await tester.pumpWidget(
          wrapWithControllers(
            RebuildStatsView(
              model: model,
              selectedFrame: selectedFrame,
            ),
          ),
        );
        await tester.pump();

        expect(
          find.textContaining('Widget rebuild counts are only available'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows normal UI when running in debug mode',
      (WidgetTester tester) async {
        final app = fakeServiceConnection.serviceManager.connectedApp!;
        when(app.isProfileBuildNow).thenReturn(false);

        await tester.pumpWidget(
          wrapWithControllers(
            RebuildStatsView(
              model: model,
              selectedFrame: selectedFrame,
            ),
          ),
        );
        await tester.pump();

        expect(
          find.textContaining('Widget rebuild counts are only available'),
          findsNothing,
        );
      },
    );
  });
}
