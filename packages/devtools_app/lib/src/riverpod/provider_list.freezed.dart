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
      @required String providerRefId,
      @required String type}) {
    return _ProviderNode(
      containerId: containerId,
      providerRefId: providerRefId,
      type: type,
    );
  }
}

/// @nodoc
// ignore: unused_element
const $ProviderNode = _$ProviderNodeTearOff();

/// @nodoc
mixin _$ProviderNode {
  String get containerId;
  String get providerRefId;
  String get type;

  @JsonKey(ignore: true)
  $ProviderNodeCopyWith<ProviderNode> get copyWith;
}

/// @nodoc
abstract class $ProviderNodeCopyWith<$Res> {
  factory $ProviderNodeCopyWith(
          ProviderNode value, $Res Function(ProviderNode) then) =
      _$ProviderNodeCopyWithImpl<$Res>;
  $Res call({String containerId, String providerRefId, String type});
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
    Object providerRefId = freezed,
    Object type = freezed,
  }) {
    return _then(_value.copyWith(
      containerId:
          containerId == freezed ? _value.containerId : containerId as String,
      providerRefId: providerRefId == freezed
          ? _value.providerRefId
          : providerRefId as String,
      type: type == freezed ? _value.type : type as String,
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
  $Res call({String containerId, String providerRefId, String type});
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
    Object providerRefId = freezed,
    Object type = freezed,
  }) {
    return _then(_ProviderNode(
      containerId:
          containerId == freezed ? _value.containerId : containerId as String,
      providerRefId: providerRefId == freezed
          ? _value.providerRefId
          : providerRefId as String,
      type: type == freezed ? _value.type : type as String,
    ));
  }
}

/// @nodoc
class _$_ProviderNode implements _ProviderNode {
  const _$_ProviderNode(
      {@required this.containerId,
      @required this.providerRefId,
      @required this.type})
      : assert(containerId != null),
        assert(providerRefId != null),
        assert(type != null);

  @override
  final String containerId;
  @override
  final String providerRefId;
  @override
  final String type;

  @override
  String toString() {
    return 'ProviderNode(containerId: $containerId, providerRefId: $providerRefId, type: $type)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _ProviderNode &&
            (identical(other.containerId, containerId) ||
                const DeepCollectionEquality()
                    .equals(other.containerId, containerId)) &&
            (identical(other.providerRefId, providerRefId) ||
                const DeepCollectionEquality()
                    .equals(other.providerRefId, providerRefId)) &&
            (identical(other.type, type) ||
                const DeepCollectionEquality().equals(other.type, type)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(containerId) ^
      const DeepCollectionEquality().hash(providerRefId) ^
      const DeepCollectionEquality().hash(type);

  @JsonKey(ignore: true)
  @override
  _$ProviderNodeCopyWith<_ProviderNode> get copyWith =>
      __$ProviderNodeCopyWithImpl<_ProviderNode>(this, _$identity);
}

abstract class _ProviderNode implements ProviderNode {
  const factory _ProviderNode(
      {@required String containerId,
      @required String providerRefId,
      @required String type}) = _$_ProviderNode;

  @override
  String get containerId;
  @override
  String get providerRefId;
  @override
  String get type;
  @override
  @JsonKey(ignore: true)
  _$ProviderNodeCopyWith<_ProviderNode> get copyWith;
}
