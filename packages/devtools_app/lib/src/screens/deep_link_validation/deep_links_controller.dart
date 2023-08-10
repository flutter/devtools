// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'deep_links_model.dart';
import 'fake_data.dart';


class DeepLinksController {

  final _linkDatasNotifier = ValueNotifier<List<LinkData>>(allLinkDatas);
  ValueListenable<List<LinkData>> get linkDatasNotifier => _linkDatasNotifier;
  List<LinkData> get linkDatas => _linkDatasNotifier.value;

  final _searchContentNotifier = ValueNotifier<String>('');
  ValueListenable<String> get searchContentNotifier => _searchContentNotifier;
  set searchContent(String content) {
    _searchContentNotifier.value = content;
    _updateLinks();
  }

  final _bundleByDomainNotifier = ValueNotifier<bool>(false);
  ValueListenable<bool> get bundleByDomainNotifier => _bundleByDomainNotifier;
  set bundleByDomain(bool value) {
    _bundleByDomainNotifier.value = value;
    _updateLinks();
  }
  bool get bundleByDomain => _bundleByDomainNotifier.value;

  void _updateLinks() {
    final searchContent = _searchContentNotifier.value;
    List<LinkData> linkDatas = searchContent.isNotEmpty
        ? allLinkDatas
            .where(
              (linkData) => linkData.searchLabel.contains(searchContent),
            )
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
    _linkDatasNotifier.value = linkDatas;
  }
}
