// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/common_widgets.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/ui/colors.dart';
import '../../shared/utils.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';
import 'validation_details_view.dart';

const _kNotificationCardSize = Size(475, 132);
const _kSearchFieldFullWidth = 314.0;
const _kSearchFieldSplitScreenWidth = 280.0;

enum TableViewType {
  domainView,
  pathView,
  singleUrlView,
}

/// A view that display all deep links for the app.
class DeepLinkListView extends StatefulWidget {
  const DeepLinkListView({super.key});

  @override
  State<DeepLinkListView> createState() => _DeepLinkListViewState();
}

class _DeepLinkListViewState extends State<DeepLinkListView>
    with ProvidedControllerMixin<DeepLinksController, DeepLinkListView> {
  List<String> get androidVariants =>
      controller.selectedProject.value!.androidVariants;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
    callWhenControllerReady((_) {
      int releaseVariantIndex = controller
          .selectedProject.value!.androidVariants
          .indexWhere((variant) => variant.toLowerCase().contains('release'));
      // If not found, default to 0.
      releaseVariantIndex = max(releaseVariantIndex, 0);
      controller.selectedVariantIndex.value = releaseVariantIndex;
      controller.updateLinks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: TableViewType.values.length,
      child: const RoundedOutlinedBorder(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DeepLinkListViewTopPanel(),
            SizedBox(height: denseSpacing),
            Expanded(child: _DeepLinkListViewMainPanel()),
          ],
        ),
      ),
    );
  }
}

class _DeepLinkListViewMainPanel extends StatelessWidget {
  const _DeepLinkListViewMainPanel();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DeepLinksController>(context);
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<DisplayOptions>(
      valueListenable: controller.displayOptionsNotifier,
      builder: (context, displayOptions, _) =>
          ValueListenableBuilder<List<LinkData>?>(
        valueListenable: controller.linkDatasNotifier,
        builder: (context, linkDatas, _) {
          if (linkDatas == null) {
            return const CenteredCircularProgressIndicator();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AreaPaneHeader(
                title: Text('Validate and fix', style: textTheme.bodyLarge),
              ),
              displayOptions.showSplitScreen
                  ? const SizedBox.shrink()
                  : _NotificationCardSection(
                      domainErrorCount: displayOptions.domainErrorCount,
                      pathErrorCount: displayOptions.pathErrorCount,
                      controller: controller,
                    ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _AllDeepLinkDataTable(controller: controller),
                    ),
                    if (displayOptions.showSplitScreen)
                      Expanded(
                        child: ValueListenableBuilder<LinkData?>(
                          valueListenable: controller.selectedLink,
                          builder: (context, selectedLink, _) => TabBarView(
                            children: [
                              ValidationDetailScreen(
                                linkData: selectedLink!,
                                controller: controller,
                                viewType: TableViewType.domainView,
                              ),
                              ValidationDetailScreen(
                                linkData: selectedLink,
                                controller: controller,
                                viewType: TableViewType.pathView,
                              ),
                              ValidationDetailScreen(
                                linkData: selectedLink,
                                controller: controller,
                                viewType: TableViewType.singleUrlView,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DataTable extends StatelessWidget {
  const _DataTable({
    required this.linkDatas,
    required this.viewType,
    required this.controller,
  });
  final List<LinkData> linkDatas;
  final TableViewType viewType;
  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final ColumnData<LinkData> domain = DomainColumn(controller);
    final ColumnData<LinkData> path = PathColumn(controller);

    return Padding(
      padding: const EdgeInsets.only(top: denseSpacing),
      child: FlatTable(
        keyFactory: (node) => ValueKey(node.toString),
        data: linkDatas,
        dataKey: 'deep-links',
        autoScrollContent: true,
        headerColor: Theme.of(context).colorScheme.deeplinkTableHeaderColor,
        columns: <ColumnData>[
          ...(() {
            switch (viewType) {
              case TableViewType.domainView:
                return [domain, NumberOfAssociatedPathColumn()];
              case TableViewType.pathView:
                return [path, NumberOfAssociatedDomainColumn()];
              case TableViewType.singleUrlView:
                return [domain, path];
            }
          })(),
          SchemeColumn(controller),
          OSColumn(controller),
          if (!controller.displayOptionsNotifier.value.showSplitScreen) ...[
            StatusColumn(controller, viewType),
            NavigationColumn(),
          ],
        ],
        selectionNotifier: controller.selectedLink,
        defaultSortColumn: viewType == TableViewType.pathView ? path : domain,
        defaultSortDirection: SortDirection.ascending,
        onItemSelected: (item) =>
            controller.updateDisplayOptions(showSplitScreen: true),
      ),
    );
  }
}

class _DeepLinkListViewTopPanel extends StatelessWidget {
  const _DeepLinkListViewTopPanel();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DeepLinksController>(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.all(defaultSpacing),
          child: ValueListenableBuilder(
            valueListenable: controller.selectedVariantIndex,
            builder: (_, value, __) {
              return _AndroidVariantDropdown(
                androidVariants:
                    controller.selectedProject.value!.androidVariants,
                index: value,
                onVariantIndexSelected: (index) {
                  controller.selectedVariantIndex.value = index;
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AndroidVariantDropdown extends StatelessWidget {
  const _AndroidVariantDropdown({
    required this.androidVariants,
    required this.index,
    required this.onVariantIndexSelected,
  });

  final List<String> androidVariants;
  final int index;
  final ValueChanged<int> onVariantIndexSelected;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Android Variant:'),
        RoundedDropDownButton<int>(
          value: index,
          items: [
            for (int i = 0; i < androidVariants.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(androidVariants[i]),
              ),
          ],
          onChanged: (int? index) {
            onVariantIndexSelected(index!);
          },
        ),
      ],
    );
  }
}

class _AllDeepLinkDataTable extends StatelessWidget {
  const _AllDeepLinkDataTable({
    required this.controller,
  });
  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Column(
      children: <Widget>[
        OutlineDecoration(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: defaultSpacing),
                  child: Text(
                    'All deep links',
                    style: textTheme.bodyLarge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(denseSpacing),
                child: SizedBox(
                  width: controller.displayOptions.showSplitScreen
                      ? _kSearchFieldSplitScreenWidth
                      : _kSearchFieldFullWidth,
                  child: DevToolsClearableTextField(
                    labelText: '',
                    hintText: 'Search a URL, domain or path',
                    prefixIcon: const Icon(Icons.search),
                    onChanged: (value) {
                      controller.searchContent = value;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        TabBar(
          tabs: [
            Text(
              'Domain view',
              style: textTheme.bodyLarge,
            ),
            Text(
              'Path view',
              style: textTheme.bodyLarge,
            ),
            Text(
              'Single URL view',
              style: textTheme.bodyLarge,
            ),
          ],
          tabAlignment: TabAlignment.start,
          isScrollable: true,
        ),
        Expanded(
          child: ValueListenableBuilder<List<LinkData>?>(
            valueListenable: controller.linkDatasNotifier,
            builder: (context, linkDatas, _) => TabBarView(
              children: [
                _DataTable(
                  viewType: TableViewType.domainView,
                  linkDatas: controller.getLinkDatasByDomain,
                  controller: controller,
                ),
                _DataTable(
                  viewType: TableViewType.pathView,
                  linkDatas: controller.getLinkDatasByPath,
                  controller: controller,
                ),
                _DataTable(
                  viewType: TableViewType.singleUrlView,
                  linkDatas: linkDatas!,
                  controller: controller,
                ),
              ],
            ),
          ),
        ),
      ],
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
