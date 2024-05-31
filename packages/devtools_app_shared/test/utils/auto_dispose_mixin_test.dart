// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class AutoDisposeController extends DisposableController
    with AutoDisposeControllerMixin {}

class AutoDisposedWidget extends StatefulWidget {
  const AutoDisposedWidget(this.stream, {super.key});

  final Stream<Object?> stream;

  @override
  State<AutoDisposedWidget> createState() => _AutoDisposedWidgetState();
}

class _AutoDisposedWidgetState extends State<AutoDisposedWidget>
    with AutoDisposeMixin {
  int eventCount = 0;
  @override
  void initState() {
    super.initState();
    autoDisposeStreamSubscription(widget.stream.listen(_onData));
  }

  void _onData(Object? _) {
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
      final controller1 = StreamController<void>(sync: true);
      final controller2 = StreamController<void>(sync: true);
      var c1Events = 0;
      var c2Events = 0;
      disposer.autoDisposeStreamSubscription(
        controller1.stream.listen((_) {
          c1Events++;
        }),
      );
      disposer.autoDisposeStreamSubscription(
        controller2.stream.listen((_) {
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

    test('cancels and disposes a single listener', () {
      final disposer = Disposer();
      final notifier = ValueNotifier<int>(42);
      final values = <int>[];
      void listener() {
        values.add(notifier.value);
      }

      disposer.addAutoDisposeListener(notifier, listener);
      expect(notifier.hasListeners, isTrue);
      notifier.value = 13;
      expect(values.length, equals(1));
      expect(values.last, equals(13));
      notifier.value = 15;
      expect(values.length, equals(2));
      expect(values.last, equals(15));
      expect(notifier.hasListeners, isTrue);
      disposer.cancelListener(listener);
      expect(notifier.hasListeners, isFalse);
      notifier.value = 17;
      // Verify listener not fired.
      expect(values.length, equals(2));
      expect(values.last, equals(15));

      // Add a new listener:
      disposer.addAutoDisposeListener(notifier, listener);
      expect(notifier.hasListeners, isTrue);
      notifier.value = 19;
      expect(values.length, equals(3));
      expect(values.last, equals(19));
      disposer.cancelListener(listener);

      expect(notifier.hasListeners, isFalse);
      notifier.value = 21;
      expect(values.length, equals(3));
      expect(values.last, equals(19));
    });

    test('cancels listeners with excludeIds', () {
      final disposer = Disposer();
      final notifier = ValueNotifier<int>(42);

      final values1 = <int>[];
      void listener1() {
        values1.add(notifier.value);
      }

      final values2 = <int>[];
      void listener2() {
        values2.add(notifier.value);
      }

      disposer.addAutoDisposeListener(notifier, listener1);
      disposer.addAutoDisposeListener(notifier, listener2, 'id-2');
      expect(notifier.hasListeners, isTrue);
      notifier.value = 13;
      expect(values1.length, equals(1));
      expect(values1.last, equals(13));
      expect(values2.length, equals(1));
      expect(values2.last, equals(13));

      disposer.cancelListeners(excludeIds: ['id-2']);
      notifier.value = 15;
      // Verify the first listener was cancelled and did not fire.
      expect(values1.length, equals(1));
      expect(values1.last, equals(13));

      // Verify the second listener was not cancelled and did fire.
      expect(values2.length, equals(2));
      expect(values2.last, equals(15));

      expect(notifier.hasListeners, isTrue);

      // Cancel all listeners.
      disposer.cancelListeners();
      expect(notifier.hasListeners, isFalse);
      notifier.value = 19;

      // Verify neither listeners fire.
      expect(values1.length, equals(1));
      expect(values1.last, equals(13));
      expect(values2.length, equals(2));
      expect(values2.last, equals(15));
    });

    group('callOnceWhenReady', () {
      for (final isReady in [false, true]) {
        group('isReady=$isReady', () {
          test('triggers callback and cancels listeners when ready ', () async {
            final disposer = Disposer();
            final trigger = ValueNotifier<bool?>(!isReady);
            int callbackCounter = 0;

            disposer.callOnceWhenReady(
              trigger: trigger,
              readyWhen: (triggerValue) => triggerValue == isReady,
              callback: () {
                callbackCounter++;
              },
            );

            expect(callbackCounter, equals(0));
            expect(disposer.listenables.length, equals(1));
            expect(disposer.listeners.length, equals(1));

            // Set a value that won't trigger the callback.
            trigger.value = null;

            await shortDelay();

            expect(trigger.hasListeners, isTrue);
            expect(callbackCounter, equals(0));
            expect(disposer.listenables.length, equals(1));
            expect(disposer.listeners.length, equals(1));

            // Set a value that will trigger the callback.
            trigger.value = isReady;

            await shortDelay();

            expect(trigger.hasListeners, isFalse);
            expect(disposer.listenables.length, equals(0));
            expect(disposer.listeners.length, equals(0));

            // Check that we ran the callback.
            expect(callbackCounter, equals(1));

            // Keep changing the isReady value to make sure we don't trigger again.
            trigger.value = true;
            trigger.value = null;

            await shortDelay();

            // Verify callback not fired again.
            expect(callbackCounter, equals(1));
          });

          test('removes listeners when disposer cancels', () async {
            final disposer = Disposer();
            final trigger = ValueNotifier<bool>(!isReady);
            int callbackCounter = 0;

            disposer.callOnceWhenReady(
              trigger: trigger,
              readyWhen: (triggerValue) => triggerValue == isReady,
              callback: () {
                callbackCounter++;
              },
            );

            expect(trigger.hasListeners, isTrue);
            expect(disposer.listenables.length, equals(1));
            expect(disposer.listeners.length, equals(1));
            expect(callbackCounter, equals(0));

            disposer.cancelListeners();

            expect(trigger.hasListeners, isFalse);
            expect(disposer.listenables.length, equals(0));
            expect(disposer.listeners.length, equals(0));

            // Change the isReady value to make sure we don't trigger again.
            trigger.value = isReady;

            await shortDelay();

            // Verify callback not fired again.
            expect(callbackCounter, equals(0));
          });

          test(
            'runs callback immediately if starting in the ready state',
            () async {
              final disposer = Disposer();
              final trigger = ValueNotifier<bool>(isReady);
              int callbackCounter = 0;

              expect(trigger.hasListeners, isFalse);

              disposer.callOnceWhenReady(
                trigger: trigger,
                readyWhen: (triggerValue) => triggerValue == isReady,
                callback: () {
                  callbackCounter++;
                },
              );

              expect(trigger.hasListeners, isFalse);
              expect(callbackCounter, equals(1));
              expect(disposer.listenables.length, equals(0));
              expect(disposer.listeners.length, equals(0));

              // Change the isReady value to make sure we don't trigger again.
              trigger.value = !trigger.value;

              await shortDelay();

              // Verify callback not fired again.
              expect(callbackCounter, equals(1));
            },
          );
        });
      }
    });
  });

  testWidgets('Test stream auto dispose', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final key = GlobalKey();
    final controller = StreamController<void>();
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

  test('Test Listenable auto dispose', () {
    final controller = AutoDisposeController();
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
