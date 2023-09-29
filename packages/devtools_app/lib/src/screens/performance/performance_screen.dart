// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/screen.dart';
import '../../shared/utils.dart';
import 'panes/controls/performance_controls.dart';
import 'panes/flutter_frames/flutter_frames_chart.dart';
import 'performance_controller.dart';
import 'tabbed_performance_view.dart';

// TODO(kenz): handle small screen widths better by using Wrap instead of Row
// where applicable.

class PerformanceScreen extends Screen {
  PerformanceScreen() : super.fromMetaData(ScreenMetaData.performance);

  static final id = ScreenMetaData.performance.id;

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    if (serviceConnection.serviceManager.connectedApp?.isDartWebAppNow ??
        false) {
      return const WebPerformanceScreenBody();
    }
    return const PerformanceScreenBody();
  }
}

class PerformanceScreenBody extends StatefulWidget {
  const PerformanceScreenBody({super.key});

  @override
  PerformanceScreenBodyState createState() => PerformanceScreenBodyState();
}

class PerformanceScreenBodyState extends State<PerformanceScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<PerformanceController, PerformanceScreenBody> {
  @override
  void initState() {
    super.initState();
    ga.screen(PerformanceScreen.id);
    addAutoDisposeListener(offlineController.offlineMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    maybePushUnsupportedFlutterVersionWarning(
      PerformanceScreen.id,
      supportedFlutterVersion: SemanticVersion(
        major: 2,
        minor: 3,
        // Specifying patch makes the version number more readable.
        // ignore: avoid_redundant_argument_values
        patch: 0,
        preReleaseMajor: 16,
        preReleaseMinor: 0,
      ),
    );
    maybePushDebugModePerformanceMessage(context, PerformanceScreen.id);

    if (!initController()) return;

    cancelListeners();
    addAutoDisposeListener(controller.loadingOfflineData);
    addAutoDisposeListener(controller.flutterFramesController.selectedFrame);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: controller.initialized,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            controller.loadingOfflineData.value) {
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const CenteredCircularProgressIndicator(),
          );
        }

        final offlineMode = offlineController.offlineMode.value;
        final isOfflineFlutterApp = offlineMode &&
            controller.offlinePerformanceData != null &&
            controller.offlinePerformanceData!.frames.isNotEmpty;
        return Column(
          children: [
            PerformanceControls(
              controller: controller,
              onClear: () => setState(() {}),
            ),
            const SizedBox(height: intermediateSpacing),
            if (isOfflineFlutterApp ||
                (!offlineMode &&
                    serviceConnection
                        .serviceManager.connectedApp!.isFlutterAppNow!))
              FlutterFramesChart(
                controller.flutterFramesController,
                offlineMode: offlineMode,
              ),
            const Expanded(child: TabbedPerformanceView()),
          ],
        );
      },
    );
  }
}

class WebPerformanceScreenBody extends StatelessWidget {
  const WebPerformanceScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isFlutterWebApp =
        serviceConnection.serviceManager.connectedApp?.isFlutterWebAppNow ??
            false;
    return Markdown(
      data: isFlutterWebApp ? flutterWebInstructionsMd : dartWebInstructionsMd,
      onTapLink: (_, url, __) {
        if (url != null) {
          unawaited(
            launchUrl(
              Uri.parse(url),
            ),
          );
        }
      },
    );
  }
}

const timelineLink =
    'https://api.flutter.dev/flutter/dart-developer/Timeline-class.html';
const timelineTaskLink =
    'https://api.flutter.dev/flutter/dart-developer/TimelineTask-class.html';
const debugBuildsLink =
    'https://api.flutter.dev/flutter/widgets/debugProfileBuildsEnabled.html';
const debugUserBuildsLink =
    'https://api.flutter.dev/flutter/widgets/debugProfileBuildsEnabledUserWidgets.html';
const debugLayoutsLink =
    'https://api.flutter.dev/flutter/rendering/debugProfileLayoutsEnabled.html';
const debugPaintsLink =
    'https://api.flutter.dev/flutter/rendering/debugProfilePaintsEnabled.html';
const profileModeLink = 'https://docs.flutter.dev/testing/build-modes#profile';
const performancePanelLink =
    'https://developer.chrome.com/docs/devtools/performance';

const flutterWebInstructionsMd = '''
# How to use Chrome DevTools for performance profiling

The Flutter framework emits timeline events as it works to build frames, draw 
scenes, and track other activity such as garbage collections. These events are 
exposed in the Chrome DevTools performance panel for debugging.

You can also emit your own timeline events using the `dart:developer` 
[Timeline]($timelineLink) and [TimelineTask]($timelineTaskLink) APIs for further
performance analysis.

## Optional flags to enhance tracing

- [debugProfileBuildsEnabled]($debugBuildsLink): Adds Timeline events for every Widget built.
- [debugProfileBuildsEnabledUserWidgets]($debugUserBuildsLink): Adds Timeline events for every user-created Widget built.
- [debugProfileLayoutsEnabled]($debugLayoutsLink): Adds Timeline events for every RenderObject layout.
- [debugProfilePaintsEnabled]($debugPaintsLink): Adds Timeline events for every RenderObject painted.

## Instructions

1. *[Optional]* Set any desired tracing flags to true from your app's main method.
2. Run your Flutter web app in [profile mode]($profileModeLink).
3. Open up the [Chrome DevTools' Performance panel]($performancePanelLink) for
your application, and start recording to capture timeline events.
''';

const dartWebInstructionsMd = '''
# How to use Chrome DevTools for performance profiling

Any events emitted using the `dart:developer` [Timeline]($timelineLink) and 
[TimelineTask]($timelineTaskLink) APIs are exposed in the Chrome DevTools 
performance panel.

Open up the [Chrome DevTools' Performance panel]($performancePanelLink) for
your application, and start recording to capture timeline events.
''';
