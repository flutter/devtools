// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
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
    return Tab(
      text: 'Debugger',
      icon: Icon(Octicons.getIconData('bug')),
    );
  }
}

class DebuggerScreenBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Don't build this in const because compile time const evaluation
    // will fail on non-web apps.
    return RawGestureDetector(
      gestures: {
        EagerGestureRecognizer: _EagerGestureFactory(PointerDeviceKind.mouse),
      },
      // TODO(djshuckerow): Follow up on this: if this code won't compile
      // on desktop as a const, then the constructor shouldn't be const.
      // ignore:prefer_const_constructors
      child: HtmlElementView(
        viewType: 'DebuggerFlutterPlugin',
      ),
    );
  }
}

class _EagerGestureFactory
    extends GestureRecognizerFactory<EagerGestureRecognizer> {
  _EagerGestureFactory(this.kind);

  final PointerDeviceKind kind;

  @override
  EagerGestureRecognizer constructor() => EagerGestureRecognizer(kind: kind);

  @override
  void initializer(EagerGestureRecognizer instance) {}
}
