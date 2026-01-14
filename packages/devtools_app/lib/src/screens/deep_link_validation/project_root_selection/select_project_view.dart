// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/globals.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/server/server.dart' as server;
import '../../../shared/ui/common_widgets.dart';
import '../deep_links_controller.dart';
import '../deep_links_model.dart';
import 'root_selector.dart';

const _kLinearProgressIndicatorWidth = 280.0;

enum DeepLinksTarget { android, ios }

/// A view for selecting a Flutter project.
class SelectProjectView extends StatefulWidget {
  const SelectProjectView({super.key});

  @override
  State<SelectProjectView> createState() => _SelectProjectViewState();
}

class _SelectProjectViewState extends State<SelectProjectView> {
  late DeepLinksController controller;

  bool _retrievingFlutterProject = false;

  List<Uri>? projectRoots;

  @override
  void initState() {
    super.initState();
    unawaited(_initProjectRoots());
    controller = screenControllers.lookup<DeepLinksController>();
    unawaited(_validateProject());
  }

  Future<void> _initProjectRoots() async {
    final roots = await dtdManager.projectRoots();
    setState(() {
      projectRoots = roots?.uris;
    });
  }

  Future<void> _validateProject() async {
    final packageDirectoryForMainIsolate = await controller
        .packageDirectoryForMainIsolate();
    if (packageDirectoryForMainIsolate != null) {
      _handleValidateProject(packageDirectoryForMainIsolate);
    }
  }

  Future<List<String>> _requestAndridVariants(String directory) async {
    ga.timeStart(gac.deeplink, gac.AnalyzeFlutterProject.loadVariants.name);
    final androidVariants = await server.requestAndroidBuildVariants(directory);
    if (androidVariants.isEmpty || !mounted) {
      // If the project is not a Flutter project, cancel timing and return an empty list.
      ga.cancelTimingOperation(
        gac.deeplink,
        gac.AnalyzeFlutterProject.loadVariants.name,
      );
      return [];
    } else {
      ga.timeEnd(gac.deeplink, gac.AnalyzeFlutterProject.loadVariants.name);
      return androidVariants;
    }
  }

  Future<XcodeBuildOptions> _requestiOSBuildOptions(String directory) async {
    ga.timeStart(
      gac.deeplink,
      gac.AnalyzeFlutterProject.loadIosBuildOptions.name,
    );
    final iosBuildOptions = await server.requestIosBuildOptions(directory);
    ga.timeEnd(
      gac.deeplink,
      gac.AnalyzeFlutterProject.loadIosBuildOptions.name,
    );
    return iosBuildOptions;
  }

  Future<void> showNonFlutterProjectDialog() async {
    await showDialog(
      context: context,
      builder: (_) {
        return const DevToolsDialog(
          title: Text('You selected a non Flutter project'),
          content: Text(
            'It looks like you have selected a non-Flutter project. Please select a Flutter project instead.',
          ),
          actions: [DialogCloseButton()],
        );
      },
    );
    setState(() {
      _retrievingFlutterProject = false;
    });
  }

  void _handleValidateProject(String directory) async {
    setState(() {
      _retrievingFlutterProject = true;
    });
    final connected =
        serviceConnection.serviceManager.connectedState.value.connected;
    if (connected &&
        !serviceConnection.serviceManager.connectedApp!.isFlutterAppNow!) {
      await showNonFlutterProjectDialog();
      return;
    }

    final androidVariants = await _requestAndridVariants(directory);
    if (!mounted) {
      return;
    }
    XcodeBuildOptions iosBuildOptions = XcodeBuildOptions.empty;
    iosBuildOptions = await _requestiOSBuildOptions(directory);
    ga.select(
      gac.deeplink,
      gac.AnalyzeFlutterProject.flutterProjectSelected.name,
    );
    if (androidVariants.isEmpty && iosBuildOptions.configurations.isEmpty) {
      ga.select(
        gac.deeplink,
        gac.AnalyzeFlutterProject.flutterInvalidProjectSelected.name,
      );
      await _showFlutterProjectMissingBuildOptionsDialog(directory);
      return;
    }
    controller.selectedProject.value = FlutterProject(
      path: directory,
      androidVariants: androidVariants,
      iosBuildOptions: iosBuildOptions,
    );
    setState(() {
      _retrievingFlutterProject = false;
    });
  }

