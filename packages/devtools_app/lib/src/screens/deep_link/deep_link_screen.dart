// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/ui/icons.dart';

import 'one_link_screen.dart';

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
  String get searchLabel => os + path + domain + scheme;

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
                    Icon(Icons.error,
                        color: Theme.of(context).colorScheme.error),
                    SizedBox(width: 10),
                    Text(domain),
                  ],
                )
              : Text(domain),
        ),
        DataCell(
          pathError
              ? Row(
                  children: [
                    Icon(Icons.error,
                        color: Theme.of(context).colorScheme.error),
                    SizedBox(width: 10),
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

    return LinkData(os: os, domain: domain, path: '${linkData.path}\n$path');
  }
}

class DeepLinkScreen extends Screen {
  DeepLinkScreen()
      : super.conditional(
          id: id,
          worksOffline: true,
          title: ScreenMetaData.deepLink.title,
          icon: Octicons.link,
        );

  static final id = ScreenMetaData.deepLink.id;

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    return MyHomePage();
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String responseBody = 'empty response';

  int? selectedRowIndex;
  String searchContent = '';
  bool bundleByDomain = false;

  void setResponse(String response) {
    setState(() {
      responseBody = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (selectedRowIndex != null) {
      return OneLinkPage(
        onBack: () {
          setState(() {
            selectedRowIndex = null;
          });
        },
      );
    }

    return ListView(
      children: [
        Row(
          //mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: buildTitle('All deep links', context)),
            const Text('Bundle by domain'),
            const SizedBox(width: 10),
            SearchBar(
              leading: const Icon(Icons.search),
              onChanged: (value) {
                setState(() {
                  searchContent = value;
                });
              },
              constraints: BoxConstraints.tight(Size(200, 40)),
            ),
          ],
        ),
        SizedBox(height: 10),
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
//bundleByDomain
    if (true) {
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
      columns: [
        DataColumn(
          label: Text('OS'),
          onSort: (_, __) {},
        ),
        DataColumn(label: Text('Scheme')),
        DataColumn(label: Text('Domain')),
        DataColumn(label: Text('Path')),
      ],
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



  // Widget buildBundledTable(BuildContext context) {
  //   List<String> paths = [
  //     '/shoes/..*',
  //     '/Clothes/..*',
  //     '/Toys/..*',
  //     '/Jewelry/..*',
  //     '/Watches/..* ',
  //     '/Glasses/..*',
  //   ];

  //   List<String> domains = [
  //     'm.shopping.com',
  //     'm.french.shopping.com',
  //     'm.chinese.shopping.com',
  //   ];

  //   String allPath = '';
  //   for (var j = 0; j < 6; j++) allPath += paths[j] + '\n';
  //   print(allPath);

  //   List<DataRow> rows = [
  //     for (var i = 0; i < 3; i++)
  //       buildRow(
  //         domain: domains[i],
  //         path: allPath, //for (var j = 0; j < 6; j++)paths[j],
  //         color: i % 2 == 0
  //             ? MaterialStateProperty.all<Color>(
  //                 Theme.of(context).colorScheme.onSurface.withOpacity(0.3))
  //             : null,
  //       ),
  //   ];
  //   List<String> searchList = [
  //     for (var i = 0; i < 3; i++)
  //       for (var j = 0; j < 6; j++)
  //         'AndroidIOSHttp://, https://${domains[i]}${paths[j]}'
  //   ];

  //   if (searchContent.isNotEmpty) {
  //     rows = rows
  //         .whereIndexed(
  //           (index, element) => searchList[index].contains(searchContent),
  //         )
  //         .toList();
  //   }

  //   return DataTable(
  //     columns: [
  //       DataColumn(
  //         label: Text('OS'),
  //         onSort: (_, __) {},
  //       ),
  //       DataColumn(label: Text('Scheme')),
  //       DataColumn(label: Text('Domain')),
  //       DataColumn(label: Text('Path')),
  //       DataColumn(label: Text('issues')),
  //     ],
  //     rows: rows,
  //     dataRowMinHeight: 150,
  //   );
  // }