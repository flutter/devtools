// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

bool promptToLoadFallbackApp(String message) {
  print(
    'Loading a fallback version of DevTools is not supported on this platform.\n'
    '$message',
  );
  return false;
}