  Future<void> _showFlutterProjectMissingBuildOptionsDialog(
    String appPath,
  ) async {
    await showDialog(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        return DevToolsDialog(
          title: const Text('No iOS or Android build options found.'),
          content: SizedBox(
            width: defaultDialogWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DevTools could not verify the build options for this project.',
                ),
                const SizedBox(height: largeSpacing),
                ..._deepLinksInstructions(
                  theme: theme,
                  appPath: appPath,
                  target: DeepLinksTarget.android,
                ),
                const SizedBox(height: largeSpacing),
                ..._deepLinksInstructions(
                  theme: theme,
                  appPath: appPath,
                  target: DeepLinksTarget.ios,
                ),
              ],
            ),
          ),
          actions: const [DialogCloseButton()],
        );
      },
    );
    setState(() {
      _retrievingFlutterProject = false;
    });
  }

  List<Widget> _deepLinksInstructions({
    required ThemeData theme,
    required String appPath,
    required DeepLinksTarget target,
  }) {
    final commandStyle = theme.subtleTextStyle.copyWith(
      fontFamily: 'RobotoMono',
    );
    const commandPadding = EdgeInsets.symmetric(
      horizontal: denseSpacing,
      vertical: densePadding,
    );
    final title = switch (target) {
      DeepLinksTarget.android => 'Android',
      DeepLinksTarget.ios => 'iOS',
    };
    final directory = switch (target) {
      DeepLinksTarget.android => '/android',
      DeepLinksTarget.ios => '/ios',
    };
    final documentationUrl = switch (target) {
      DeepLinksTarget.android => 'https://docs.flutter.dev/deployment/android',
      DeepLinksTarget.ios => 'https://docs.flutter.dev/deployment/ios',
    };
    final command = switch (target) {
      DeepLinksTarget.android =>
        'flutter analyze --android --list-build-variants',
      DeepLinksTarget.ios => 'flutter analyze --ios --list-build-options',
    };

    return [
      Text('For $title', style: theme.textTheme.titleMedium),
      const SizedBox(height: intermediateSpacing),
      RichText(
        text: TextSpan(
          style: theme.regularTextStyle,
          children: [
            TextSpan(
              text:
                  'These are configured in the $directory directory. Please refer to the ',
            ),
            GaLinkTextSpan(
              link: GaLink(
                display: 'Flutter documentation',
                url: documentationUrl,
              ),
              context: context,
            ),
            const TextSpan(text: ' for more information.'),
          ],
        ),
      ),
      const SizedBox(height: intermediateSpacing),
      const Text(
        'To confirm your setup, run the following command in your terminal:',
      ),
      const SizedBox(height: denseSpacing),
      Card(
        child: Padding(
          padding: commandPadding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('$command $appPath', style: commandStyle)),
              CopyToClipboardControl(dataProvider: () => '$command $appPath'),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_retrievingFlutterProject) {
      return const _LoadingProjectView();
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(extraLargeSpacing),
          child: Text(
            'Select a local Flutter project to check the status of all deep links.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (!projectRoots.isNullOrEmpty) ...[
          ProjectRootsDropdown(
            projectRoots: projectRoots!,
            onValidatePressed: _handleValidateProject,
          ),
          const SizedBox(height: largeSpacing),
          Text(
            'Don\'t see your project in the list? Try entering your project below.',
            style: theme.subtleTextStyle,
          ),
          const SizedBox(height: extraLargeSpacing * 2),
        ],
        ProjectRootTextField(
          onValidatePressed: _handleValidateProject,
          enabled: !_retrievingFlutterProject,
        ),
      ],
    );
  }
}

class _LoadingProjectView extends StatelessWidget {
  const _LoadingProjectView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Project loading...', style: theme.regularTextStyle),
          Container(
            width: _kLinearProgressIndicatorWidth,
            padding: const EdgeInsets.symmetric(vertical: densePadding),
            child: const LinearProgressIndicator(),
          ),
          Text(
            'Loading your project usually takes about a minute.',
            style: theme.subtleTextStyle,
          ),
        ],
      ),
    );
  }
}
