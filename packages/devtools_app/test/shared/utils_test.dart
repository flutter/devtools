import 'package:devtools_app/devtools_app.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebounceTimer', () {
    test('only calls the callback once, while the first call is still running',
        () {
      fakeAsync((async) {
        int callbackCounter = 0;
        DebounceTimer.periodic(
          const Duration(seconds: 1),
          (_) async {
            callbackCounter++;
            await Future<void>.delayed(const Duration(seconds: 60));
          },
        );
        async.elapse(const Duration(seconds: 40));
        expect(callbackCounter, 1);
      });
    });

    test('calls the callback once per period', () {
      fakeAsync((async) {
        int callbackCounter = 0;
        DebounceTimer.periodic(
          const Duration(seconds: 1),
          (_) async {
            callbackCounter++;
            await Future<void>.delayed(
              const Duration(milliseconds: 1),
            );
          },
        );
        async.elapse(const Duration(seconds: 40));
        expect(callbackCounter, 40);
      });
    });

    test('cancels the timer when cancel is called', () {
      fakeAsync((async) {
        int callbackCounter = 0;
        final timer = DebounceTimer.periodic(
          const Duration(seconds: 1),
          (_) async {
            callbackCounter++;
            await Future<void>.delayed(
              const Duration(milliseconds: 1),
            );
          },
        );
        async.elapse(const Duration(seconds: 20));
        timer.cancel();
        async.elapse(const Duration(seconds: 20));
        expect(callbackCounter, 20);
      });
    });
  });
}
