// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devtools_app/src/flutter/auto_dispose_mixin.dart';

class AutoDisposedWidget extends StatefulWidget {
  const AutoDisposedWidget(this.stream, {Key key}) : super(key: key);

  final Stream stream;

  @override
  _AutoDisposedWidgetState createState() => _AutoDisposedWidgetState();
}

class _AutoDisposedWidgetState extends State<AutoDisposedWidget>
    with AutoDisposeMixin {
  int eventCount = 0;
  @override
  void initState() {
    super.initState();
    autoDispose(widget.stream.listen(_onData));
  }

  void _onData(dynamic data) {
    eventCount++;
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

void main() {
  testWidgets('Test auto dispose', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final key = GlobalKey();
    final controller = StreamController();
    await tester.pumpWidget(AutoDisposedWidget(controller.stream, key: key));

    final _AutoDisposedWidgetState state = key.currentState;
    // Verify that the eventCount matches the number of events sent.
    expect(state.eventCount, 0);
    controller.add(null);
    await tester.pump();
    expect(state.eventCount, 1);
    controller.add(null);
    await tester.pump();
    expect(state.eventCount, 2);

    await tester.pumpWidget(Container());
    // Verify that the eventCount is not updated after the widget has been
    // disposed.
    expect(state.eventCount, 2);
    controller.add(null);
    await tester.pump();
    expect(state.eventCount, 2);
  });
}
