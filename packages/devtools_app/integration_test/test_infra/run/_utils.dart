// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// ignore_for_file: avoid_print

bool debugTestScript = false;

void debugLog(String log) {
  if (debugTestScript) {
    print(log);
  }
}
