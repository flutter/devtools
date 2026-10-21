// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/shared.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:unified_analytics/unified_analytics.dart' as ua;

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

  // TODO(https://github.com/flutter/devtools/issues/9811): Remove this legacy
  // parameter once IDE integrations have been passing dashTool and dashIdeName
  // for long enough (at least two years) to allow users ample time to upgrade.
  /// The IDE that DevTools is embedded in or was launched from.
  ///
  /// This is a legacy value (for example `VSCode`, `Android-Studio` or
  /// `IntelliJ-IDEA`) that IDE integrations continue to pass for the benefit of
  /// versions of DevTools that predate [dashTool] and [dashIdeName]. Prefer
  /// those parameters, and use [isVsCode] to check for VS Code.
  String? get ide => params[ideKey];

  /// The feature of the IDE that DevTools was opened from.
  String? get ideFeature => params[ideFeatureKey];

  /// The canonical label of the Dash tool, such as an IDE plugin, that DevTools
  /// is embedded in or was launched from (for example `vscode-plugins` or
  /// `intellij-plugins`).
  ///
  /// This corresponds to the `DASH__TOOL` environment variable that IDEs set
  /// for the processes they spawn. It is shared by every variant of an IDE
  /// that uses the same plugin (for example VS Code, Cursor and Antigravity).
  /// See [ua.DashTool] for the labels of the known tools.
  String? get dashTool => params[dashToolKey];

  /// The name of the IDE that DevTools is embedded in or was launched from (for
  /// example `Visual Studio Code`, `Cursor`, `Antigravity` or `Android Studio`).
  ///
  /// This corresponds to the `DASH__IDE_NAME` environment variable that IDEs
  /// set for the processes they spawn. The possible values are open-ended,
  /// because new IDEs, and forks of existing IDEs, choose their own names. So
  /// this should only be used for display and diagnostics, and not to decide
  /// how DevTools behaves. Use [dashTool] or [isVsCode] for that.
  String? get dashIdeName => params[dashIdeNameKey];

  /// The best available name of the IDE that DevTools is embedded in or was
  /// launched from, for display and diagnostics (for example in bug reports).
  ///
  /// This is [dashIdeName], which distinguishes forks of an IDE (like Cursor)
  /// from the IDE itself, falling back to the legacy [ide] for IDE integrations
  /// that do not pass [dashIdeName].
  String? get ideDisplayName => dashIdeName ?? ide;

  /// Whether DevTools is embedded in or was launched from VS Code, or a fork of
  /// VS Code such as Cursor or Antigravity.
  ///
  /// This is determined by [dashTool], which is the same for every variant of
  /// VS Code. The legacy [ide] is checked as well, for IDE integrations that do
  /// not pass [dashTool].
  bool get isVsCode =>
      dashTool == ua.DashTool.vscodePlugins.label ||
      ide == legacyVsCodeIdeValue;

  /// Keys for theming values that an IDE may pass in the embedded DevTools URI.
  IdeThemeQueryParams get ideThemeParams => IdeThemeQueryParams(params);

  /// The current [EmbedMode] of DevTools based on the query parameters.
  EmbedMode get embedMode => ideThemeParams.embedMode;

  /// Whether DevTools should be loaded using dart2wasm + skwasm instead of
  /// dart2js + canvaskit.
  bool get useWasm => params[compilerKey] == 'wasm';

  /// Whether DevTools should be loaded using dart2js + canvaskit instead of
  /// dart2wasm + skwasm.
  ///
  /// This should only ever be explicitly set by the user if their app fails to
  /// load using wasm.
  bool get useJs => params[compilerKey] == 'js';

  static const vmServiceUriKey = 'uri';
  static const hideScreensKey = 'hide';
  static const hideExtensionsValue = 'extensions';
  static const hideAllExceptExtensionsValue = 'all-except-extensions';
  static const offlineScreenIdKey = 'screen';
  static const inspectorRefKey = 'inspectorRef';
  static const ideKey = 'ide';
  static const ideFeatureKey = 'ideFeature';
  static const dashToolKey = 'dashTool';
  static const dashIdeNameKey = 'dashIdeName';

  /// The value of the legacy [ide] parameter that VS Code, and the forks of VS
  /// Code that use the same extension, pass.
  static const legacyVsCodeIdeValue = 'VSCode';

  /// The value of the legacy [ide] parameter that Android Studio passes.
  static const legacyAndroidStudioIdeValue = 'Android-Studio';

  /// The value of the legacy [ide] parameter that IntelliJ IDEA passes.
  static const legacyIntelliJIdeValue = 'IntelliJ-IDEA';

  /// Query parameter key to determine whether to use dart2wasm or dart2js.
  ///
  ///  This query parameter must match the String value in the Flutter bootstrap
  ///  logic that is used to select a web renderer. See
  /// devtools/packages/devtools_app/web/flutter_bootstrap.js.
  ///
  /// Valid values are "js" or "wasm".
  static const compilerKey = 'compiler';

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
