// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_flutter/src/config.dart';
import 'package:devtools_flutter/src/scaffold.dart';
import 'package:devtools_flutter/src/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrappers.dart';

void main() {
  group('DevToolsScaffold widget', () {
    const screens = [
      _TestScreen('page3', Key('page 1')),
      _TestScreen('page2', Key('page 2')),
    ];

    testWidgets('displays in narrow mode without error',
        (WidgetTester tester) async {
      await setWindowSize(const Size(800.0, 1200.0));

      await tester.pumpWidget(wrap(DevToolsScaffold(config: _TestConfig())));
      expect(find.byKey(contentKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.fullWidthKey), findsNothing);
    });

    testWidgets('displays in full-width mode without error',
        (WidgetTester tester) async {
      await setWindowSize(const Size(1203.0, 1200.0));

      await tester.pumpWidget(wrap(DevToolsScaffold(config: _TestConfig())));
      expect(find.byKey(contentKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.fullWidthKey), findsOneWidget);
      expect(find.byKey(DevToolsScaffold.narrowWidthKey), findsNothing);
    });
  });
}

class _TestConfig extends Config {
  @override
  List<Screen> get screensWithTabs => [];
}

class _TestScreen extends Screen {
  const _TestScreen(String name, this.key) : super(name, name);

  static const contentKey = Key('DevToolsScaffold Content');

  final Key key;

  @override
  Widget build(BuildContext context) {
    return SizedBox(key: key);
  }

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      text: name,
      icon: Icon(Icons.computer),
    );
  }
}
