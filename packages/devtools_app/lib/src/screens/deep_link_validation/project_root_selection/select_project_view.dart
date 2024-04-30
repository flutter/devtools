// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/globals.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/server/server.dart' as server;
import '../../../shared/utils.dart';
import '../deep_links_controller.dart';
import '../deep_links_model.dart';
import 'root_selector.dart';

const _kLinearProgressIndicatorWidth = 280.0;

/// A view for selecting a Flutter project.
class SelectProjectView extends StatefulWidget {
  const SelectProjectView({super.key});

  @override
  State<SelectProjectView> createState() => _SelectProjectViewState();
}

class _SelectProjectViewState extends State<SelectProjectView>
    with ProvidedControllerMixin<DeepLinksController, SelectProjectView> {
  bool _retrievingFlutterProject = false;

  List<Uri>? projectRoots;

  @override
  void initState() {
    super.initState();
    unawaited(_initProjectRoots());
  }

  Future<void> _initProjectRoots() async {
    final roots = await dtdManager.projectRoots();
    setState(() {
      projectRoots = roots?.uris;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    callWhenControllerReady((_) async {
      final packageDirectoryForMainIsolate =
          await controller.packageDirectoryForMainIsolate();
      if (packageDirectoryForMainIsolate != null) {
        _handleValidateProject(packageDirectoryForMainIsolate);
      }
    });
  }

  void _handleValidateProject(String directory) async {
    setState(() {
      _retrievingFlutterProject = true;
    });
    ga.timeStart(gac.deeplink, gac.AnalyzeFlutterProject.loadVariants.name);
    final List<String> androidVariants =
        await server.requestAndroidBuildVariants(directory);
    if (!mounted) {
      ga.cancelTimingOperation(
        gac.deeplink,
        gac.AnalyzeFlutterProject.loadVariants.name,
      );
      return;
    }
    if (androidVariants.isEmpty) {
      ga.cancelTimingOperation(
        gac.deeplink,
        gac.AnalyzeFlutterProject.loadVariants.name,
      );
      await showDialog(
        context: context,
        builder: (_) {
          return const DevToolsDialog(
            title: Text('You selected a non Flutter project'),
            content: Text(
              'It looks like you have selected a non-Flutter project. Please select a Flutter project instead.',
            ),
            actions: [
              DialogCloseButton(),
            ],
          );
        },
      );
    } else {
      ga.timeEnd(gac.deeplink, gac.AnalyzeFlutterProject.loadVariants.name);
      ga.select(
        gac.deeplink,
        gac.AnalyzeFlutterProject.flutterProjectSelected.name,
      );
      controller.selectedProject.value =
          FlutterProject(path: directory, androidVariants: androidVariants);
    }
    setState(() {
      _retrievingFlutterProject = false;
    });
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
            'Select a local flutter project to check the status of all deep links.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
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
          Text(
            'Project loading...',
            style: theme.regularTextStyle,
          ),
          Container(
            width: _kLinearProgressIndicatorWidth,
            padding: const EdgeInsets.symmetric(vertical: densePadding),
            child: const LinearProgressIndicator(),
          ),
          Text(
            'The first load will take longer than usual',
            style: theme.subtleTextStyle,
          ),
        ],
      ),
    );
  }
}
