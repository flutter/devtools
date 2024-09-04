// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

bool debugTestScript = true;

void debugLog(String log) {
  if (debugTestScript) {
    print(log);
  }
}
