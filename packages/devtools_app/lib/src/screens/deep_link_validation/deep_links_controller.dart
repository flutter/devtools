// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'deep_links_model.dart';
import 'fake_data.dart';

class DeepLinksController {
  ValueListenable<List<LinkData>> get linkDatasNotifier => _linkDatasNotifier;
  ValueListenable<String> get searchContentNotifier => _searchContentNotifier;
  ValueListenable<bool> get showSpitScreenNotifier => _showSpitScreenNotifier;

  List<LinkData> get linkDatas => _linkDatasNotifier.value;

  bool get showSpitScreen => _showSpitScreenNotifier.value;

  final selectedLink = ValueNotifier<LinkData?>(null);

  final _linkDatasNotifier = ValueNotifier<List<LinkData>>(allLinkDatas);
  final _searchContentNotifier = ValueNotifier<String>('');
  final _showSpitScreenNotifier = ValueNotifier<bool>(false);

  set showSpitScreen(bool value) {
    _showSpitScreenNotifier.value = value;
  }

  set searchContent(String content) {
    _searchContentNotifier.value = content;
    _updateLinks();
  }

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

    _linkDatasNotifier.value = linkDatas;
  }

  List<LinkData> get getLinkDatasByPath {
    final linkDatasByPath = <String, LinkData>{};

    for (var linkData in _linkDatasNotifier.value) {
      linkDatasByPath[linkData.path] = linkData;
    }
    return linkDatasByPath.values.toList();
  }

  List<LinkData> get getLinkDatasByDomain {
    final linkDatasByDomain = <String, LinkData>{};

    for (var linkData in _linkDatasNotifier.value) {
      linkDatasByDomain[linkData.domain] = linkData;
    }
    return linkDatasByDomain.values.toList();
  }
}
