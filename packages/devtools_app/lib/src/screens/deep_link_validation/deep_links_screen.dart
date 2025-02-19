// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/framework/screen.dart';
import '../../shared/globals.dart';
import 'deep_link_list_view.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';
import 'project_root_selection/select_project_view.dart';

class DeepLinksScreen extends Screen {
  DeepLinksScreen() : super.fromMetaData(ScreenMetaData.deepLinks);

  static final id = ScreenMetaData.deepLinks.id;

  // TODO(https://github.com/flutter/devtools/issues/6013): write documentation.
  // @override
  // String get docPageId => id;

  @override
  String get docsUrl => 'https://flutter.dev/to/deep-link-tool';

  @override
  Widget buildScreenBody(BuildContext context) {
    return const DeepLinkPage();
  }
}

class DeepLinkPage extends StatefulWidget {
  const DeepLinkPage({super.key});

  @override
  State<DeepLinkPage> createState() => _DeepLinkPageState();
}

class _DeepLinkPageState extends State<DeepLinkPage> {
  late DeepLinksController controller;

  @override
  void initState() {
    super.initState();
    ga.screen(gac.deeplink);
    controller = screenControllers.lookup<DeepLinksController>();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.selectedProject,
      builder: (_, FlutterProject? project, _) {
        return project == null
            ? const SelectProjectView()
            : const DeepLinkListView();
      },
    );
  }
}
