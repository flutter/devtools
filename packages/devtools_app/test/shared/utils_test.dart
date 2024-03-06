import 'package:devtools_app/src/shared/utils.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebounceTimer', () {
    test('the callback happens immediately', () {
      fakeAsync((async) {
        int callbackCounter = 0;
        DebounceTimer.periodic(
          const Duration(seconds: 1),
          (_) async {
            callbackCounter++;
            await Future<void>.delayed(const Duration(seconds: 60));
          },
        );
        async.elapse(const Duration(milliseconds: 40));
        expect(callbackCounter, 1);
      });
    });

    test('only triggers another callback after the first is done', () {
      fakeAsync((async) {
        int callbackCounter = 0;
        DebounceTimer.periodic(
          const Duration(seconds: 1),
          (_) async {
            callbackCounter++;
            await Future<void>.delayed(const Duration(seconds: 30));
          },
        );
        async.elapse(const Duration(seconds: 40));
        expect(callbackCounter, 2);
      });
    });

    test('calls the callback at the beginning and then once per period', () {
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
        async.elapse(const Duration(milliseconds: 40500));
        expect(callbackCounter, 41);
      });
    });

    test(
      'cancels the periodic timer when cancel is called between the first and second callback calls',
      () {
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
          async.elapse(const Duration(milliseconds: 500));
          expect(callbackCounter, 1);

          timer.cancel();

          async.elapse(const Duration(seconds: 20));
          expect(callbackCounter, 1);
        });
      },
    );

    test(
      'cancels the periodic timer when cancelled after multiple periodic calls',
      () {
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
          async.elapse(const Duration(milliseconds: 20500));
          expect(callbackCounter, 21);

          timer.cancel();

          async.elapse(const Duration(seconds: 20));
          expect(callbackCounter, 21);
        });
      },
    );
  });
}
