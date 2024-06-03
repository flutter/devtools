// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/common_widgets.dart';
import '../../shared/feature_flags.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/ui/colors.dart';
import '../../shared/ui/tab.dart';
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
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    initController();
    callWhenControllerReady((_) {
      controller.selectedAndroidVariantIndex.value = _getDefaultVariantIndex(
        controller.selectedProject.value!.androidVariants,
        defaultVariant: 'release',
      );
      if (FeatureFlags.deepLinkIosCheck) {
        controller.selectedIosConfigurationIndex.value =
            _getDefaultVariantIndex(
          controller.selectedProject.value!.iosBuildOptions.configurations,
          defaultVariant: 'release',
        );
        controller.selectedIosTargetIndex.value = _getDefaultVariantIndex(
          controller.selectedProject.value!.iosBuildOptions.configurations,
          defaultVariant: 'runner',
        );
      }
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
            Expanded(child: _DeepLinkListViewMainPanel()),
          ],
        ),
      ),
    );
  }

  int _getDefaultVariantIndex(List<String> variants,
      {required String defaultVariant}) {
    final index = variants.indexWhere(
      (variant) => variant.caseInsensitiveContains(defaultVariant),
    );
    // If not found, default to 0.
    return max(index, 0);
  }
}

class _DeepLinkListViewMainPanel extends StatelessWidget {
  const _DeepLinkListViewMainPanel();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DeepLinksController>(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder<PagePhase>(
      valueListenable: controller.pagePhase,
      builder: (context, pagePhase, _) {
        switch (pagePhase) {
          case PagePhase.emptyState:
          case PagePhase.linksLoading:
          case PagePhase.linksValidating:
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CenteredCircularProgressIndicator(),
                const SizedBox(height: densePadding),
                Text(
                  pagePhase == PagePhase.linksLoading
                      ? 'Loading deep links...'
                      : 'Validating deep links...',
                  style: theme.subtleTextStyle,
                ),
              ],
            );
          case PagePhase.linksValidated:
            return const _ValidatedDeepLinksView();
          case PagePhase.noLinks:
            // TODO(hangyujin): This is just a place holder to add UI.
            return const CenteredMessage(
              'Your Flutter project has no Links to verify.',
            );
          case PagePhase.analyzeErrorPage:
            assert(controller.currentAppLinkSettings?.error != null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to retrieve deep links from the Flutter project. '
                  'This can be a result of errors in the project.',
                ),
                const SizedBox(height: densePadding),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Text(
                        controller.currentAppLinkSettings!.error!,
                        style: theme.errorTextStyle,
                      ),
                    ),
                  ),
                ),
              ],
            );

          case PagePhase.validationErrorPage:
            // TODO(hangyujin): This is just a place holder to add Error handling.
            return const CenteredMessage('Error validating domain ');
        }
      },
    );
  }
}

