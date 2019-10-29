// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Returns [routeName] with [queryParameters] appended as [Uri] query
/// parameters.
///
/// If not overridden, this will preserve the theme parameter across
/// navigations.
String routeNameWithQueryParams(BuildContext context, String routeName,
    [Map<String, String> queryParameters]) {
  final newQueryParams =
      queryParameters == null ? null : Map.of(queryParameters);
  final previousQueryParams =
      Uri.parse(ModalRoute.of(context).settings.name ?? '').queryParameters;
  // Preserve the theme across app-triggered navigations.
  if (newQueryParams != null &&
      !newQueryParams.containsKey('theme') &&
      previousQueryParams.containsKey('theme')) {
    newQueryParams['theme'] = previousQueryParams['theme'];
  }
  return Uri.parse(routeName)
      .replace(queryParameters: newQueryParams)
      .toString();
}
