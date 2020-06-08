// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/auto_dispose.dart';
import 'package:devtools_app/src/auto_dispose_mixin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class AutoDisposedWidget extends StatefulWidget {
  const AutoDisposedWidget(this.stream, {Key key}) : super(key: key);

  final Stream stream;

  @override
  _AutoDisposedWidgetState createState() => _AutoDisposedWidgetState();
}

class AutoDisposeContoller extends DisposableController
    with AutoDisposeControllerMixin {}

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
  group('Disposer', () {
    test('disposes streams', () {
      final disposer = Disposer();
      final controller1 = StreamController(sync: true);
      final controller2 = StreamController(sync: true);
      var c1Events = 0;
      var c2Events = 0;
      disposer.autoDispose(controller1.stream.listen((data) {
        c1Events++;
      }));
      disposer.autoDispose(controller2.stream.listen((data) {
        c2Events++;
      }));
      expect(c1Events, 0);
      expect(c2Events, 0);
      controller1.add(null);
      expect(c1Events, 1);
      expect(c2Events, 0);
      controller1.add(null);
      controller2.add(null);
      expect(c1Events, 2);
      expect(c2Events, 1);
      disposer.cancel();

      // Make sure stream subscriptions are cancelled.
      controller1.add(null);
      controller2.add(null);
      expect(c1Events, 2);
      expect(c2Events, 1);
    });

    test('disposes listeners', () {
      final disposer = Disposer();
      final notifier = ValueNotifier<int>(42);
      final values = <int>[];
      disposer.addAutoDisposeListener(notifier, () {
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
      disposer.cancel();
      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, isFalse);
      notifier.value = 17;
      // Verify listener not fired.
      expect(values.length, equals(2));
      expect(values.last, equals(15));

      // Add a new listener:
      disposer.addAutoDisposeListener(notifier, () {
        values.add(notifier.value);
      });
      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, isTrue);
      notifier.value = 19;
      expect(values.length, equals(3));
      expect(values.last, equals(19));
      disposer.cancel();

      // ignore: invalid_use_of_protected_member
      expect(notifier.hasListeners, isFalse);
      notifier.value = 21;
      expect(values.length, equals(3));
      expect(values.last, equals(19));
    });

    test('throws an error when disposing already-disposed listeners', () {
      final disposer = Disposer();
      final notifier = ValueNotifier<int>(42);
      final values = <int>[];
      void callback() {
        values.add(notifier.value);
      }

      disposer.addAutoDisposeListener(notifier, callback);
      notifier.value = 72;
      expect(values, [72]);
      // After disposal, all notifier methods will throw. Disposer needs
      // to ignore this when cancelling.
      notifier.dispose();
      expect(() => disposer.cancel(), throwsA(anything));
      expect(values, [72]);
    });
  });

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
  });
}
