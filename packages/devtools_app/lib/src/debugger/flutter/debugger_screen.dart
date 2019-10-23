// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../../flutter/screen.dart';

class DebuggerScreen extends Screen {
  const DebuggerScreen() : super('Debugger');

  @override
  Widget build(BuildContext context) {
    return DebuggerScreenBody();
  }

  @override
  Widget buildTab(BuildContext context) {
    // TODO: implement buildTab
    return Tab(
      text: 'Debugger',
      icon: Octicons.getIconData('bug'),
    );
  }
}

class DebuggerScreenBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return null;
  }
}
