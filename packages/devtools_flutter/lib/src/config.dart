// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'connect_screen.dart';
import 'screen.dart';

/// Top-level configuration for the app.
@immutable
class Config {
  final List<Screen> allScreens = const [
    ConnectScreen(),
    EmptyScreen.inspector,
    EmptyScreen.timeline,
    EmptyScreen.performance,
    EmptyScreen.memory,
    EmptyScreen.logging,
  ];

  /// The main screens to show in the app's main navbar.
  final Set<Screen> screensWithTabs = const {
    EmptyScreen.inspector,
    EmptyScreen.timeline,
    EmptyScreen.performance,
    EmptyScreen.memory,
    EmptyScreen.logging,
  };
}
