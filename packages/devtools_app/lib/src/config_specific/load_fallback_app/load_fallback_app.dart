// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '_load_fallback_app_stub.dart'
    if (dart.library.html) '_load_fallback_app_web.dart' as implementation;

/// Load a fallback version of the app if the user agrees.
///
/// The dialog to load a fallback version of the app must use platform specific
/// features as the regular app is likely broken enough that it cannot render
/// a dialog.
bool promptToLoadFallbackApp(String message) {
  return implementation.promptToLoadFallbackApp(message);
}
