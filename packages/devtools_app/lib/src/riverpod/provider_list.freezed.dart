// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies

part of 'provider_list.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

/// @nodoc
class _$ProviderNodeTearOff {
  const _$ProviderNodeTearOff();

// ignore: unused_element
  _ProviderNode call(
      {@required String containerId,
      @required String providerId,
      @required String type,
      @required @nullable String paramDisplayString}) {
    return _ProviderNode(
      containerId: containerId,
      providerId: providerId,
      type: type,
      paramDisplayString: paramDisplayString,
    );
  }
}

/// @nodoc
// ignore: unused_element
const $ProviderNode = _$ProviderNodeTearOff();

/// @nodoc
mixin _$ProviderNode {
  String get containerId;
  String get providerId;
  String get type;
  @nullable
  String get paramDisplayString;

  @JsonKey(ignore: true)
  $ProviderNodeCopyWith<ProviderNode> get copyWith;
}

/// @nodoc
abstract class $ProviderNodeCopyWith<$Res> {
  factory $ProviderNodeCopyWith(
          ProviderNode value, $Res Function(ProviderNode) then) =
      _$ProviderNodeCopyWithImpl<$Res>;
  $Res call(
      {String containerId,
      String providerId,
      String type,
      @nullable String paramDisplayString});
}

/// @nodoc
class _$ProviderNodeCopyWithImpl<$Res> implements $ProviderNodeCopyWith<$Res> {
  _$ProviderNodeCopyWithImpl(this._value, this._then);

  final ProviderNode _value;
  // ignore: unused_field
  final $Res Function(ProviderNode) _then;

  @override
  $Res call({
    Object containerId = freezed,
    Object providerId = freezed,
    Object type = freezed,
    Object paramDisplayString = freezed,
  }) {
    return _then(_value.copyWith(
      containerId:
          containerId == freezed ? _value.containerId : containerId as String,
      providerId:
          providerId == freezed ? _value.providerId : providerId as String,
      type: type == freezed ? _value.type : type as String,
      paramDisplayString: paramDisplayString == freezed
          ? _value.paramDisplayString
          : paramDisplayString as String,
    ));
  }
}

/// @nodoc
abstract class _$ProviderNodeCopyWith<$Res>
    implements $ProviderNodeCopyWith<$Res> {
  factory _$ProviderNodeCopyWith(
          _ProviderNode value, $Res Function(_ProviderNode) then) =
      __$ProviderNodeCopyWithImpl<$Res>;
  @override
  $Res call(
      {String containerId,
      String providerId,
      String type,
      @nullable String paramDisplayString});
}

/// @nodoc
class __$ProviderNodeCopyWithImpl<$Res> extends _$ProviderNodeCopyWithImpl<$Res>
    implements _$ProviderNodeCopyWith<$Res> {
  __$ProviderNodeCopyWithImpl(
      _ProviderNode _value, $Res Function(_ProviderNode) _then)
      : super(_value, (v) => _then(v as _ProviderNode));

  @override
  _ProviderNode get _value => super._value as _ProviderNode;

  @override
  $Res call({
    Object containerId = freezed,
    Object providerId = freezed,
    Object type = freezed,
    Object paramDisplayString = freezed,
  }) {
    return _then(_ProviderNode(
      containerId:
          containerId == freezed ? _value.containerId : containerId as String,
      providerId:
          providerId == freezed ? _value.providerId : providerId as String,
      type: type == freezed ? _value.type : type as String,
      paramDisplayString: paramDisplayString == freezed
          ? _value.paramDisplayString
          : paramDisplayString as String,
    ));
  }
}

/// @nodoc
class _$_ProviderNode implements _ProviderNode {
  const _$_ProviderNode(
      {@required this.containerId,
      @required this.providerId,
      @required this.type,
      @required @nullable this.paramDisplayString})
      : assert(containerId != null),
        assert(providerId != null),
        assert(type != null);

  @override
  final String containerId;
  @override
  final String providerId;
  @override
  final String type;
  @override
  @nullable
  final String paramDisplayString;

  @override
  String toString() {
    return 'ProviderNode(containerId: $containerId, providerId: $providerId, type: $type, paramDisplayString: $paramDisplayString)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _ProviderNode &&
            (identical(other.containerId, containerId) ||
                const DeepCollectionEquality()
                    .equals(other.containerId, containerId)) &&
            (identical(other.providerId, providerId) ||
                const DeepCollectionEquality()
                    .equals(other.providerId, providerId)) &&
            (identical(other.type, type) ||
                const DeepCollectionEquality().equals(other.type, type)) &&
            (identical(other.paramDisplayString, paramDisplayString) ||
                const DeepCollectionEquality()
                    .equals(other.paramDisplayString, paramDisplayString)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(containerId) ^
      const DeepCollectionEquality().hash(providerId) ^
      const DeepCollectionEquality().hash(type) ^
      const DeepCollectionEquality().hash(paramDisplayString);

  @JsonKey(ignore: true)
  @override
  _$ProviderNodeCopyWith<_ProviderNode> get copyWith =>
      __$ProviderNodeCopyWithImpl<_ProviderNode>(this, _$identity);
}

abstract class _ProviderNode implements ProviderNode {
  const factory _ProviderNode(
      {@required String containerId,
      @required String providerId,
      @required String type,
      @required @nullable String paramDisplayString}) = _$_ProviderNode;

  @override
  String get containerId;
  @override
  String get providerId;
  @override
  String get type;
  @override
  @nullable
  String get paramDisplayString;
  @override
  @JsonKey(ignore: true)
  _$ProviderNodeCopyWith<_ProviderNode> get copyWith;
}
