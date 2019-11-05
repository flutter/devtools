// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/auto_dispose.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devtools_app/src/flutter/auto_dispose_mixin.dart';

class AutoDisposedWidget extends StatefulWidget {
  const AutoDisposedWidget(this.stream, {Key key}) : super(key: key);

  final Stream stream;

  @override
  _AutoDisposedWidgetState createState() => _AutoDisposedWidgetState();
}

class AutoDisposeContoller extends DisposableController
    with AutoDisposeBase, AutoDisposeControllerMixin {}

class _AutoDisposedWidgetState extends State<AutoDisposedWidget>
    with AutoDisposeBase, AutoDisposeMixin {
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
  testWidgets('Test stream auto dispose', (WidgetTester tester) async {
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

  test('Test Listenable auto dispose', () async {
    final controller = AutoDisposeContoller();
    final notifier = ValueNotifier<int>(42);
    final values = <int>[];
    controller.addAutoDisposeListener(notifier, () {
      values.add(notifier.value);
    });
    // ignore: invalid_use_of_protected_member
    expect(notifier.hasListeners, isTrue);
    notifier.value = 13;
    expect(values.length, equals(1));
    expect(values.last, equals(13));
    notifier.value = 15;
    expect(values.length, equals(2));
    expect(values.last, equals(15));
    // ignore: invalid_use_of_protected_member
    expect(notifier.hasListeners, isTrue);
    controller.cancel();
    // ignore: invalid_use_of_protected_member
    expect(notifier.hasListeners, isFalse);
    notifier.value = 17;
    // Verify listener not fired.
    expect(values.length, equals(2));
    expect(values.last, equals(15));
    controller.addAutoDisposeListener(notifier, () {
      values.add(notifier.value);
    });
    // ignore: invalid_use_of_protected_member
    expect(notifier.hasListeners, isTrue);
    notifier.value = 19;
    expect(values.length, equals(3));
    expect(values.last, equals(19));
    controller.dispose();
    // ignore: invalid_use_of_protected_member
    expect(notifier.hasListeners, isFalse);
    notifier.value = 21;
    expect(values.length, equals(3));
    expect(values.last, equals(19));
  });
}
