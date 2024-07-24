// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_model.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_services.dart';
import 'package:flutter_test/flutter_test.dart';

class DeepLinksTestController extends DeepLinksController {
  @override
  Future<String?> packageDirectoryForMainIsolate() async {
    return null;
  }

  @override
  Future<void> validateLinks() async {
    if (validatedLinkDatas.all.isEmpty) {
      return;
    }
    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount: validatedLinkDatas.byDomain
          .where((element) => element.domainErrors.isNotEmpty)
          .length,
      pathErrorCount: validatedLinkDatas.byPath
          .where((element) => element.pathErrors.isNotEmpty)
          .length,
    );
    applyFilters();
    pagePhase.value = PagePhase.linksValidated;
  }

  @override
  void selectLink(LinkData linkdata) async {
    selectedLink.value = linkdata;
    if (linkdata.domainErrors.isNotEmpty) {
      generatedAssetLinksForSelectedLink.value = GenerateAssetLinksResult(
        '',
        'fake generated content',
      );
    }
  }
}
