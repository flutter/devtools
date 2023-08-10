// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../devtools_app.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';

const bundledDataRowHeight = 150.0;

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
    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'All deep links',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            InkWell(
              onTap: () {
                controller.bundleByDomain = !controller.bundleByDomain;
              },
              child: const Text('Bundle by domain'),
            ),
            const SizedBox(width: denseSpacing),
            SearchBar(
              leading: const Icon(Icons.search),
              onChanged: (value) {
                controller.searchContent = value;
              },
              constraints: BoxConstraints.tight(
                Size(defaultSearchFieldWidth, defaultTextFieldHeight),
              ),
            ),
          ],
        ),
        const SizedBox(height: denseSpacing),
        ValueListenableBuilder<List<LinkData>>(
          valueListenable: controller.linkDatasNotifier,
          builder: (context, linkDatas, _) => _DataTable(
            linkDatas: linkDatas,
            bundleByDomain: controller.bundleByDomain,
          ),
        ),
      ],
    );
  }
}

class _DataTable extends StatelessWidget {
  const _DataTable({required this.bundleByDomain, required this.linkDatas});
  final bool bundleByDomain;
  final List<LinkData> linkDatas;

  @override
  Widget build(BuildContext context) {
    final List<DataRow> rows = [
      for (var i = 0; i < linkDatas.length; i++)
        _buildRow(
          context,
          linkDatas[i],
          color: MaterialStateProperty.all<Color>(
            alternatingColorForIndex(i, Theme.of(context).colorScheme),
          ),
        ),
    ];

    return DataTable(
      columns: const [
        DataColumn(label: Text('OS')),
        DataColumn(label: Text('Scheme')),
        DataColumn(label: Text('Domain')),
        DataColumn(label: Text('Path')),
      ],
      dataRowMinHeight: bundleByDomain ? bundledDataRowHeight : null,
      dataRowMaxHeight: bundleByDomain ? bundledDataRowHeight : null,
      rows: rows,
    );
  }

  DataRow _buildRow(
    BuildContext context,
    LinkData data, {
    MaterialStateProperty<Color?>? color,
  }) {
    return DataRow(
      color: color,
      cells: [
        DataCell(Text(data.os)),
        DataCell(Text(data.scheme)),
        DataCell(
          Row(
            children: [
              if (data.domainError)
                Padding(
                  padding: const EdgeInsets.only(right: denseSpacing),
                  child: Icon(
                    Icons.error,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              Text(data.domain),
            ],
          ),
        ),
        DataCell(
          Row(
            children: [
              if (data.pathError)
                Padding(
                  padding: const EdgeInsets.only(right: denseSpacing),
                  child: Icon(
                    Icons.error,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(width: 10),
              Text(data.paths.join('\n')),
            ],
          ),
        ),
      ],
    );
  }
}
