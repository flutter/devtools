// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Retrieve a string from the asset bundle.
///
/// Throws an exception if the asset is not found.
///
/// If the `cache` argument is set to false, then the data will not be
/// cached, and reading the data may bypass the cache. This is useful if the
/// caller is going to be doing its own caching. (It might not be cached if
/// it's set to true either, that depends on the asset bundle
/// implementation.)
Future<String> loadStringImpl(String key, {bool cache = true}) {
  throw Exception('Assets not yet supported in dart:html app');
}
