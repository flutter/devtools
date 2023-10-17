// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'deep_links_model.dart';
import 'fake_data.dart';

enum SchemeFilterOption {
  http,
  custom,
  showAll,
}

enum OsFilterOption {
  android,
  ios,
  showAll,
}

enum StatusFilterOption {
  noIssue,
  failedDomainCheck,
  failedPathCheck,
  failedAllCheck,
  showAll,
}

class DeepLinksController {
  bool get showSplitScreen => showSplitScreenNotifier.value;

  List<LinkData> get getLinkDatasByPath =>
      _getFilterredLinks(linkDatasByPath, _searchContentNotifier.value);
  List<LinkData> get getLinkDatasByDomain =>
      _getFilterredLinks(linkDatasByDomain, _searchContentNotifier.value);

  final selectedLink = ValueNotifier<LinkData?>(null);
  final linkDatasNotifier = ValueNotifier<List<LinkData>>(allLinkDatas);
  final showSplitScreenNotifier = ValueNotifier<bool>(false);
  final domainErrorCountNotifier = ValueNotifier<int>(0);
  final pathErrorCountNotifier = ValueNotifier<int>(0);
  final _searchContentNotifier = ValueNotifier<String>('');
  final schemeFilterOptionNotifier =
      ValueNotifier<SchemeFilterOption>(SchemeFilterOption.showAll);
  final osFilterOptionNotifier =
      ValueNotifier<OsFilterOption>(OsFilterOption.showAll);
  final statusFilterOptionNotifier =
      ValueNotifier<StatusFilterOption>(StatusFilterOption.showAll);

  var linkDatasByDomain = <LinkData>[];
  var linkDatasByPath = <LinkData>[];

  void initLinkDatas() {
    linkDatasNotifier.value = allLinkDatas;
    final linkDatasByDomainMap = <String, LinkData>{};
    for (var linkData in allLinkDatas) {
      linkDatasByDomainMap[linkData.domain.single] =
          linkData.mergebyDomain(linkDatasByDomainMap[linkData.domain.single]);
    }
    final List<LinkData> linkDatasByDomainValues =
        linkDatasByDomainMap.values.toList();
    domainErrorCountNotifier.value =
        linkDatasByDomainValues.where((element) => element.domainError).length;
    linkDatasByDomain = linkDatasByDomainValues;

    final linkDatasByPathMap = <String, LinkData>{};
    for (var linkData in allLinkDatas) {
      linkDatasByPathMap[linkData.path.single] =
          linkData.mergebyPath(linkDatasByPathMap[linkData.path.single]);
    }
    final List<LinkData> linkDatasByPathValues =
        linkDatasByPathMap.values.toList();
    pathErrorCountNotifier.value =
        linkDatasByPathValues.where((element) => element.pathError).length;
    linkDatasByPath = linkDatasByPathValues;
  }

  set searchContent(String content) {
    _searchContentNotifier.value = content;
    linkDatasNotifier.value =
        _getFilterredLinks(allLinkDatas, _searchContentNotifier.value);
  }

  void updateFilterOptions({
    SchemeFilterOption? schemeOption,
    OsFilterOption? osOption,
    StatusFilterOption? statusOption,
  }) {
    if (schemeOption != null) schemeFilterOptionNotifier.value = schemeOption;
    if (osOption != null) osFilterOptionNotifier.value = osOption;
    if (statusOption != null) statusFilterOptionNotifier.value = statusOption;

    linkDatasNotifier.value =
        _getFilterredLinks(allLinkDatas, _searchContentNotifier.value);
  }

  List<LinkData> _getFilterredLinks(
    List<LinkData> linkDatas,
    String searchContent,
  ) {
    if (searchContent.isNotEmpty) {
      linkDatas = linkDatas
          .where(
            (linkData) => linkData.matchesSearchToken(
              RegExp(
                searchContent,
                caseSensitive: false,
              ),
            ),
          )
          .toList();
    }
    switch (statusFilterOptionNotifier.value) {
      case StatusFilterOption.failedAllCheck:
        linkDatas = linkDatas
            .where((linkData) => linkData.domainError && linkData.pathError)
            .toList();
        break;
      case StatusFilterOption.failedDomainCheck:
        linkDatas =
            linkDatas.where((linkData) => linkData.domainError).toList();
        break;
      case StatusFilterOption.failedPathCheck:
        linkDatas = linkDatas.where((linkData) => linkData.pathError).toList();
        break;
      case StatusFilterOption.noIssue:
        linkDatas = linkDatas
            .where((linkData) => !linkData.pathError && !linkData.domainError)
            .toList();
        break;
      case StatusFilterOption.showAll:
        break;
    }
    switch (osFilterOptionNotifier.value) {
      case OsFilterOption.android:
        linkDatas = linkDatas
            .where((linkData) => linkData.os.contains('Android'))
            .toList();
        break;
      case OsFilterOption.ios:
        linkDatas =
            linkDatas.where((linkData) => linkData.os.contains('iOS')).toList();
        break;
      case OsFilterOption.showAll:
        break;
    }

    return linkDatas;
  }
}
