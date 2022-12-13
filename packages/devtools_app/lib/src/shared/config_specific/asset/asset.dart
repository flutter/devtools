// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '_asset_stub.dart' if (dart.library.ui) '_asset_flutter.dart';

/// Retrieve a string from the asset bundle.
///
/// Throws an exception if the asset is not found.
///
/// If the `cache` argument is set to false, then the data will not be
/// cached, and reading the data may bypass the cache. This is useful if the
/// caller is going to be doing its own caching. (It might not be cached if
/// it's set to true either, that depends on the asset bundle
/// implementation.)
Future<String> loadString(String key, {bool cache = true}) {
  return loadStringImpl(key, cache: cache);
}
