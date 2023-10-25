// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter/foundation.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/config_specific/server/server.dart' as server;
import 'deep_links_model.dart';
import 'fake_data.dart';

typedef _DomainAndPath = ({String domain, String path});

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
    this.searchContent = '',
  });

  int domainErrorCount = 0;
  int pathErrorCount = 0;
  bool showSplitScreen = false;
  String searchContent;

  Map<FilterOption, bool> filters;

  DisplayOptions updateFilter(FilterOption option, bool value) {
    final Map<FilterOption, bool> newFilters =
        Map<FilterOption, bool>.from(filters);
    newFilters[option] = value;

    return DisplayOptions(
      domainErrorCount: domainErrorCount,
      pathErrorCount: pathErrorCount,
      showSplitScreen: showSplitScreen,
      filters: newFilters,
      searchContent: searchContent,
    );
  }

  DisplayOptions copyWith({
    int? domainErrorCount,
    int? pathErrorCount,
    bool? showSplitScreen,
    String? searchContent,
  }) {
    return DisplayOptions(
      domainErrorCount: domainErrorCount ?? this.domainErrorCount,
      pathErrorCount: pathErrorCount ?? this.pathErrorCount,
      showSplitScreen: showSplitScreen ?? this.showSplitScreen,
      filters: filters,
      searchContent: searchContent ?? '',
    );
  }
}

class DeepLinksController {
  DeepLinksController() {
    selectedVariantIndex.addListener(_handleSelectedVariantIndexChanged);
  }

  DisplayOptions get displayOptions => displayOptionsNotifier.value;

  List<LinkData> get getLinkDatasByPath {
    final linkDatasByPath = <String, LinkData>{};
    for (var linkData in linkDatasNotifier.value!) {
      final prevoisRecord = linkDatasByPath[linkData.path];
      linkDatasByPath[linkData.path] = LinkData(
        domain: linkData.domain,
        path: linkData.path,
        os: [
          if (prevoisRecord?.os.contains(PlatformOS.android) ??
              false || linkData.os.contains(PlatformOS.android))
            PlatformOS.android,
          if (prevoisRecord?.os.contains(PlatformOS.ios) ??
              false || linkData.os.contains(PlatformOS.ios))
            PlatformOS.ios,
        ],
        associatedDomains: [
          ...prevoisRecord?.associatedDomains ?? [],
          linkData.domain,
        ],
        pathError: linkData.pathError,
      );
    }

    return _getFilterredLinks(linkDatasByPath.values.toList());
  }

  List<LinkData> get getLinkDatasByDomain {
    final linkDatasByDomain = <String, LinkData>{};

    for (var linkData in linkDatasNotifier.value!) {
      final prevoisRecord = linkDatasByDomain[linkData.domain];
      linkDatasByDomain[linkData.domain] = LinkData(
        domain: linkData.domain,
        path: linkData.path,
        os: linkData.os,
        associatedPath: [
          ...prevoisRecord?.associatedPath ?? [],
          linkData.path,
        ],
        domainError: linkData.domainError,
      );
    }
    return _getFilterredLinks(linkDatasByDomain.values.toList());
  }

  final Map<int, AppLinkSettings> _androidAppLinks = <int, AppLinkSettings>{};

  late final selectedVariantIndex = ValueNotifier<int>(0);
  void _handleSelectedVariantIndexChanged() {
    linkDatasNotifier.value = null;
    unawaited(_loadAndroidAppLinks());
  }

  Future<void> _loadAndroidAppLinks() async {
    if (!_androidAppLinks.containsKey(selectedVariantIndex.value)) {
      final variant =
          selectedProject.value!.androidVariants[selectedVariantIndex.value];
      await ga.timeAsync(
        gac.deeplink,
        gac.AnalyzeFlutterProject.loadAppLinks.name,
        asyncOperation: () async {
          final result = await server.requestAndroidAppLinkSettings(
            selectedProject.value!.path,
            buildVariant: variant,
          );
          _androidAppLinks[selectedVariantIndex.value] = result;
        },
      );
    }
    updateLinks();
  }

  List<LinkData> get _allLinkDatas {
    final appLinks = _androidAppLinks[selectedVariantIndex.value]?.deeplinks;
    if (appLinks == null) {
      return const <LinkData>[];
    }
    final domainPathToScheme = <_DomainAndPath, Set<String>>{};
    for (final appLink in appLinks) {
      final schemes = domainPathToScheme.putIfAbsent(
        (domain: appLink.host, path: appLink.path),
        () => <String>{},
      );
      schemes.add(appLink.scheme);
    }
    return domainPathToScheme.entries
        .map(
          (entry) => LinkData(
            domain: entry.key.domain,
            path: entry.key.path,
            os: [PlatformOS.android],
            scheme: entry.value.toList(),
          ),
        )
        .toList();
  }

  final selectedProject = ValueNotifier<FlutterProject?>(null);
  final selectedLink = ValueNotifier<LinkData?>(null);
  final linkDatasNotifier = ValueNotifier<List<LinkData>?>(null);

  final displayOptionsNotifier =
      ValueNotifier<DisplayOptions>(DisplayOptions());

  void updateLinks() {
    linkDatasNotifier.value = _allLinkDatas;

    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount:
          getLinkDatasByDomain.where((element) => element.domainError).length,
      pathErrorCount:
          getLinkDatasByPath.where((element) => element.pathError).length,
    );
  }

  set searchContent(String content) {
    displayOptionsNotifier.value =
        displayOptionsNotifier.value.copyWith(searchContent: content);
    linkDatasNotifier.value = _getFilterredLinks(_allLinkDatas);
  }

  void updateFilterOptions({
    required FilterOption option,
    required bool value,
  }) {
    displayOptionsNotifier.value =
        displayOptionsNotifier.value.updateFilter(option, value);

    linkDatasNotifier.value = _getFilterredLinks(_allLinkDatas);
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
    linkDatasNotifier.value = _getFilterredLinks(_allLinkDatas);
  }

  List<LinkData> _getFilterredLinks(List<LinkData> linkDatas) {
    final String searchContent = displayOptions.searchContent;
    linkDatas = linkDatas.where((linkData) {
      if (searchContent.isNotEmpty &&
          !linkData.matchesSearchToken(
            RegExp(searchContent, caseSensitive: false),
          )) {
        return false;
      }

      if (!((linkData.os.contains(PlatformOS.android) &&
              displayOptions.filters[FilterOption.android]!) ||
          (linkData.os.contains(PlatformOS.ios) &&
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
