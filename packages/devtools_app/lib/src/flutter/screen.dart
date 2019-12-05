// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'scaffold.dart';

/// Defines pages shown in the tabbar of the app.
@immutable
abstract class Screen {
  const Screen();

  /// Builds the tab to show for this screen in the [DevToolsScaffold]'s main navbar.
  ///
  /// This will not be used if the [Screen] is the only one shown in the scaffold.
  Widget buildTab(BuildContext context);

  /// Builds the body to display for this tab.
  Widget build(BuildContext context);
}
