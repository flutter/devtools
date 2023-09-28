// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'deep_links_model.dart';
import 'fake_data.dart';

class DeepLinksController {
  bool get showSpitScreen => showSpitScreenNotifier.value;

  List<LinkData> get getLinkDatasByPath {
    final linkDatasByPath = <String, LinkData>{};
    for (var linkData in linkDatasNotifier.value) {
      linkDatasByPath[linkData.path.single] =
          linkData.mergeDomain(linkDatasByPath[linkData.path.single]);
    }
    return linkDatasByPath.values.toList();
  }

  List<LinkData> get getLinkDatasByDomain {
    final linkDatasByDomain = <String, LinkData>{};
    for (var linkData in linkDatasNotifier.value) {
      linkDatasByDomain[linkData.domain.single] =
          linkData.mergePath(linkDatasByDomain[linkData.domain.single]);
    }
    final List<LinkData> linkDatasByDomainValues =
        linkDatasByDomain.values.toList();
    domainErrorCountNotifier.value =
        linkDatasByDomainValues.where((element) => element.domainError).length;
    return linkDatasByDomainValues;
  }


  final selectedLink = ValueNotifier<LinkData?>(null);
  final linkDatasNotifier = ValueNotifier<List<LinkData>>(allLinkDatas);
  final showSpitScreenNotifier = ValueNotifier<bool>(false);
  final domainErrorCountNotifier = ValueNotifier<int>(0);

  final _searchContentNotifier = ValueNotifier<String>('');

  void _updateLinks() {
    final searchContent = _searchContentNotifier.value;
    final List<LinkData> linkDatas = searchContent.isNotEmpty
        ? allLinkDatas
            .where(
              (linkData) => linkData.matchesSearchToken(
                RegExp(
                  searchContent,
                  caseSensitive: false,
                ),
              ),
            )
            .toList()
        : allLinkDatas;

    linkDatasNotifier.value = linkDatas;
  }

  set searchContent(String content) {
    _searchContentNotifier.value = content;
    _updateLinks();
  }
}
