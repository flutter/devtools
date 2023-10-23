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
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: TableViewType.values.length,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeepLinkListViewTopPanel(),
          SizedBox(height: denseSpacing),
          Expanded(child: _DeepLinkListViewMainPanel()),
        ],
      ),
    );
  }
}

class _DeepLinkListViewMainPanel extends StatelessWidget {
  const _DeepLinkListViewMainPanel();

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DeepLinksController>(context);
    return ValueListenableBuilder<List<LinkData>?>(
      valueListenable: controller.linkDatasNotifier,
      builder: (context, linkDatas, _) {
        if (linkDatas == null) {
          return const CenteredCircularProgressIndicator();
        }
        return Column(
          children: [
            AreaPaneHeader(
              title: Text(
                'All deep links',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              actions: [
                SizedBox(
                  width: wideSearchFieldWidth,
                  child: DevToolsClearableTextField(
                    labelText: '',
                    hintText: 'Search a URL, domain or path',
                    prefixIcon: const Icon(Icons.search),
                    onChanged: (value) {
                      controller.searchContent = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: denseSpacing),
            const TabBar(
              tabs: [
                Text('Domain view'),
                Text('Path view'),
                Text('Single URL view'),
              ],
              tabAlignment: TabAlignment.start,
              isScrollable: true,
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: controller.showSpitScreenNotifier,
                builder: (context, showSpitScreen, _) => TabBarView(
                  children: [
                    _DataTableWithValidationDetails(
                      tableView: TableViewType.domainView,
                      linkDatas: controller.getLinkDatasByDomain,
                      controller: controller,
                      showSpitScreen: showSpitScreen,
                    ),
                    _DataTableWithValidationDetails(
                      tableView: TableViewType.pathView,
                      linkDatas: controller.getLinkDatasByPath,
                      controller: controller,
                      showSpitScreen: showSpitScreen,
                    ),
                    _DataTableWithValidationDetails(
                      tableView: TableViewType.singleUrlView,
                      linkDatas: linkDatas,
                      controller: controller,
                      showSpitScreen: showSpitScreen,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DataTableWithValidationDetails extends StatelessWidget {
  const _DataTableWithValidationDetails({
    required this.linkDatas,
    required this.tableView,
    required this.controller,
    required this.showSpitScreen,
  });
  final List<LinkData> linkDatas;
  final TableViewType tableView;
  final DeepLinksController controller;
  final bool showSpitScreen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DataTable(
            tableView: tableView,
            linkDatas: linkDatas,
            controller: controller,
          ),
        ),
        if (showSpitScreen)
          Expanded(
            child: ValueListenableBuilder<LinkData?>(
              valueListenable: controller.selectedLink,
              builder: (context, selectedLink, _) => _ValidationDetailScreen(
                tableView: tableView,
                linkData: selectedLink!,
                controller: controller,
              ),
            ),
          ),
      ],
    );
  }
}

class _DataTable extends StatelessWidget {
  const _DataTable({
    required this.linkDatas,
    required this.tableView,
    required this.controller,
  });
  final List<LinkData> linkDatas;
  final TableViewType tableView;
  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final ColumnData<LinkData> domain = DomainColumn();
    final ColumnData<LinkData> path = PathColumn();

    return FlatTable(
      keyFactory: (node) => ValueKey(node.toString),
      data: linkDatas,
      dataKey: 'deep-links',
      autoScrollContent: true,
      columns: <ColumnData>[
        if (tableView != TableViewType.pathView) domain,
        if (tableView != TableViewType.domainView) path,
        SchemeColumn(),
        OSColumn(),
        if (!controller.showSpitScreen) ...[
          StatusColumn(),
          NavigationColumn(),
        ],
      ],
      selectionNotifier: controller.selectedLink,
      defaultSortColumn: tableView == TableViewType.pathView ? path : domain,
      defaultSortDirection: SortDirection.ascending,
      onItemSelected: (item) => controller.showSpitScreenNotifier.value = true,
    );
  }
}

class _ValidationDetailScreen extends StatelessWidget {
  const _ValidationDetailScreen({
    required this.linkData,
    required this.tableView,
    required this.controller,
  });

  final LinkData linkData;
  final TableViewType tableView;
  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: largeSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Selected deep link validation details'),
              IconButton(
                onPressed: () =>
                    controller.showSpitScreenNotifier.value = false,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'This tool helps you diagnose Universal Links, App Links,'
            ' and Custom Schemes in your app. Web checks are done for the web association'
            ' files on your website. App checks are done for the intent filters in'
            ' the manifest and info.plist file, routing issues, URL format, etc.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Text('Domain check'),
          Expanded(child: _DomainCheckTable(linkData: linkData)),
        ],
      ),
    );
  }
}

class _DomainCheckTable extends StatelessWidget {
  const _DomainCheckTable({
    required this.linkData,
  });

  final LinkData linkData;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('OS')),
        DataColumn(label: Text('Issue type')),
        DataColumn(label: Text('Status')),
      ],
      rows: [
        if (linkData.os.contains(PlatformOS.android))
          DataRow(
            cells: [
              const DataCell(Text('Android')),
              const DataCell(Text('Digital assets link file')),
              DataCell(
                linkData.domainError
                    ? Text(
                        'Check failed',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : Text(
                        'No issues found',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.green,
                        ),
                      ),
              ),
            ],
          ),
        if (linkData.os.contains(PlatformOS.ios))
          DataRow(
            cells: [
              const DataCell(Text('iOS')),
              const DataCell(Text('Apple-App-Site-Association file')),
              DataCell(
                Text(
                  'No issues found',
                  style: TextStyle(color: Theme.of(context).colorScheme.green),
                ),
              ),
            ],
          ),
      ],
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
