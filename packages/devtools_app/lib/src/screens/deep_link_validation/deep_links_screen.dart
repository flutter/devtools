// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/screen.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/ui/colors.dart';
import '../../shared/utils.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';

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
    with
        AutoDisposeMixin,
        SingleTickerProviderStateMixin,
        ProvidedControllerMixin<DeepLinksController, DeepLinkPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
    controller.initLinkDatas();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return ValueListenableBuilder<DisplayOptions>(
      valueListenable: controller.displayOptionsNotifier,
      builder: (context, displayOptions, _) => DefaultTabController(
        length: TableViewType.values.length,
        child: RoundedOutlinedBorder(
          child: Column(
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
                              _ValidationDetailScreen(
                                linkData: selectedLink!,
                                controller: controller,
                                tableView: TableViewType.domainView,
                              ),
                              _ValidationDetailScreen(
                                linkData: selectedLink,
                                controller: controller,
                                tableView: TableViewType.pathView,
                              ),
                              _ValidationDetailScreen(
                                linkData: selectedLink,
                                controller: controller,
                                tableView: TableViewType.singleUrlView,
                              ),
                            ],
                          ),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              defaultSpacing,
              denseSpacing,
              denseSpacing,
              denseSpacing,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'All deep links',
                    style: textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: denseSpacing),
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
          ),
        ),
        Row(
          children: [
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
            const Spacer(),

            // TODO: Add functions to these icons.
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.restart_alt, size: actionsIconSize),
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.settings, size: actionsIconSize),
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(Icons.help_outline, size: actionsIconSize),
            ),
          ],
        ),
        Expanded(
          child: ValueListenableBuilder<List<LinkData>>(
            valueListenable: controller.linkDatasNotifier,
            builder: (context, linkDatas, _) => TabBarView(
              children: [
                _DataTable(
                  tableView: TableViewType.domainView,
                  linkDatas: controller.getLinkDatasByDomain,
                  controller: controller,
                ),
                _DataTable(
                  tableView: TableViewType.pathView,
                  linkDatas: controller.getLinkDatasByPath,
                  controller: controller,
                ),
                _DataTable(
                  tableView: TableViewType.singleUrlView,
                  linkDatas: linkDatas,
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

    return Padding(
      padding: const EdgeInsets.only(top: denseSpacing),
      child: FlatTable(
        keyFactory: (node) => ValueKey(node.toString),
        data: linkDatas,
        dataKey: 'deep-links',
        autoScrollContent: true,
        headerColor: Theme.of(context).colorScheme.deeplinkTableHeaderColor,
        columns: <ColumnData>[
          if (tableView == TableViewType.domainView) ...[
            domain,
            NumberOfAssociatedPathColumn(),
          ],
          if (tableView == TableViewType.pathView) ...[
            path,
            NumberOfAssociatedDomainColumn(),
          ],
          if (tableView == TableViewType.singleUrlView) ...[domain, path],
          SchemeColumn(controller),
          OSColumn(controller),
          if (!controller.displayOptionsNotifier.value.showSplitScreen) ...[
            StatusColumn(controller, tableView),
            NavigationColumn(),
          ],
        ],
        selectionNotifier: controller.selectedLink,
        defaultSortColumn: tableView == TableViewType.pathView ? path : domain,
        defaultSortDirection: SortDirection.ascending,
        onItemSelected: (item) =>
            controller.updateDisplayOptions(showSplitScreen: true),
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlineDecoration(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: largeSpacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tableView == TableViewType.domainView
                      ? 'Selected domain validation details'
                      : 'Selected Deep link validation details',
                  style: textTheme.titleSmall,
                ),
                IconButton(
                  onPressed: () =>
                      controller.updateDisplayOptions(showSplitScreen: false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: largeSpacing,
            vertical: defaultSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This tool assistants helps you diagnose Universal Links, App Links,'
                ' and Custom Schemes in your app. Web check are done for the web association'
                ' file on your website. App checks are done for the intent filters in'
                ' the manifest and info.plist file, routing issues, URL format, etc.',
                style: Theme.of(context).subtleTextStyle,
              ),
              if (tableView != TableViewType.pathView) ...[
                const SizedBox(height: intermediateSpacing),
                Text('Domain check', style: textTheme.titleSmall),
                _DomainCheckTable(linkData: linkData),
              ],
              if (tableView != TableViewType.domainView) ...[
                const SizedBox(height: intermediateSpacing),
                Text('Path check (coming soon)', style: textTheme.titleSmall),
                _PathCheckTable(),
              ],
              Align(
                alignment: Alignment.bottomRight,
                child: FilledButton(
                  onPressed: () {
                    controller.initLinkDatas();
                  },
                  child: const Text('Recheck all'),
                ),
              ),
              if (tableView == TableViewType.domainView) ...[
                Text('Associated deep link URL', style: textTheme.titleSmall),
                Card(
                  color: colorScheme.surface,
                  shape: const RoundedRectangleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(denseSpacing),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: linkData.path
                          .map(
                            (path) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: denseRowSpacing,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.error,
                                    color: colorScheme.error,
                                    size: defaultIconSize,
                                  ),
                                  const SizedBox(width: denseSpacing),
                                  Text(path),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
                  style: TextStyle(color: Theme.of(context).colorScheme.green),
                ),
              ),
            ],
          ),
      ],
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
