// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';

class DebuggerScreen extends Screen {
  const DebuggerScreen();

  @override
  Widget build(BuildContext context) {
    return DebuggerScreenBody();
  }

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Debugger',
      icon: Icon(Octicons.bug),
    );
  }
}

class DebuggerScreenBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      final theme = Theme.of(context);
      final textStyle = Theme.of(context)
          .textTheme
          .headline
          .copyWith(color: theme.accentColor);
      return Center(
        child: Text(
          'The debugger screen is only available when running DevTools as a web'
          'app.\n'
          '\n'
          'It is implemented as a webview, which is not available in Flutter '
          'desktop embedding.',
          style: textStyle,
          textAlign: TextAlign.center,
        ),
      );
    }

    // TODO(https://github.com/flutter/flutter/issues/43532): Don't build const
    // because compile time const evaluation will fail on non-web apps.
    // ignore:prefer_const_constructors
    final webView = HtmlElementView(
      viewType: 'DebuggerFlutterPlugin',
    );

    // Wrap the content with an EagerGestureRecognizer to pass all mouse
    // events to the web view.
    return RawGestureDetector(
      gestures: {
        EagerGestureRecognizer: _EagerGestureFactory(PointerDeviceKind.mouse),
      },
      child: webView,
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
