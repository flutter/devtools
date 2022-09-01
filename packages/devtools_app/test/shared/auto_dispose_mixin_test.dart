// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/primitives/auto_dispose.dart';
import 'package:devtools_app/src/primitives/auto_dispose_mixin.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class AutoDisposedWidget extends StatefulWidget {
  const AutoDisposedWidget(this.stream, {Key? key}) : super(key: key);

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
    autoDisposeStreamSubscription(widget.stream.listen(_onData));
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
      disposer.autoDisposeStreamSubscription(
        controller1.stream.listen((data) {
          c1Events++;
        }),
      );
      disposer.autoDisposeStreamSubscription(
        controller2.stream.listen((data) {
          c2Events++;
        }),
      );
      expect(c1Events, 0);
      expect(c2Events, 0);
      controller1.add(null);
      expect(c1Events, 1);
      expect(c2Events, 0);
      controller1.add(null);
      controller2.add(null);
      expect(c1Events, 2);
      expect(c2Events, 1);
      disposer.cancelStreamSubscriptions();

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
      expect(notifier.hasListeners, isTrue);
      notifier.value = 13;
      expect(values.length, equals(1));
      expect(values.last, equals(13));
      notifier.value = 15;
      expect(values.length, equals(2));
      expect(values.last, equals(15));
      expect(notifier.hasListeners, isTrue);
      disposer.cancelListeners();
      expect(notifier.hasListeners, isFalse);
      notifier.value = 17;
      // Verify listener not fired.
      expect(values.length, equals(2));
      expect(values.last, equals(15));

      // Add a new listener:
      disposer.addAutoDisposeListener(notifier, () {
        values.add(notifier.value);
      });
      expect(notifier.hasListeners, isTrue);
      notifier.value = 19;
      expect(values.length, equals(3));
      expect(values.last, equals(19));
      disposer.cancelListeners();

      expect(notifier.hasListeners, isFalse);
      notifier.value = 21;
      expect(values.length, equals(3));
      expect(values.last, equals(19));
    });

    group('callOnceWhenReady', () {
      for (bool readyWhen in [false, true]) {
        group('readyWhen=$readyWhen', () {
          testWidgets('triggers callback and cancels listeners when ready ',
              (WidgetTester tester) async {
            final disposer = Disposer();
            final trigger = ValueNotifier<bool?>(!readyWhen);
            final callbackEntries = <int>[];
            int counter = 0;

            disposer.callOnceWhenReady(
              trigger: trigger,
              readyWhen: (triggerValue) => triggerValue == readyWhen,
              callback: () {
                counter++;
                callbackEntries.add(counter);
              },
            );

            expect(callbackEntries, equals([]));

            // Set a value that won't trigger the callback.
            trigger.value = null;

            await tester.pump();
            expect(trigger.hasListeners, isTrue);
            expect(callbackEntries, equals([]));

            // Set a value that will trigger the callback.
            trigger.value = readyWhen;

            await tester.pump();

            expect(trigger.hasListeners, isFalse);

            // Check that we ran the callback.
            expect(callbackEntries, equals([1]));

            // Keep changing the isReady value to make sure we don't trigger again.
            trigger.value = true;
            trigger.value = null;

            await tester.pump();

            // Verify callback not fired again.
            expect(callbackEntries, equals([1]));
          });

          testWidgets('removes listeners when disposer cancels',
              (WidgetTester tester) async {
            final disposer = Disposer();
            final trigger = ValueNotifier<bool>(!readyWhen);
            final callbackEntries = <int>[];
            int counter = 0;

            disposer.callOnceWhenReady(
              trigger: trigger,
              readyWhen: (triggerValue) => triggerValue == readyWhen,
              callback: () {
                counter++;
                callbackEntries.add(counter);
              },
            );

            expect(trigger.hasListeners, isTrue);
            expect(callbackEntries, equals([]));

            disposer.cancelListeners();

            expect(trigger.hasListeners, isFalse);

            // Change the isReady value to make sure we don't trigger again.
            trigger.value = readyWhen;

            await tester.pump();

            // Verify callback not fired again.
            expect(callbackEntries, equals([]));
          });

          testWidgets(
              'runs callback immediately if starting in the ready state',
              (WidgetTester tester) async {
            final disposer = Disposer();
            final trigger = ValueNotifier<bool>(readyWhen);
            final callbackEntries = <int>[];
            int counter = 0;

            expect(trigger.hasListeners, isFalse);

            disposer.callOnceWhenReady(
              trigger: trigger,
              readyWhen: (triggerValue) => triggerValue == readyWhen,
              callback: () {
                counter++;
                callbackEntries.add(counter);
              },
            );

            expect(trigger.hasListeners, isFalse);
            expect(callbackEntries, equals([1]));

            // Change the isReady value to make sure we don't trigger again.
            trigger.value = !trigger.value;

            await tester.pump();

            // Verify callback not fired again.
            expect(callbackEntries, equals([1]));
          });
        });
      }
    });
  });

  testWidgets('Test stream auto dispose', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final key = GlobalKey();
    final controller = StreamController();
    await tester.pumpWidget(AutoDisposedWidget(controller.stream, key: key));

    final state = key.currentState as _AutoDisposedWidgetState;
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
    expect(notifier.hasListeners, isTrue);
    notifier.value = 13;
    expect(values.length, equals(1));
    expect(values.last, equals(13));
    notifier.value = 15;
    expect(values.length, equals(2));
    expect(values.last, equals(15));
    expect(notifier.hasListeners, isTrue);
    controller.cancelListeners();
    expect(notifier.hasListeners, isFalse);
    notifier.value = 17;
    // Verify listener not fired.
    expect(values.length, equals(2));
    expect(values.last, equals(15));
  });
}
