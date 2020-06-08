// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Return the url the application is launched from.
Future<String> initializePlatform() {
  throw UnimplementedError(
      'Attempting to initialize framework for unrecognized platform');
}
