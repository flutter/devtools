// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/config_specific/import_export/import_export.dart';
import '../../shared/file_import.dart';
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
  Widget buildScreenBody(BuildContext context) {
    if (serviceConnection.serviceManager.connectedApp?.isDartWebAppNow ??
        false) {
      return const WebPerformanceScreenBody();
    }
    return const PerformanceScreenBody();
  }

  @override
  Widget buildDisconnectedScreenBody(BuildContext context) {
    return const DisconnectedPerformanceScreenBody();
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
    addAutoDisposeListener(offlineDataController.showingOfflineData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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

        final showingOfflineData =
            offlineDataController.showingOfflineData.value;
        final isOfflineFlutterApp = showingOfflineData &&
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
                (!showingOfflineData &&
                    serviceConnection
                        .serviceManager.connectedApp!.isFlutterAppNow!))
              FlutterFramesChart(
                controller.flutterFramesController,
                showingOfflineData: showingOfflineData,
                impellerEnabled: controller.impellerEnabled,
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

class DisconnectedPerformanceScreenBody extends StatelessWidget {
  const DisconnectedPerformanceScreenBody({super.key});

  static const importInstructions =
      'Open a performance data file that was previously saved from DevTools.';

  @override
  Widget build(BuildContext context) {
    return FileImportContainer(
      instructions: importInstructions,
      actionText: 'Load data',
      gaScreen: gac.performance,
      gaSelectionImport: gac.PerformanceEvents.openDataFile.name,
      gaSelectionAction: gac.PerformanceEvents.loadDataFromFile.name,
      onAction: (jsonFile) {
        Provider.of<ImportController>(context, listen: false)
            .importData(jsonFile, expectedScreenId: PerformanceScreen.id);
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
## How to use Chrome DevTools for performance profiling

The Flutter framework emits timeline events as it works to build frames, draw
scenes, and track other activity such as garbage collections. These events are
exposed in the Chrome DevTools performance panel for debugging.

You can also emit your own timeline events using the `dart:developer`
[Timeline]($timelineLink) and [TimelineTask]($timelineTaskLink) APIs for further
performance analysis.

### Optional flags to enhance tracing

- [debugProfileBuildsEnabled]($debugBuildsLink): Adds Timeline events for every Widget built.
- [debugProfileBuildsEnabledUserWidgets]($debugUserBuildsLink): Adds Timeline events for every user-created Widget built.
- [debugProfileLayoutsEnabled]($debugLayoutsLink): Adds Timeline events for every RenderObject layout.
- [debugProfilePaintsEnabled]($debugPaintsLink): Adds Timeline events for every RenderObject painted.

### Instructions

1. *[Optional]* Set any desired tracing flags to true from your app's main method.
2. Run your Flutter web app in [profile mode]($profileModeLink).
3. Open up the [Chrome DevTools' Performance panel]($performancePanelLink) for
your application, and start recording to capture timeline events.
''';

const dartWebInstructionsMd = '''
## How to use Chrome DevTools for performance profiling

Any events emitted using the `dart:developer` [Timeline]($timelineLink) and
[TimelineTask]($timelineTaskLink) APIs are exposed in the Chrome DevTools
performance panel.

Open up the [Chrome DevTools' Performance panel]($performancePanelLink) for
your application, and start recording to capture timeline events.
''';
