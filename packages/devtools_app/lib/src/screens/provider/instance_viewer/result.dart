// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vm_service/vm_service.dart' hide SentinelException;

import '../../../shared/eval_on_dart_library.dart';

// This part is generated using package:freezed, but without the devtool
// depending on the package.
// To update the generated files: temporarily add
// https://pub.dev/packages/freezed to dependencies; replace the
// `fake_freezed_annotation.dart` import with
// 'package:freezed_annotation/freezed_annotation.dart', then execute
// `flutter pub run build_runner build`.
part 'result.freezed.dart';

@freezed
abstract class Result<T extends Object> with _$Result<T> {
  Result._();
  factory Result.data(T value) = _ResultData<T>;
  factory Result.error(Object error, [StackTrace? stackTrace]) =
      _ResultError<T>;

  factory Result.guard(T Function() cb) {
    try {
      return Result.data(cb());
    } catch (err, stack) {
      return Result.error(err, stack);
    }
  }

  static Future<Result<T>> guardFuture<T extends Object>(
      Future<T> Function() cb) async {
    try {
      return Result.data(await cb());
    } catch (err, stack) {
      return Result.error(err, stack);
    }
  }

  Result<Res> chain<Res extends Object>(Res Function(T value) cb) {
    return when(
      data: (value) {
        try {
          return Result.data(cb(value!));
        } catch (err, stack) {
          return Result.error(err, stack);
        }
      },
      error: (err, stack) => Result.error(err, stack),
    );
  }

  T get dataOrThrow {
    return when<T>(
      data: (value) => value!,
      error: (err, stack) {
        // ignore: only_throw_errors
        throw err;
      },
    );
  }
}

Result<T> parseSentinel<T extends Object>(Object value) {
  // TODO(rrousselGit) remove condition after migrating to NNBD

  if (value is T) return Result.data(value);

  if (value is Sentinel) {
    return Result.error(
      SentinelException(value),
      StackTrace.current,
    );
  }

  return Result.error(value, StackTrace.current);
}
