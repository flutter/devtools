// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter/foundation.dart';

import '../../shared/config_specific/server/server.dart' as server;
import 'deep_links_model.dart';

typedef _DomainAndPath = ({String domain, String path});

class DeepLinksController {
  DeepLinksController() {
    selectedVariantIndex.addListener(_handleSelectedVariantIndexChanged);
  }

  bool get showSpitScreen => showSpitScreenNotifier.value;

  List<LinkData> get getLinkDatasByPath {
    final linkDatasByPath = <String, LinkData>{};
    for (var linkData in linkDatasNotifier.value!) {
      linkDatasByPath[linkData.path] = linkData;
    }
    return linkDatasByPath.values.toList();
  }

  List<LinkData> get getLinkDatasByDomain {
    final linkDatasByDomain = <String, LinkData>{};
    for (var linkData in linkDatasNotifier.value!) {
      linkDatasByDomain[linkData.domain] = linkData;
    }
    return linkDatasByDomain.values.toList();
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
      final result = await server.requestAndroidAppLinkSettings(
        selectedProject.value!.path,
        buildVariant: variant,
      );
      _androidAppLinks[selectedVariantIndex.value] = result;
    }
    _updateLinks();
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
  final showSpitScreenNotifier = ValueNotifier<bool>(false);

  final _searchContentNotifier = ValueNotifier<String>('');

  void _updateLinks() {
    final searchContent = _searchContentNotifier.value;
    final List<LinkData> linkDatas = searchContent.isNotEmpty
        ? _allLinkDatas
            .where(
              (linkData) => linkData.matchesSearchToken(
                RegExp(
                  searchContent,
                  caseSensitive: false,
                ),
              ),
            )
            .toList()
        : _allLinkDatas;
    linkDatasNotifier.value = linkDatas;
  }

  set searchContent(String content) {
    _searchContentNotifier.value = content;
    _updateLinks();
  }
}
