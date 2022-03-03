// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies

// @dart=2.9

part of 'result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

/// @nodoc
class _$ResultTearOff {
  const _$ResultTearOff();

// ignore: unused_element
  _ResultData<T> data<T>(@nullable T value) {
    return _ResultData<T>(
      value,
    );
  }

// ignore: unused_element
  _ResultError<T> error<T>(Object error, [StackTrace stackTrace]) {
    return _ResultError<T>(
      error,
      stackTrace,
    );
  }
}

/// @nodoc
// ignore: unused_element
const $Result = _$ResultTearOff();

/// @nodoc
mixin _$Result<T> {
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required TResult data(@nullable T value),
    @required TResult error(Object error, StackTrace stackTrace),
  });
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult data(@nullable T value),
    TResult error(Object error, StackTrace stackTrace),
    @required TResult orElse(),
  });
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult data(_ResultData<T> value),
    @required TResult error(_ResultError<T> value),
  });
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult data(_ResultData<T> value),
    TResult error(_ResultError<T> value),
    @required TResult orElse(),
  });
}

/// @nodoc
abstract class $ResultCopyWith<T, $Res> {
  factory $ResultCopyWith(Result<T> value, $Res Function(Result<T>) then) =
      _$ResultCopyWithImpl<T, $Res>;
}

/// @nodoc
class _$ResultCopyWithImpl<T, $Res> implements $ResultCopyWith<T, $Res> {
  _$ResultCopyWithImpl(this._value, this._then);

  final Result<T> _value;
  // ignore: unused_field
  final $Res Function(Result<T>) _then;
}

/// @nodoc
abstract class _$ResultDataCopyWith<T, $Res> {
  factory _$ResultDataCopyWith(
          _ResultData<T> value, $Res Function(_ResultData<T>) then) =
      __$ResultDataCopyWithImpl<T, $Res>;
  $Res call({@nullable T value});
}

/// @nodoc
class __$ResultDataCopyWithImpl<T, $Res> extends _$ResultCopyWithImpl<T, $Res>
    implements _$ResultDataCopyWith<T, $Res> {
  __$ResultDataCopyWithImpl(
      _ResultData<T> _value, $Res Function(_ResultData<T>) _then)
      : super(_value, (v) => _then(v as _ResultData<T>));

  @override
  _ResultData<T> get _value => super._value as _ResultData<T>;

  @override
  $Res call({
    Object value = freezed,
  }) {
    return _then(_ResultData<T>(
      value == freezed ? _value.value : value as T,
    ));
  }
}

/// @nodoc
class _$_ResultData<T> extends _ResultData<T> {
  _$_ResultData(@nullable this.value) : super._();

  @override
  @nullable
  final T value;

  @override
  String toString() {
    return 'Result<$T>.data(value: $value)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _ResultData<T> &&
            (identical(other.value, value) ||
                const DeepCollectionEquality().equals(other.value, value)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^ const DeepCollectionEquality().hash(value);

  @JsonKey(ignore: true)
  @override
  _$ResultDataCopyWith<T, _ResultData<T>> get copyWith =>
      __$ResultDataCopyWithImpl<T, _ResultData<T>>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required TResult data(@nullable T value),
    @required TResult error(Object error, StackTrace stackTrace),
  }) {
    assert(data != null);
    assert(error != null);
    return data(value);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult data(@nullable T value),
    TResult error(Object error, StackTrace stackTrace),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (data != null) {
      return data(value);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult data(_ResultData<T> value),
    @required TResult error(_ResultError<T> value),
  }) {
    assert(data != null);
    assert(error != null);
    return data(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult data(_ResultData<T> value),
    TResult error(_ResultError<T> value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (data != null) {
      return data(this);
    }
    return orElse();
  }
}

abstract class _ResultData<T> extends Result<T> {
  _ResultData._() : super._();
  factory _ResultData(@nullable T value) = _$_ResultData<T>;

  @nullable
  T get value;
  @JsonKey(ignore: true)
  _$ResultDataCopyWith<T, _ResultData<T>> get copyWith;
}

/// @nodoc
abstract class _$ResultErrorCopyWith<T, $Res> {
  factory _$ResultErrorCopyWith(
          _ResultError<T> value, $Res Function(_ResultError<T>) then) =
      __$ResultErrorCopyWithImpl<T, $Res>;
  $Res call({Object error, StackTrace stackTrace});
}

/// @nodoc
class __$ResultErrorCopyWithImpl<T, $Res> extends _$ResultCopyWithImpl<T, $Res>
    implements _$ResultErrorCopyWith<T, $Res> {
  __$ResultErrorCopyWithImpl(
      _ResultError<T> _value, $Res Function(_ResultError<T>) _then)
      : super(_value, (v) => _then(v as _ResultError<T>));

  @override
  _ResultError<T> get _value => super._value as _ResultError<T>;

  @override
  $Res call({
    Object error = freezed,
    Object stackTrace = freezed,
  }) {
    return _then(_ResultError<T>(
      error == freezed ? _value.error : error,
      stackTrace == freezed ? _value.stackTrace : stackTrace as StackTrace,
    ));
  }
}

/// @nodoc
class _$_ResultError<T> extends _ResultError<T> {
  _$_ResultError(this.error, [this.stackTrace])
      : assert(error != null),
        super._();

  @override
  final Object error;
  @override
  final StackTrace stackTrace;

  @override
  String toString() {
    return 'Result<$T>.error(error: $error, stackTrace: $stackTrace)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _ResultError<T> &&
            (identical(other.error, error) ||
                const DeepCollectionEquality().equals(other.error, error)) &&
            (identical(other.stackTrace, stackTrace) ||
                const DeepCollectionEquality()
                    .equals(other.stackTrace, stackTrace)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(error) ^
      const DeepCollectionEquality().hash(stackTrace);

  @JsonKey(ignore: true)
  @override
  _$ResultErrorCopyWith<T, _ResultError<T>> get copyWith =>
      __$ResultErrorCopyWithImpl<T, _ResultError<T>>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required TResult data(@nullable T value),
    @required TResult error(Object error, StackTrace stackTrace),
  }) {
    assert(data != null);
    assert(error != null);
    return error(this.error, stackTrace);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult data(@nullable T value),
    TResult error(Object error, StackTrace stackTrace),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (error != null) {
      return error(this.error, stackTrace);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult data(_ResultData<T> value),
    @required TResult error(_ResultError<T> value),
  }) {
    assert(data != null);
    assert(error != null);
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult data(_ResultData<T> value),
    TResult error(_ResultError<T> value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class _ResultError<T> extends Result<T> {
  _ResultError._() : super._();
  factory _ResultError(Object error, [StackTrace stackTrace]) =
      _$_ResultError<T>;

  Object get error;
  StackTrace get stackTrace;
  @JsonKey(ignore: true)
  _$ResultErrorCopyWith<T, _ResultError<T>> get copyWith;
}
