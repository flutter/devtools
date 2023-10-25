// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/screen.dart';
import '../../shared/ui/colors.dart';
import '../../shared/utils.dart';
import 'deep_link_list_view.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';
import 'select_project_view.dart';
import 'package:devtools_app_shared/ui.dart';



class DeepLinksScreen extends Screen {
  DeepLinksScreen() : super.fromMetaData(ScreenMetaData.deepLinks);

  static final id = ScreenMetaData.deepLinks.id;

  // TODO(https://github.com/flutter/devtools/issues/6013): write documentation.
  // @override
  // String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    return const DeepLinkPage();
  }
}

class DeepLinkPage extends StatefulWidget {
  const DeepLinkPage({super.key});

  @override
  State<DeepLinkPage> createState() => _DeepLinkPageState();
}

class _DeepLinkPageState extends State<DeepLinkPage>
    with ProvidedControllerMixin<DeepLinksController, DeepLinkPage> {
  @override
  void initState() {
    super.initState();
    ga.screen(gac.deeplink);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
  }

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder(
      valueListenable: controller.selectedProject,
      builder: (_, FlutterProject? project, __) {
        return project == null
            ? const SelectProjectView()
            : const DeepLinkListView();
      },
    );
  }
}

