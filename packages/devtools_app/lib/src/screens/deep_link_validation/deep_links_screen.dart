// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import '../../shared/screen.dart';

const List<String> paths = [
  '/shoes/..*',
  '/Clothes/..*',
  '/Toys/..*',
  '/Jewelry/..*',
  '/Watches/..* ',
  '/Glasses/..*',
];

List<LinkData> allLinkDatas = [
  for (var path in paths)
    LinkData(
      os: 'Android, iOS',
      domain: 'm.shopping.com',
      path: path,
      domainError: true,
      pathError: path.contains('shoe'),
    ),
  for (var path in paths)
    LinkData(
      os: 'iOS',
      domain: 'm.french.shopping.com',
      path: path,
      pathError: path.contains('shoe'),
    ),
  for (var path in paths)
    LinkData(
      os: 'Android',
      domain: 'm.chinese.shopping.com',
      path: path,
      pathError: path.contains('shoe'),
    ),
];

class LinkData {
  LinkData({
    required this.os,
    required this.domain,
    required this.path,
    this.scheme = 'Http://, Https://',
    this.domainError = false,
    this.pathError = false,
  });

  String os;
  String path;
  String domain;
  String scheme;
  bool domainError;
  bool pathError;
  String get searchLabel => (os + path + domain + scheme).toLowerCase();

  DataRow buildRow(
    BuildContext context, {
    MaterialStateProperty<Color?>? color,
  }) {
    return DataRow(
      color: color,
      cells: [
        DataCell(Text(os)),
        DataCell(Text(scheme)),
        DataCell(
          domainError
              ? Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Text(domain),
                  ],
                )
              : Text(domain),
        ),
        DataCell(
          pathError
              ? Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Text(path),
                  ],
                )
              : Text(path),
        ),
      ],
    );
  }

  LinkData mergeByDomain(LinkData? linkData) {
    if (linkData == null) {
      return this;
    }

    return LinkData(
      os: os,
      domain: domain,
      path: '${linkData.path}\n$path',
      domainError: domainError || linkData.domainError,
      // pathError: pathError || linkData.pathError,
    );
  }
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

  @override
  String get docPageId => id;

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

class _DeepLinkPageState extends State<DeepLinkPage> {
  String responseBody = 'empty response';

  int? selectedRowIndex;
  String searchContent = '';
  bool bundleByDomain = true;

  void setBundleByDomain(bool shouldBundleByDomain) {
    setState(() {
      bundleByDomain = shouldBundleByDomain;
    });
  }

  void setResponse(String response) {
    setState(() {
      responseBody = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Row(
          children: [
            Expanded(child: buildTitle('All deep links', context)),
            InkWell(
              onTap: () {
                setBundleByDomain(!bundleByDomain);
              },
              child: const Text('Bundle by domain'),
            ),
            const SizedBox(width: 10),
            SearchBar(
              leading: const Icon(Icons.search),
              onChanged: (value) {
                setState(() {
                  searchContent = value.toLowerCase();
                });
              },
              constraints: BoxConstraints.tight(const Size(200, 40)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        buildDataTable(context),
      ],
    );
  }

  Widget buildDataTable(BuildContext context) {
    List<LinkData> linkDatas = searchContent.isNotEmpty
        ? allLinkDatas
            .where((linkData) => linkData.searchLabel.contains(searchContent))
            .toList()
        : allLinkDatas;

    if (bundleByDomain) {
      final Map<String, LinkData> bundleByDomainMap = {};
      for (var linkData in linkDatas) {
        bundleByDomainMap[linkData.domain] =
            linkData.mergeByDomain(bundleByDomainMap[linkData.domain]);
      }
      linkDatas = bundleByDomainMap.values.toList();
    }

    final List<DataRow> rows = [
      for (var i = 0; i < linkDatas.length; i++)
        linkDatas[i].buildRow(
          context,
          color: i % 2 == 0
              ? MaterialStateProperty.all<Color>(
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                )
              : null,
        ),
    ];

    return DataTable(
      columns: const [
        DataColumn(label: Text('OS')),
        DataColumn(label: Text('Scheme')),
        DataColumn(label: Text('Domain')),
        DataColumn(label: Text('Path')),
      ],
      dataRowMinHeight: bundleByDomain ? 150 : null,
      dataRowMaxHeight: bundleByDomain ? 150 : null,
      rows: rows,
    );
  }
}

Widget buildTitle(String text, BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  return Text(
    text,
    style: textTheme.bodyLarge,
  );
}
