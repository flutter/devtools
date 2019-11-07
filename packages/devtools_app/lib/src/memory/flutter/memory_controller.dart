// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class MemoryController {
  MemoryController();

  bool _paused = false;

  bool get paused =>_paused;

  void pauseTimer() {
    _paused = true;
  }

  void resumeTimer() {
    _paused = false;
  }

  bool _restartSample = false;
  
  void resetTimer() {
    _restartSample = true;
  }
}