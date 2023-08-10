// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Contains all data relevant to a deep link.
class LinkData {
  LinkData({
    required this.os,
    required this.domain,
    required this.paths,
    this.scheme = 'Http://, Https://',
    this.domainError = false,
    this.pathError = false,
  });

  final String os;
  final List<String> paths;
  final String domain;
  final String scheme;
  final bool domainError;
  final bool pathError;

  String get searchLabel => (os + paths.join() + domain + scheme).toLowerCase();

  LinkData mergeByDomain(LinkData? linkData) {
    if (linkData == null) {
      return this;
    }

    return LinkData(
      os: os,
      domain: domain,
      paths: [...paths, ...linkData.paths],
      domainError: domainError || linkData.domainError,
    );
  }
}

DataRow buildRow(
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
