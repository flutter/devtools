// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';

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

  /// The URI for the VM Service that DevTools is connected to.
  String? get vmServiceUri => params[vmServiceUriKey];

  /// The set of screens that are hidden based on the query parameters.
  Set<String> get hiddenScreens => {...?params[hideScreensKey]?.split(',')};

  /// Whether DevTools extensions should be hidden.
  bool get hideExtensions => hiddenScreens.contains(hideExtensionsValue);

  /// Whether all screens except DevTools extension screens should be hidden.
  bool get hideAllExceptExtensions =>
      hiddenScreens.contains(hideAllExceptExtensionsValue);

  /// The screen that should be visible for viewing offline data.
  String? get offlineScreenId => params[offlineScreenIdKey];

  /// The Inspector object reference that should be automatically selected when
  /// opening the Flutter Inspector.
  String? get inspectorRef => params[inspectorRefKey];

  /// The file path for the base file to load on the App Size screen.
  String? get appSizeBaseFilePath =>
      params[AppSizeApi.baseAppSizeFilePropertyName];

  /// The file path for the test file to load on the App Size screen.
  String? get appSizeTestFilePath =>
      params[AppSizeApi.testAppSizeFilePropertyName];

  /// The IDE that DevTools is embedded in or was launched from.
  String? get ide => params[ideKey];

  /// The feature of the IDE that DevTools was opened from.
  String? get ideFeature => params[ideFeatureKey];

  /// Keys for theming values that an IDE may pass in the embedded DevTools URI.
  IdeThemeQueryParams get ideThemeParams => IdeThemeQueryParams(params);

  /// The current [EmbedMode] of DevTools based on the query parameters.
  EmbedMode get embedMode => ideThemeParams.embedMode;

  /// Whether DevTools should be loaded using dart2wasm + skwasm instead of
  /// dart2js + canvaskit.
  bool get useWasm => params[wasmKey] == 'true';

  static const vmServiceUriKey = 'uri';
  static const hideScreensKey = 'hide';
  static const hideExtensionsValue = 'extensions';
  static const hideAllExceptExtensionsValue = 'all-except-extensions';
  static const offlineScreenIdKey = 'screen';
  static const inspectorRefKey = 'inspectorRef';
  static const ideKey = 'ide';
  static const ideFeatureKey = 'ideFeature';

  // This query parameter must match the String value in the Flutter bootstrap
  // logic that is used to select a web renderer. See
  // devtools/packages/devtools_app/web/flutter_bootstrap.js.
  static const wasmKey = 'wasm';

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
