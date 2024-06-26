// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An abstract implementation of a key value store.
///
/// We have concrete implementations for Flutter web, Flutter desktop, and
/// Flutter web when launched from the DevTools server.
abstract class Storage {
  /// Return the value associated with the given key.
  Future<String?> getValue(String key);

  /// Set a value for the given key.
  Future<void> setValue(String key, String value);
}
