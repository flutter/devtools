// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'connect_screen.dart';

/// Top-level configuration for the app.
@immutable
class Config {
  /// The routes the navigator in the app will use.
  final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
    '/': (context) => ConnectScreen(),
  };
}
