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

const _kNotificationCardSize = Size(475, 132);

enum TableViewType {
  domainView,
  pathView,
  singleUrlView,
}

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
    controller.initLinkDatas();
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

class _PathCheckTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notAvailableCell = DataCell(
      Text(
        'Not available',
        style: TextStyle(
          color: Theme.of(context).colorScheme.deeplinkUnavailableColor,
        ),
      ),
    );
    return Opacity(
      opacity: 0.5,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(
          Theme.of(context).colorScheme.deeplinkTableHeaderColor,
        ),
        dataRowColor: MaterialStateProperty.all(
          Theme.of(context).colorScheme.alternatingBackgroundColor2,
        ),
        columns: const [
          DataColumn(label: Text('OS')),
          DataColumn(label: Text('Issue type')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          DataRow(
            cells: [
              const DataCell(Text('Android')),
              const DataCell(Text('Intent filter')),
              notAvailableCell,
            ],
          ),
          DataRow(
            cells: [
              const DataCell(Text('iOS')),
              const DataCell(Text('Associated domain')),
              notAvailableCell,
            ],
          ),
          DataRow(
            cells: [
              const DataCell(Text('Android, iOS')),
              const DataCell(Text('URL format')),
              notAvailableCell,
            ],
          ),
          DataRow(
            cells: [
              const DataCell(Text('Android, iOS')),
              const DataCell(Text('Routing')),
              notAvailableCell,
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationCardSection extends StatelessWidget {
  const _NotificationCardSection({
    required this.domainErrorCount,
    required this.pathErrorCount,
    required this.controller,
  });

  final int domainErrorCount;
  final int pathErrorCount;
  final DeepLinksController controller;
  @override
  Widget build(BuildContext context) {
    if (domainErrorCount == 0 && domainErrorCount == 0) {
      return const SizedBox.shrink();
    }
    return OutlineDecoration(
      child: Padding(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Row(
          children: [
            if (domainErrorCount > 0)
              _NotificationCard(
                title: '$domainErrorCount domain not verified',
                description:
                    'This affects all deep links. Fix issues to make users go directly to your app.',
                actionButton: TextButton(
                  onPressed: () {
                    // Switch to the domain view. Select the first link with domain error and show the split screen.
                    DefaultTabController.of(context).index = 0;
                    controller.selectedLink.value = controller
                        .getLinkDatasByDomain
                        .where((element) => element.domainError)
                        .first;
                    controller.updateDisplayOptions(showSplitScreen: true);
                  },
                  child: const Text('Fix domain'),
                ),
              ),
            if (domainErrorCount > 0 && pathErrorCount > 0)
              const SizedBox(width: defaultSpacing),
            if (pathErrorCount > 0)
              _NotificationCard(
                title: '$pathErrorCount path not working',
                description:
                    'Fix these path to make sure users are directed to your app',
                actionButton: TextButton(
                  onPressed: () {
                    // Switch to the path view. Select the first link with path error and show the split screen.
                    DefaultTabController.of(context).index = 1;
                    controller.selectedLink.value = controller
                        .getLinkDatasByPath
                        .where((element) => element.pathError)
                        .first;
                    controller.updateDisplayOptions(showSplitScreen: true);
                  },
                  child: const Text('Fix path'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.description,
    required this.actionButton,
  });

  final String title;
  final String description;
  final Widget actionButton;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox.fromSize(
      size: _kNotificationCardSize,
      child: Card(
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            defaultSpacing,
            defaultSpacing,
            defaultSpacing,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error, color: colorScheme.error),
              const SizedBox(width: denseSpacing),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium!
                          .copyWith(color: colorScheme.onSurface),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).subtleTextStyle,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: actionButton,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
