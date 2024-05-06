// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';

extension type DevToolsQueryParams(Map<String, String?> params) {
  static DevToolsQueryParams empty() => DevToolsQueryParams({});

  static DevToolsQueryParams load() => DevToolsQueryParams(loadQueryParams());

  static DevToolsQueryParams fromUrl(String url) {
    final modifiedUrl = _simplifyDevToolsUrl(url);
    final uri = Uri.parse(modifiedUrl);
    return DevToolsQueryParams(uri.queryParameters);
  }

  DevToolsQueryParams withUpdates(Map<String, String?>? updates) {
    return DevToolsQueryParams({...params, ...?updates});
  }

  String? get vmServiceUri => params[vmServiceUriKey];

  EmbedMode get embedMode => ideThemeParams.embedMode;

  Set<String> get hiddenScreens => {...?params[hideScreensKey]?.split(',')};

  String? get offlineScreenId => params[offlineScreenIdKey];

  String? get inspectorRef => params[inspectorRefKey];

  // Keys for theming values that an IDE may pass in the embedded DevTools URI.
  IdeThemeQueryParams get ideThemeParams => IdeThemeQueryParams(params);

  static const vmServiceUriKey = 'uri';
  static const hideScreensKey = 'hide';
  static const offlineScreenIdKey = 'screen';
  static const inspectorRefKey = 'inspectorRef';

  // TODO(kenz): remove legacy value in May of 2025 when all IDEs are not using
  // these and 12 months have passed to allow users ample upgrade time.
  String? get legacyPage => params[legacyPageKey];
  static const legacyPageKey = 'page';
}

String _simplifyDevToolsUrl(String url) {
  // DevTools urls can have the form:
  // http://localhost:123/?key=value
  // http://localhost:123/#/?key=value
  // http://localhost:123/#/page-id?key=value
  // Since we just want the query params, we will modify the url to have an
  // easy-to-parse form.
  return url.replaceFirst(RegExp(r'#\/([\w\-]*)[?]'), '?');
}
