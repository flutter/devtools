// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'deep_links_model.dart';
import 'fake_data.dart';

enum FilterOption {
  http('http://, https://'),
  custom('Custom scheme'),
  android('Android'),
  ios('iOS'),
  noIssue('No issues found'),
  failedDomainCheck('Failed domain checks '),
  failedPathCheck('Failed path checks');

  const FilterOption(this.description);
  final String description;
}

class DisplayOptions {
  DisplayOptions({
    this.domainErrorCount = 0,
    this.pathErrorCount = 0,
    this.showSplitScreen = false,
    this.filters = const {
      FilterOption.http: true,
      FilterOption.custom: true,
      FilterOption.android: true,
      FilterOption.ios: true,
      FilterOption.noIssue: true,
      FilterOption.failedDomainCheck: true,
      FilterOption.failedPathCheck: true,
    },
  });

  int domainErrorCount = 0;
  int pathErrorCount = 0;
  bool showSplitScreen = false;

  Map<FilterOption, bool> filters = {
    for (var item in FilterOption.values) item: true,
  };

  DisplayOptions updateFilter(FilterOption option, bool value) {
    filters[option] = value;
    return DisplayOptions(
      domainErrorCount: domainErrorCount,
      pathErrorCount: pathErrorCount,
      showSplitScreen: showSplitScreen,
      filters: filters,
    );
  }

  DisplayOptions copyWith({
    int? domainErrorCount,
    int? pathErrorCount,
    bool? showSplitScreen,
  }) {
    return DisplayOptions(
      domainErrorCount: domainErrorCount ?? this.domainErrorCount,
      pathErrorCount: pathErrorCount ?? this.pathErrorCount,
      showSplitScreen: showSplitScreen ?? this.showSplitScreen,
      filters: filters,
    );
  }
}

class DeepLinksController {
  List<LinkData> get getLinkDatasByPath =>
      _getFilterredLinks(linkDatasByPath, _searchContentNotifier.value);
  List<LinkData> get getLinkDatasByDomain =>
      _getFilterredLinks(linkDatasByDomain, _searchContentNotifier.value);

  DisplayOptions get displayOptions => displayOptionsNotifier.value;

  final selectedLink = ValueNotifier<LinkData?>(null);
  final linkDatasNotifier = ValueNotifier<List<LinkData>>(allLinkDatas);

  final displayOptionsNotifier =
      ValueNotifier<DisplayOptions>(DisplayOptions());

  final _searchContentNotifier = ValueNotifier<String>('');

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
    linkDatasByDomain = linkDatasByDomainValues;

    final linkDatasByPathMap = <String, LinkData>{};
    for (var linkData in allLinkDatas) {
      linkDatasByPathMap[linkData.path.single] =
          linkData.mergebyPath(linkDatasByPathMap[linkData.path.single]);
    }
    final List<LinkData> linkDatasByPathValues =
        linkDatasByPathMap.values.toList();
    linkDatasByPath = linkDatasByPathValues;

    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount: linkDatasByDomainValues
          .where((element) => element.domainError)
          .length,
      pathErrorCount:
          linkDatasByPathValues.where((element) => element.pathError).length,
    );
  }

  set searchContent(String content) {
    _searchContentNotifier.value = content;
    linkDatasNotifier.value =
        _getFilterredLinks(allLinkDatas, _searchContentNotifier.value);
  }

  void updateFilterOptions({
    required FilterOption option,
    required bool value,
  }) {
    displayOptionsNotifier.value =
        displayOptionsNotifier.value.updateFilter(option, value);

    linkDatasNotifier.value =
        _getFilterredLinks(allLinkDatas, _searchContentNotifier.value);
  }

  void updateDisplayOptions({
    int? domainErrorCount,
    int? pathErrorCount,
    bool? showSplitScreen,
  }) {
    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount: domainErrorCount,
      pathErrorCount: pathErrorCount,
      showSplitScreen: showSplitScreen,
    );
    linkDatasNotifier.value =
        _getFilterredLinks(allLinkDatas, _searchContentNotifier.value);
  }

  List<LinkData> _getFilterredLinks(
    List<LinkData> linkDatas,
    String searchContent,
  ) {
    linkDatas = linkDatas.where((linkData) {
      if (searchContent.isNotEmpty &&
          !linkData.matchesSearchToken(
            RegExp(
              searchContent,
              caseSensitive: false,
            ),
          )) {
        return false;
      }

      if (!((linkData.os.contains('Android') &&
              displayOptions.filters[FilterOption.android]!) ||
          (linkData.os.contains('iOS') &&
              displayOptions.filters[FilterOption.ios]!))) {
        return false;
      }

      if (!((linkData.domainError &&
              displayOptions.filters[FilterOption.failedDomainCheck]!) ||
          (linkData.pathError &&
              displayOptions.filters[FilterOption.failedPathCheck]!) ||
          (!linkData.domainError &&
              !linkData.pathError &&
              displayOptions.filters[FilterOption.noIssue]!))) {
        return false;
      }

      return true;
    }).toList();

    return linkDatas;
  }
}
