// import 'package:freezed_annotation/freezed_annotation.dart';

import '../../eval_on_dart_library.dart';

import 'fake_freezed_annotation.dart';

// run `flutter pub run build_runner build --delete-conflicting-outputs` to re-generate
part 'result.freezed.dart';

@freezed
abstract class Result<T> with _$Result<T> {
  Result._();
  factory Result.data(@nullable T value) = _ResultData<T>;
  factory Result.error(Object error, [StackTrace stackTrace]) = _ResultError<T>;

  factory Result.guard(T Function() cb) {
    try {
      return Result.data(cb());
    } catch (err, stack) {
      return Result.error(err, stack);
    }
  }

  static Future<Result<T>> guardFuture<T>(Future<T> Function() cb) async {
    try {
      return Result.data(await cb());
    } catch (err, stack) {
      return Result.error(err, stack);
    }
  }

  Result<Res> chain<Res>(Res Function(T value) cb) {
    return when(
      data: (value) {
        try {
          return Result.data(cb(value));
        } catch (err, stack) {
          return Result.error(err, stack);
        }
      },
      error: (err, stack) => Result.error(err, stack),
    );
  }

  T get dataOrThrow {
    return when(
      data: (value) => value,
      error: (err, stack) {
        // ignore: only_throw_errors
        throw err;
      },
    );
  }
}

Result<T> parseSentinel<T>(Object value) {
  // TODO(rrousselGit) remove condition after migrating to NNBD
  if (value == null) return Result.data(null);

  if (value is T) return Result.data(value);
  if (value is SentinelException) return Result.error(value);

  return Result.error(StateError('Unknown error'));
}
