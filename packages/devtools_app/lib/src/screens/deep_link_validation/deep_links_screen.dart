// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/screen.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/ui/search.dart';
import '../../shared/utils.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';

enum TableViewType {
  domainView,
  pathView,
  singleUrlView,
}

class DeepLinksScreen extends Screen {
  DeepLinksScreen()
      : super.conditional(
          id: id,
          requiresConnection: false,
          requiresDartVm: true,
          title: ScreenMetaData.deepLinks.title,
          icon: ScreenMetaData.deepLinks.icon,
        );

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
    with
        AutoDisposeMixin,
        SingleTickerProviderStateMixin,
        ProvidedControllerMixin<DeepLinksController, DeepLinkPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: TableViewType.values.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: ValueListenableBuilder<List<LinkData>>(
              valueListenable: controller.linkDatasNotifier,
              builder: (context, linkDatas, _) => ValueListenableBuilder<bool>(
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
          ),
        ],
      ),
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
              const Text('Selected Deep link validation details'),
              IconButton(
                onPressed: () =>
                    controller.showSpitScreenNotifier.value = false,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'This tool assistants helps you diagnose Universal Links, App Links,'
            ' and Custom Schemes in your app. Web check are done for the web association'
            ' file on your website. App checks are done for the intent filters in'
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
        if (linkData.os.contains('Android'))
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
                          // TODO: Update devtool colorscheme and use color from there.
                          color: Theme.of(context).colorScheme.green,
                        ),
                      ),
              ),
            ],
          ),
        if (linkData.os.contains('iOS'))
          DataRow(
            cells: [
              const DataCell(Text('iOS')),
              const DataCell(Text('Apple-App-Site-Association file')),
              DataCell(
                Text(
                  'No issues found',
                  // TODO: Update devtool colorscheme and use color from there.
                  style: TextStyle(color: Theme.of(context).colorScheme.green),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
