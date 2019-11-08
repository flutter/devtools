// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This library must not have direct dependencies on Flutter UI (widgets).
///
/// To control the state of the feed use these methods.

library memory_controller;

typedef chartStateListener = void Function();

class MemoryController {
  MemoryController();

  bool _paused = false;

  bool get paused => _paused;

  void pauseLiveFeed() {
    _paused = true;
  }

  void resumeLiveFeed() {
    _paused = false;
  }

  /// Listeners to hookup modifying the MemoryChartState.
  final List<chartStateListener> _resetFeedListeners = [];

  void addResetFeedListener(chartStateListener listener) {
    _resetFeedListeners.add(listener);
  }

  void removeResetFeedListener(chartStateListener listener) {
    _resetFeedListeners.remove(listener);
  }

  // Call any ChartState listeners.
  void notifyResetFeedListeners() {
    for (var notifyListener in _resetFeedListeners) {
      notifyListener();
    }
  }
}
