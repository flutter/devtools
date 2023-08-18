// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

/// Returns [routeName] with [queryParameters] appended as [Uri] query
/// parameters.
///
/// If not overridden, this will preserve the theme parameter across
/// navigations.
///
///
/// This will fail because we can't determine what the theme value for the app
/// is.

String routeNameWithQueryParams(
  BuildContext? context,
  String routeName, [
  Map<String, String>? queryParameters,
]) {
  final newQueryParams =
      queryParameters == null ? null : Map.of(queryParameters);

  String? previousQuery;
  if (context == null) {
    // We allow null context values to make easy pure-VM tests.
    previousQuery = '';
  } else {
    previousQuery = ModalRoute.of(context)!.settings.name;
    // When this function is invoked from an unnamed context,
    // infer from the global theme configuration.
    previousQuery ??= _inferThemeParameter(Theme.of(context).colorScheme);
  }

  final previousQueryParams = Uri.parse(previousQuery).queryParameters;
  // Preserve the theme across app-triggered navigations.
  if (newQueryParams != null &&
      !newQueryParams.containsKey('theme') &&
      previousQueryParams['theme'] == 'dark') {
    newQueryParams['theme'] = 'dark';
  }
  return Uri.parse(routeName)
      .replace(queryParameters: newQueryParams)
      .toString();
}

/// Infers the app's theme from a global constant.
///
/// When calling from an unnamed route, we can't infer the theme
/// value from the Uri. For example,
///
/// ```dart
/// Navigator.of(context).push(MaterialPageRoute(builder: (innerContext) {
///   routeNameWithQueryParams(innerContext, '/foo');
/// }));
/// ```
///
/// ModalRoute.of`(innerContext)` returns the unnamed page route.
String _inferThemeParameter(ColorScheme colorScheme) =>
    colorScheme.isDark ? '/unnamedRoute?theme=dark' : '/unnamedRoute';
