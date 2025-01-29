// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid-unused-parameters, intentional empty methods for stub file.

Map<String, String> loadQueryParams() => {};

/// Gets the URL from the browser.
///
/// Returns null for non-web platforms.
String? getWebUrl() => null;

/// Performs a web redirect using window.location.replace().
///
/// No-op for non-web platforms.
// Unused parameter lint doesn't make sense for stub files.
void webRedirect(String url) {}

/// Updates the query parameter with [key] to the new [value], and optionally
/// reloads the page when [reload] is true.
///
/// No-op for non-web platforms.
void updateQueryParameter(String key, String? value, {bool reload = false}) {}
