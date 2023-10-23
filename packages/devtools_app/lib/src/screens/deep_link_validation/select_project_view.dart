// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/config_specific/server/server.dart' as server;
import '../../shared/directory_picker.dart';
import '../../shared/utils.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';

/// A view for selecting a Flutter project.
class SelectProjectView extends StatefulWidget {
  const SelectProjectView({super.key});

  @override
  State<SelectProjectView> createState() => _SelectProjectViewState();
}

class _SelectProjectViewState extends State<SelectProjectView>
    with ProvidedControllerMixin<DeepLinksController, SelectProjectView> {
  static const _kMessageSize = 24.0;
  bool _retrievingFlutterProject = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
  }

  void _handleDirectoryPicked(String directory) async {
    setState(() {
      _retrievingFlutterProject = true;
    });
    final List<String> androidVariants =
        await server.requestAndroidBuildVariants(directory);
    if (!context.mounted) {
      return;
    }
    if (androidVariants.isEmpty) {
      await showDialog(
        context: context,
        builder: (_) {
          return const AlertDialog(
            title: Text('You selected a non Flutter project'),
            content: Text(
              'Seems you selected a non Flutter project. If it is not intended, please reselect a Flutter project.',
            ),
            actions: [
              DialogCloseButton(),
            ],
          );
        },
      );
    } else {
      controller.selectedProject.value =
          FlutterProject(path: directory, androidVariants: androidVariants);
    }
    setState(() {
      _retrievingFlutterProject = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget? child;
    if (_retrievingFlutterProject) {
      child = const CenteredCircularProgressIndicator(size: _kMessageSize);
    } else {
      child = Text(
        'Pick a flutter project from your local file to check all deep links status',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).textTheme.displayLarge!.color,
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(defaultSpacing),
            child: child,
          ),
          DirectoryPicker(
            onDirectoryPicked: _handleDirectoryPicked,
            enabled: !_retrievingFlutterProject,
          ),
        ],
      ),
    );
  }
}
