// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

Map<String, String> loadQueryParams() => {};

/// Gets the URL from the browser.
///
/// Returns null for non-web platforms.
String? getWebUrl() => null;

/// Performs a web redirect using window.location.replace().
///
/// No-op for non-web platforms.
// Unused parameter lint doesn't make sense for stub files.
// ignore: avoid-unused-parameters
void webRedirect(String url) {}
