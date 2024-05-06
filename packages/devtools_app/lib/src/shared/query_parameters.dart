// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';

extension type DevToolsQueryParams(Map<String, String?> params) {
  static DevToolsQueryParams empty() => DevToolsQueryParams({});

  static DevToolsQueryParams load() => DevToolsQueryParams(loadQueryParams());

  DevToolsQueryParams withUpdates(Map<String, String?>? updates) {
    return DevToolsQueryParams({...params, ...?updates});
  }

  String? get vmServiceUri => params[vmServiceUriKey];

  bool get embed => ideThemeParams.embed;

  Set<String> get hiddenScreens => {...?params[hideScreensKey]?.split(',')};

  bool get hideExtensions => hiddenScreens.contains('extensions');

  String? get offlineScreenId => params[offlineScreenIdKey];

  // Keys for theming values that an IDE may pass in the embedded DevTools URI.
  IdeThemeQueryParams get ideThemeParams => IdeThemeQueryParams(params);

  static const vmServiceUriKey = 'uri';
  static const hideScreensKey = 'hide';
  static const offlineScreenIdKey = 'screen';

  // TODO(kenz): remove legacy value in May of 2025 when all IDEs are not using
  // these and 12 months have passed to allow users ample upgrade time.
  String? get legacyPage => params[legacyPageKey];
  static const legacyPageKey = 'page';
}