class _ValidatedDeepLinksView extends StatelessWidget {
  const _ValidatedDeepLinksView();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DeepLinksController>(context);
    return ValueListenableBuilder<DisplayOptions>(
      valueListenable: controller.displayOptionsNotifier,
      builder: (context, displayOptions, _) {
        if (displayOptions.showSplitScreen) {
          return Row(
            children: [
              Expanded(
                child: _AllDeepLinkDataTable(controller: controller),
              ),
              VerticalDivider(
                width: 1.0,
                color: Theme.of(context).focusColor,
              ),
              Expanded(
                child: ValueListenableBuilder<LinkData?>(
                  valueListenable: controller.selectedLink,
                  builder: (context, selectedLink, _) => TabBarView(
                    children: [
                      ValidationDetailView(
                        linkData: selectedLink!,
                        controller: controller,
                        viewType: TableViewType.domainView,
                      ),
                      ValidationDetailView(
                        linkData: selectedLink,
                        controller: controller,
                        viewType: TableViewType.pathView,
                      ),
                      ValidationDetailView(
                        linkData: selectedLink,
                        controller: controller,
                        viewType: TableViewType.singleUrlView,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationCardSection(
              domainErrorCount: displayOptions.domainErrorCount,
              pathErrorCount: displayOptions.pathErrorCount,
              controller: controller,
            ),
            Expanded(
              child: _AllDeepLinkDataTable(controller: controller),
            ),
          ],
        );
      },
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
    final domain = DomainColumn(controller);
    final path = PathColumn(controller);

    return Padding(
      padding: const EdgeInsets.only(top: denseSpacing),
      child: FlatTable<LinkData>(
        keyFactory: (node) => ValueKey(node.toString),
        data: linkDatas,
        dataKey: 'deep-links',
        autoScrollContent: true,
        headerColor: Theme.of(context).colorScheme.deeplinkTableHeaderColor,
        fillWithEmptyRows: true,
        columns: <ColumnData<LinkData>>[
          ...(() {
            switch (viewType) {
              case TableViewType.domainView:
                return [domain, NumberOfAssociatedPathColumn()];
              case TableViewType.pathView:
                return [path, NumberOfAssociatedDomainColumn()];
              case TableViewType.singleUrlView:
                return <ColumnData<LinkData>>[domain, path];
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
        defaultSortColumn: (viewType == TableViewType.pathView ? path : domain)
            as ColumnData<LinkData>,
        defaultSortDirection: SortDirection.ascending,
        sortOriginalData: true,
        onItemSelected: (linkdata) {
          controller.selectLink(linkdata!);
          controller.updateDisplayOptions(showSplitScreen: true);
        },
        enableHoverHandling: true,
      ),
    );
  }
}

class _DeepLinkListViewTopPanel extends StatelessWidget {
  const _DeepLinkListViewTopPanel();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DeepLinksController>(context);
    return AreaPaneHeader(
      roundedTopBorder: false,
      includeTopBorder: false,
      includeBottomBorder: false,
      tall: true,
      title: Row(
        children: [
          Text(
            'Validate and fix',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          _VariantDropdown(
            title: 'Android Variant:',
            valuenotifier: controller.selectedAndroidVariantIndex,
            variants: controller.selectedProject.value!.androidVariants,
          ),
          if (FeatureFlags.deepLinkIosCheck) ...[
            const SizedBox(width: denseSpacing),
            _VariantDropdown(
              title: 'iOS Configuration:',
              valuenotifier: controller.selectedIosConfigurationIndex,
              variants: controller
                  .selectedProject.value!.iosBuildOptions.configurations,
            ),
            const SizedBox(width: denseSpacing),
            _VariantDropdown(
              title: 'iOS Target:',
              valuenotifier: controller.selectedIosTargetIndex,
              variants:
                  controller.selectedProject.value!.iosBuildOptions.targets,
            ),
          ],
        ],
      ),
    );
  }
}

class _VariantDropdown extends StatelessWidget {
  const _VariantDropdown({
    required this.valuenotifier,
    required this.variants,
    required this.title,
  });
  final ValueNotifier<int> valuenotifier;
  final List<String> variants;
  final String title;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: valuenotifier,
      builder: (_, index, __) {
        return Row(
          children: [
            Text(title),
            RoundedDropDownButton<int>(
              roundedCornerOptions: RoundedCornerOptions.empty,
              value: index,
              items: [
                for (int i = 0; i < variants.length; i++)
                  DropdownMenuItem<int>(value: i, child: Text(variants[i])),
              ],
              onChanged: (int? newIndex) {
                valuenotifier.value = newIndex!;
              },
            ),
          ],
        );
      },
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
    final textTheme = Theme.of(context).textTheme;
    const gaPrefix = 'deepLinkTab';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OutlineDecoration(
          showRight: false,
          showLeft: false,
          child: SizedBox(
            height: actionWidgetSize,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: defaultSpacing),
                  child: Text(
                    'All deep links',
                    style: textTheme.titleSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
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
                      controller: controller.textEditingController,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: defaultHeaderHeight,
          child: TabBar(
            tabs: [
              DevToolsTab.create(
                tabName: 'Domain view',
                gaPrefix: gaPrefix,
              ),
              DevToolsTab.create(
                tabName: 'Path view',
                gaPrefix: gaPrefix,
              ),
              DevToolsTab.create(
                tabName: 'Single URL view',
                gaPrefix: gaPrefix,
              ),
            ],
            tabAlignment: TabAlignment.start,
            isScrollable: true,
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<ValidatedLinkDatas>(
            valueListenable: controller.displayLinkDatasNotifier,
            builder: (context, linkDatas, _) => TabBarView(
              children: [
                _DataTable(
                  viewType: TableViewType.domainView,
                  linkDatas: linkDatas.byDomain,
                  controller: controller,
                ),
                _DataTable(
                  viewType: TableViewType.pathView,
                  linkDatas: linkDatas.byPath,
                  controller: controller,
                ),
                _DataTable(
                  viewType: TableViewType.singleUrlView,
                  linkDatas: linkDatas.all,
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
    if (domainErrorCount == 0 && pathErrorCount == 0) {
      return const SizedBox.shrink();
    }
    return OutlineDecoration.onlyTop(
      child: Padding(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Row(
          children: [
            if (domainErrorCount > 0)
              NotificationCard(
                title: '$domainErrorCount domain not verified',
                description:
                    'This affects all deep links. Fix issues to make users go directly to your app.',
                actionButton: TextButton(
                  onPressed: () {
                    // Switch to the domain view. Select the first link with domain error and show the split screen.
                    DefaultTabController.of(context).index = 0;
                    controller.autoSelectLink(TableViewType.domainView);
                    controller.updateDisplayOptions(showSplitScreen: true);
                  },
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: intermediateSpacing),
                    child: Text('Fix domain'),
                  ),
                ),
              ),
            if (domainErrorCount > 0 && pathErrorCount > 0)
              const SizedBox(width: defaultSpacing),
            if (pathErrorCount > 0)
              NotificationCard(
                title: '$pathErrorCount path not working',
                description:
                    'Fix these path to make sure users are directed to your app',
                actionButton: TextButton(
                  onPressed: () {
                    // Switch to the path view. Select the first link with path error and show the split screen.
                    DefaultTabController.of(context).index = 1;
                    controller.autoSelectLink(TableViewType.pathView);
                    controller.updateDisplayOptions(showSplitScreen: true);
                  },
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: intermediateSpacing),
                    child: Text('Fix path'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.title,
    required this.description,
    required this.actionButton,
  });

  final String title;
  final String description;
  final Widget actionButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox.fromSize(
      size: _kNotificationCardSize,
      child: Card(
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            defaultSpacing,
            defaultSpacing,
            densePadding,
            denseSpacing,
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
                    Text(title),
                    Text(
                      description,
                      style: theme.subtleTextStyle,
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
