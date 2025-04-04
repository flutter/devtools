// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '_focus_utils_desktop.dart'
    if (dart.library.js_interop) '_focus_utils_web.dart';

/// Workaround to prevent TextFields from holding onto focus when IFRAME-ed.
///
/// See https://github.com/flutter/flutter/issues/155265 for details.
void setUpTextFieldFocusFixHandler() {
  addBlurListener();
}

/// Workaround to prevent TextFields from holding onto focus when IFRAME-ed.
///
/// See https://github.com/flutter/flutter/issues/155265 for details.
void removeTextFieldFocusFixHandler() {
  removeBlurListener();
}
