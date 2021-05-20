// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies

part of 'instance_details.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

/// @nodoc
class _$PathToPropertyTearOff {
  const _$PathToPropertyTearOff();

// ignore: unused_element
  ListIndexPath listIndex(int index) {
    return ListIndexPath(
      index,
    );
  }

// ignore: unused_element
  MapKeyPath mapKey({@required @nullable String ref}) {
    return MapKeyPath(
      ref: ref,
    );
  }

// ignore: unused_element
  PropertyPath objectProperty(
      {@required String name,
      @required String ownerUri,
      @required String ownerName}) {
    return PropertyPath(
      name: name,
      ownerUri: ownerUri,
      ownerName: ownerName,
    );
  }
}

/// @nodoc
// ignore: unused_element
const $PathToProperty = _$PathToPropertyTearOff();

/// @nodoc
mixin _$PathToProperty {
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required TResult listIndex(int index),
    @required TResult mapKey(@nullable String ref),
    @required
        TResult objectProperty(String name, String ownerUri, String ownerName),
  });
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult listIndex(int index),
    TResult mapKey(@nullable String ref),
    TResult objectProperty(String name, String ownerUri, String ownerName),
    @required TResult orElse(),
  });
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult listIndex(ListIndexPath value),
    @required TResult mapKey(MapKeyPath value),
    @required TResult objectProperty(PropertyPath value),
  });
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult listIndex(ListIndexPath value),
    TResult mapKey(MapKeyPath value),
    TResult objectProperty(PropertyPath value),
    @required TResult orElse(),
  });
}

/// @nodoc
abstract class $PathToPropertyCopyWith<$Res> {
  factory $PathToPropertyCopyWith(
          PathToProperty value, $Res Function(PathToProperty) then) =
      _$PathToPropertyCopyWithImpl<$Res>;
}

/// @nodoc
class _$PathToPropertyCopyWithImpl<$Res>
    implements $PathToPropertyCopyWith<$Res> {
  _$PathToPropertyCopyWithImpl(this._value, this._then);

  final PathToProperty _value;
  // ignore: unused_field
  final $Res Function(PathToProperty) _then;
}

/// @nodoc
abstract class $ListIndexPathCopyWith<$Res> {
  factory $ListIndexPathCopyWith(
          ListIndexPath value, $Res Function(ListIndexPath) then) =
      _$ListIndexPathCopyWithImpl<$Res>;
  $Res call({int index});
}

/// @nodoc
class _$ListIndexPathCopyWithImpl<$Res>
    extends _$PathToPropertyCopyWithImpl<$Res>
    implements $ListIndexPathCopyWith<$Res> {
  _$ListIndexPathCopyWithImpl(
      ListIndexPath _value, $Res Function(ListIndexPath) _then)
      : super(_value, (v) => _then(v as ListIndexPath));

  @override
  ListIndexPath get _value => super._value as ListIndexPath;

  @override
  $Res call({
    Object index = freezed,
  }) {
    return _then(ListIndexPath(
      index == freezed ? _value.index : index as int,
    ));
  }
}

/// @nodoc
class _$ListIndexPath implements ListIndexPath {
  const _$ListIndexPath(this.index) : assert(index != null);

  @override
  final int index;

  @override
  String toString() {
    return 'PathToProperty.listIndex(index: $index)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is ListIndexPath &&
            (identical(other.index, index) ||
                const DeepCollectionEquality().equals(other.index, index)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^ const DeepCollectionEquality().hash(index);

  @JsonKey(ignore: true)
  @override
  $ListIndexPathCopyWith<ListIndexPath> get copyWith =>
      _$ListIndexPathCopyWithImpl<ListIndexPath>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required TResult listIndex(int index),
    @required TResult mapKey(@nullable String ref),
    @required
        TResult objectProperty(String name, String ownerUri, String ownerName),
  }) {
    assert(listIndex != null);
    assert(mapKey != null);
    assert(objectProperty != null);
    return listIndex(index);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult listIndex(int index),
    TResult mapKey(@nullable String ref),
    TResult objectProperty(String name, String ownerUri, String ownerName),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (listIndex != null) {
      return listIndex(index);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult listIndex(ListIndexPath value),
    @required TResult mapKey(MapKeyPath value),
    @required TResult objectProperty(PropertyPath value),
  }) {
    assert(listIndex != null);
    assert(mapKey != null);
    assert(objectProperty != null);
    return listIndex(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult listIndex(ListIndexPath value),
    TResult mapKey(MapKeyPath value),
    TResult objectProperty(PropertyPath value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (listIndex != null) {
      return listIndex(this);
    }
    return orElse();
  }
}

abstract class ListIndexPath implements PathToProperty {
  const factory ListIndexPath(int index) = _$ListIndexPath;

  int get index;
  @JsonKey(ignore: true)
  $ListIndexPathCopyWith<ListIndexPath> get copyWith;
}

/// @nodoc
abstract class $MapKeyPathCopyWith<$Res> {
  factory $MapKeyPathCopyWith(
          MapKeyPath value, $Res Function(MapKeyPath) then) =
      _$MapKeyPathCopyWithImpl<$Res>;
  $Res call({@nullable String ref});
}

/// @nodoc
class _$MapKeyPathCopyWithImpl<$Res> extends _$PathToPropertyCopyWithImpl<$Res>
    implements $MapKeyPathCopyWith<$Res> {
  _$MapKeyPathCopyWithImpl(MapKeyPath _value, $Res Function(MapKeyPath) _then)
      : super(_value, (v) => _then(v as MapKeyPath));

  @override
  MapKeyPath get _value => super._value as MapKeyPath;

  @override
  $Res call({
    Object ref = freezed,
  }) {
    return _then(MapKeyPath(
      ref: ref == freezed ? _value.ref : ref as String,
    ));
  }
}

/// @nodoc
class _$MapKeyPath implements MapKeyPath {
  const _$MapKeyPath({@required @nullable this.ref});

  @override
  @nullable
  final String ref;

  @override
  String toString() {
    return 'PathToProperty.mapKey(ref: $ref)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is MapKeyPath &&
            (identical(other.ref, ref) ||
                const DeepCollectionEquality().equals(other.ref, ref)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^ const DeepCollectionEquality().hash(ref);

  @JsonKey(ignore: true)
  @override
  $MapKeyPathCopyWith<MapKeyPath> get copyWith =>
      _$MapKeyPathCopyWithImpl<MapKeyPath>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required TResult listIndex(int index),
    @required TResult mapKey(@nullable String ref),
    @required
        TResult objectProperty(String name, String ownerUri, String ownerName),
  }) {
    assert(listIndex != null);
    assert(mapKey != null);
    assert(objectProperty != null);
    return mapKey(ref);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult listIndex(int index),
    TResult mapKey(@nullable String ref),
    TResult objectProperty(String name, String ownerUri, String ownerName),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (mapKey != null) {
      return mapKey(ref);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult listIndex(ListIndexPath value),
    @required TResult mapKey(MapKeyPath value),
    @required TResult objectProperty(PropertyPath value),
  }) {
    assert(listIndex != null);
    assert(mapKey != null);
    assert(objectProperty != null);
    return mapKey(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult listIndex(ListIndexPath value),
    TResult mapKey(MapKeyPath value),
    TResult objectProperty(PropertyPath value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (mapKey != null) {
      return mapKey(this);
    }
    return orElse();
  }
}

abstract class MapKeyPath implements PathToProperty {
  const factory MapKeyPath({@required @nullable String ref}) = _$MapKeyPath;

  @nullable
  String get ref;
  @JsonKey(ignore: true)
  $MapKeyPathCopyWith<MapKeyPath> get copyWith;
}

/// @nodoc
abstract class $PropertyPathCopyWith<$Res> {
  factory $PropertyPathCopyWith(
          PropertyPath value, $Res Function(PropertyPath) then) =
      _$PropertyPathCopyWithImpl<$Res>;
  $Res call({String name, String ownerUri, String ownerName});
}

/// @nodoc
class _$PropertyPathCopyWithImpl<$Res>
    extends _$PathToPropertyCopyWithImpl<$Res>
    implements $PropertyPathCopyWith<$Res> {
  _$PropertyPathCopyWithImpl(
      PropertyPath _value, $Res Function(PropertyPath) _then)
      : super(_value, (v) => _then(v as PropertyPath));

  @override
  PropertyPath get _value => super._value as PropertyPath;

  @override
  $Res call({
    Object name = freezed,
    Object ownerUri = freezed,
    Object ownerName = freezed,
  }) {
    return _then(PropertyPath(
      name: name == freezed ? _value.name : name as String,
      ownerUri: ownerUri == freezed ? _value.ownerUri : ownerUri as String,
      ownerName: ownerName == freezed ? _value.ownerName : ownerName as String,
    ));
  }
}

/// @nodoc
class _$PropertyPath implements PropertyPath {
  const _$PropertyPath(
      {@required this.name, @required this.ownerUri, @required this.ownerName})
      : assert(name != null),
        assert(ownerUri != null),
        assert(ownerName != null);

  @override
  final String name;
  @override

  /// Path to the class/mixin that defined this property
  final String ownerUri;
  @override

  /// Name of the class/mixin that defined this property
  final String ownerName;

  @override
  String toString() {
    return 'PathToProperty.objectProperty(name: $name, ownerUri: $ownerUri, ownerName: $ownerName)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is PropertyPath &&
            (identical(other.name, name) ||
                const DeepCollectionEquality().equals(other.name, name)) &&
            (identical(other.ownerUri, ownerUri) ||
                const DeepCollectionEquality()
                    .equals(other.ownerUri, ownerUri)) &&
            (identical(other.ownerName, ownerName) ||
                const DeepCollectionEquality()
                    .equals(other.ownerName, ownerName)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(name) ^
      const DeepCollectionEquality().hash(ownerUri) ^
      const DeepCollectionEquality().hash(ownerName);

  @JsonKey(ignore: true)
  @override
  $PropertyPathCopyWith<PropertyPath> get copyWith =>
      _$PropertyPathCopyWithImpl<PropertyPath>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required TResult listIndex(int index),
    @required TResult mapKey(@nullable String ref),
    @required
        TResult objectProperty(String name, String ownerUri, String ownerName),
  }) {
    assert(listIndex != null);
    assert(mapKey != null);
    assert(objectProperty != null);
    return objectProperty(name, ownerUri, ownerName);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult listIndex(int index),
    TResult mapKey(@nullable String ref),
    TResult objectProperty(String name, String ownerUri, String ownerName),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (objectProperty != null) {
      return objectProperty(name, ownerUri, ownerName);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult listIndex(ListIndexPath value),
    @required TResult mapKey(MapKeyPath value),
    @required TResult objectProperty(PropertyPath value),
  }) {
    assert(listIndex != null);
    assert(mapKey != null);
    assert(objectProperty != null);
    return objectProperty(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult listIndex(ListIndexPath value),
    TResult mapKey(MapKeyPath value),
    TResult objectProperty(PropertyPath value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (objectProperty != null) {
      return objectProperty(this);
    }
    return orElse();
  }
}

abstract class PropertyPath implements PathToProperty {
  const factory PropertyPath(
      {@required String name,
      @required String ownerUri,
      @required String ownerName}) = _$PropertyPath;

  String get name;

  /// Path to the class/mixin that defined this property
  String get ownerUri;

  /// Name of the class/mixin that defined this property
  String get ownerName;
  @JsonKey(ignore: true)
  $PropertyPathCopyWith<PropertyPath> get copyWith;
}

/// @nodoc
class _$ObjectFieldTearOff {
  const _$ObjectFieldTearOff();

// ignore: unused_element
  _ObjectField call(
      {@required String name,
      @required bool isFinal,
      @required String ownerName,
      @required String ownerUri,
      @required @nullable Result<InstanceRef> ref,
      @required EvalOnDartLibrary eval,
      @required bool isDefinedByDependency}) {
    return _ObjectField(
      name: name,
      isFinal: isFinal,
      ownerName: ownerName,
      ownerUri: ownerUri,
      ref: ref,
      eval: eval,
      isDefinedByDependency: isDefinedByDependency,
    );
  }
}

/// @nodoc
// ignore: unused_element
const $ObjectField = _$ObjectFieldTearOff();

/// @nodoc
mixin _$ObjectField {
  String get name;
  bool get isFinal;
  String get ownerName;
  String get ownerUri;
  @nullable
  Result<InstanceRef> get ref;

  /// An [EvalOnDartLibrary] that can access this field from the owner object
  EvalOnDartLibrary get eval;

  /// Whether this field was defined by the inspected app or by one of its dependencies
  ///
  /// This is used by the UI to hide variables that are not useful for the user.
  bool get isDefinedByDependency;

  @JsonKey(ignore: true)
  $ObjectFieldCopyWith<ObjectField> get copyWith;
}

/// @nodoc
abstract class $ObjectFieldCopyWith<$Res> {
  factory $ObjectFieldCopyWith(
          ObjectField value, $Res Function(ObjectField) then) =
      _$ObjectFieldCopyWithImpl<$Res>;
  $Res call(
      {String name,
      bool isFinal,
      String ownerName,
      String ownerUri,
      @nullable Result<InstanceRef> ref,
      EvalOnDartLibrary eval,
      bool isDefinedByDependency});

  $ResultCopyWith<InstanceRef, $Res> get ref;
}

/// @nodoc
class _$ObjectFieldCopyWithImpl<$Res> implements $ObjectFieldCopyWith<$Res> {
  _$ObjectFieldCopyWithImpl(this._value, this._then);

  final ObjectField _value;
  // ignore: unused_field
  final $Res Function(ObjectField) _then;

  @override
  $Res call({
    Object name = freezed,
    Object isFinal = freezed,
    Object ownerName = freezed,
    Object ownerUri = freezed,
    Object ref = freezed,
    Object eval = freezed,
    Object isDefinedByDependency = freezed,
  }) {
    return _then(_value.copyWith(
      name: name == freezed ? _value.name : name as String,
      isFinal: isFinal == freezed ? _value.isFinal : isFinal as bool,
      ownerName: ownerName == freezed ? _value.ownerName : ownerName as String,
      ownerUri: ownerUri == freezed ? _value.ownerUri : ownerUri as String,
      ref: ref == freezed ? _value.ref : ref as Result<InstanceRef>,
      eval: eval == freezed ? _value.eval : eval as EvalOnDartLibrary,
      isDefinedByDependency: isDefinedByDependency == freezed
          ? _value.isDefinedByDependency
          : isDefinedByDependency as bool,
    ));
  }

  @override
  $ResultCopyWith<InstanceRef, $Res> get ref {
    if (_value.ref == null) {
      return null;
    }
    return $ResultCopyWith<InstanceRef, $Res>(_value.ref, (value) {
      return _then(_value.copyWith(ref: value));
    });
  }
}

/// @nodoc
abstract class _$ObjectFieldCopyWith<$Res>
    implements $ObjectFieldCopyWith<$Res> {
  factory _$ObjectFieldCopyWith(
          _ObjectField value, $Res Function(_ObjectField) then) =
      __$ObjectFieldCopyWithImpl<$Res>;
  @override
  $Res call(
      {String name,
      bool isFinal,
      String ownerName,
      String ownerUri,
      @nullable Result<InstanceRef> ref,
      EvalOnDartLibrary eval,
      bool isDefinedByDependency});

  @override
  $ResultCopyWith<InstanceRef, $Res> get ref;
}

/// @nodoc
class __$ObjectFieldCopyWithImpl<$Res> extends _$ObjectFieldCopyWithImpl<$Res>
    implements _$ObjectFieldCopyWith<$Res> {
  __$ObjectFieldCopyWithImpl(
      _ObjectField _value, $Res Function(_ObjectField) _then)
      : super(_value, (v) => _then(v as _ObjectField));

  @override
  _ObjectField get _value => super._value as _ObjectField;

  @override
  $Res call({
    Object name = freezed,
    Object isFinal = freezed,
    Object ownerName = freezed,
    Object ownerUri = freezed,
    Object ref = freezed,
    Object eval = freezed,
    Object isDefinedByDependency = freezed,
  }) {
    return _then(_ObjectField(
      name: name == freezed ? _value.name : name as String,
      isFinal: isFinal == freezed ? _value.isFinal : isFinal as bool,
      ownerName: ownerName == freezed ? _value.ownerName : ownerName as String,
      ownerUri: ownerUri == freezed ? _value.ownerUri : ownerUri as String,
      ref: ref == freezed ? _value.ref : ref as Result<InstanceRef>,
      eval: eval == freezed ? _value.eval : eval as EvalOnDartLibrary,
      isDefinedByDependency: isDefinedByDependency == freezed
          ? _value.isDefinedByDependency
          : isDefinedByDependency as bool,
    ));
  }
}

/// @nodoc
class _$_ObjectField extends _ObjectField {
  _$_ObjectField(
      {@required this.name,
      @required this.isFinal,
      @required this.ownerName,
      @required this.ownerUri,
      @required @nullable this.ref,
      @required this.eval,
      @required this.isDefinedByDependency})
      : assert(name != null),
        assert(isFinal != null),
        assert(ownerName != null),
        assert(ownerUri != null),
        assert(eval != null),
        assert(isDefinedByDependency != null),
        super._();

  @override
  final String name;
  @override
  final bool isFinal;
  @override
  final String ownerName;
  @override
  final String ownerUri;
  @override
  @nullable
  final Result<InstanceRef> ref;
  @override

  /// An [EvalOnDartLibrary] that can access this field from the owner object
  final EvalOnDartLibrary eval;
  @override

  /// Whether this field was defined by the inspected app or by one of its dependencies
  ///
  /// This is used by the UI to hide variables that are not useful for the user.
  final bool isDefinedByDependency;

  @override
  String toString() {
    return 'ObjectField(name: $name, isFinal: $isFinal, ownerName: $ownerName, ownerUri: $ownerUri, ref: $ref, eval: $eval, isDefinedByDependency: $isDefinedByDependency)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _ObjectField &&
            (identical(other.name, name) ||
                const DeepCollectionEquality().equals(other.name, name)) &&
            (identical(other.isFinal, isFinal) ||
                const DeepCollectionEquality()
                    .equals(other.isFinal, isFinal)) &&
            (identical(other.ownerName, ownerName) ||
                const DeepCollectionEquality()
                    .equals(other.ownerName, ownerName)) &&
            (identical(other.ownerUri, ownerUri) ||
                const DeepCollectionEquality()
                    .equals(other.ownerUri, ownerUri)) &&
            (identical(other.ref, ref) ||
                const DeepCollectionEquality().equals(other.ref, ref)) &&
            (identical(other.eval, eval) ||
                const DeepCollectionEquality().equals(other.eval, eval)) &&
            (identical(other.isDefinedByDependency, isDefinedByDependency) ||
                const DeepCollectionEquality().equals(
                    other.isDefinedByDependency, isDefinedByDependency)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(name) ^
      const DeepCollectionEquality().hash(isFinal) ^
      const DeepCollectionEquality().hash(ownerName) ^
      const DeepCollectionEquality().hash(ownerUri) ^
      const DeepCollectionEquality().hash(ref) ^
      const DeepCollectionEquality().hash(eval) ^
      const DeepCollectionEquality().hash(isDefinedByDependency);

  @JsonKey(ignore: true)
  @override
  _$ObjectFieldCopyWith<_ObjectField> get copyWith =>
      __$ObjectFieldCopyWithImpl<_ObjectField>(this, _$identity);
}

abstract class _ObjectField extends ObjectField {
  _ObjectField._() : super._();
  factory _ObjectField(
      {@required String name,
      @required bool isFinal,
      @required String ownerName,
      @required String ownerUri,
      @required @nullable Result<InstanceRef> ref,
      @required EvalOnDartLibrary eval,
      @required bool isDefinedByDependency}) = _$_ObjectField;

  @override
  String get name;
  @override
  bool get isFinal;
  @override
  String get ownerName;
  @override
  String get ownerUri;
  @override
  @nullable
  Result<InstanceRef> get ref;
  @override

  /// An [EvalOnDartLibrary] that can access this field from the owner object
  EvalOnDartLibrary get eval;
  @override

  /// Whether this field was defined by the inspected app or by one of its dependencies
  ///
  /// This is used by the UI to hide variables that are not useful for the user.
  bool get isDefinedByDependency;
  @override
  @JsonKey(ignore: true)
  _$ObjectFieldCopyWith<_ObjectField> get copyWith;
}

/// @nodoc
class _$InstanceDetailsTearOff {
  const _$InstanceDetailsTearOff();

// ignore: unused_element
  NullInstance nill(
      {String instanceRefId,
      @required @nullable Future<void> Function(String) setter}) {
    return NullInstance(
      instanceRefId: instanceRefId,
      setter: setter,
    );
  }

// ignore: unused_element
  BoolInstance boolean(String displayString,
      {@required String instanceRefId,
      @required @nullable Future<void> Function(String) setter}) {
    return BoolInstance(
      displayString,
      instanceRefId: instanceRefId,
      setter: setter,
    );
  }

// ignore: unused_element
  NumInstance number(String displayString,
      {@required String instanceRefId,
      @required @nullable Future<void> Function(String) setter}) {
    return NumInstance(
      displayString,
      instanceRefId: instanceRefId,
      setter: setter,
    );
  }

// ignore: unused_element
  StringInstance string(String displayString,
      {@required String instanceRefId,
      @required @nullable Future<void> Function(String) setter}) {
    return StringInstance(
      displayString,
      instanceRefId: instanceRefId,
      setter: setter,
    );
  }

// ignore: unused_element
  MapInstance map(List<InstanceDetails> keys,
      {@required int hash,
      @required String instanceRefId,
      @required @nullable Future<void> Function(String) setter}) {
    return MapInstance(
      keys,
      hash: hash,
      instanceRefId: instanceRefId,
      setter: setter,
    );
  }

// ignore: unused_element
  ListInstance list(
      {@required @nullable int length,
      @required int hash,
      @required String instanceRefId,
      @required @nullable Future<void> Function(String) setter}) {
    return ListInstance(
      length: length,
      hash: hash,
      instanceRefId: instanceRefId,
      setter: setter,
    );
  }

// ignore: unused_element
  ObjectInstance object(List<ObjectField> fields,
      {@required String type,
      @required int hash,
      @required String instanceRefId,
      @required @nullable Future<void> Function(String) setter,
      @required EvalOnDartLibrary evalForInstance}) {
    return ObjectInstance(
      fields,
      type: type,
      hash: hash,
      instanceRefId: instanceRefId,
      setter: setter,
      evalForInstance: evalForInstance,
    );
  }

// ignore: unused_element
  EnumInstance enumeration(
      {@required String type,
      @required String value,
      @required @nullable Future<void> Function(String) setter,
      @required String instanceRefId}) {
    return EnumInstance(
      type: type,
      value: value,
      setter: setter,
      instanceRefId: instanceRefId,
    );
  }
}

/// @nodoc
// ignore: unused_element
const $InstanceDetails = _$InstanceDetailsTearOff();

/// @nodoc
mixin _$InstanceDetails {
  String get instanceRefId;
  @nullable
  Future<void> Function(String) get setter;

  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  });
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  });
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  });
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  });

  @JsonKey(ignore: true)
  $InstanceDetailsCopyWith<InstanceDetails> get copyWith;
}

/// @nodoc
abstract class $InstanceDetailsCopyWith<$Res> {
  factory $InstanceDetailsCopyWith(
          InstanceDetails value, $Res Function(InstanceDetails) then) =
      _$InstanceDetailsCopyWithImpl<$Res>;
  $Res call(
      {String instanceRefId, @nullable Future<void> Function(String) setter});
}

/// @nodoc
class _$InstanceDetailsCopyWithImpl<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  _$InstanceDetailsCopyWithImpl(this._value, this._then);

  final InstanceDetails _value;
  // ignore: unused_field
  final $Res Function(InstanceDetails) _then;

  @override
  $Res call({
    Object instanceRefId = freezed,
    Object setter = freezed,
  }) {
    return _then(_value.copyWith(
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
    ));
  }
}

/// @nodoc
abstract class $NullInstanceCopyWith<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  factory $NullInstanceCopyWith(
          NullInstance value, $Res Function(NullInstance) then) =
      _$NullInstanceCopyWithImpl<$Res>;
  @override
  $Res call(
      {String instanceRefId, @nullable Future<void> Function(String) setter});
}

/// @nodoc
class _$NullInstanceCopyWithImpl<$Res>
    extends _$InstanceDetailsCopyWithImpl<$Res>
    implements $NullInstanceCopyWith<$Res> {
  _$NullInstanceCopyWithImpl(
      NullInstance _value, $Res Function(NullInstance) _then)
      : super(_value, (v) => _then(v as NullInstance));

  @override
  NullInstance get _value => super._value as NullInstance;

  @override
  $Res call({
    Object instanceRefId = freezed,
    Object setter = freezed,
  }) {
    return _then(NullInstance(
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
    ));
  }
}

/// @nodoc
class _$NullInstance extends NullInstance {
  _$NullInstance({this.instanceRefId, @required @nullable this.setter})
      : assert(instanceRefId == null),
        super._();

  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString() {
    return 'InstanceDetails.nill(instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is NullInstance &&
            (identical(other.instanceRefId, instanceRefId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceRefId, instanceRefId)) &&
            (identical(other.setter, setter) ||
                const DeepCollectionEquality().equals(other.setter, setter)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(instanceRefId) ^
      const DeepCollectionEquality().hash(setter);

  @JsonKey(ignore: true)
  @override
  $NullInstanceCopyWith<NullInstance> get copyWith =>
      _$NullInstanceCopyWithImpl<NullInstance>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return nill(instanceRefId, setter);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (nill != null) {
      return nill(instanceRefId, setter);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return nill(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (nill != null) {
      return nill(this);
    }
    return orElse();
  }
}

abstract class NullInstance extends InstanceDetails {
  NullInstance._() : super._();
  factory NullInstance(
          {String instanceRefId,
          @required @nullable Future<void> Function(String) setter}) =
      _$NullInstance;

  @override
  String get instanceRefId;
  @override
  @nullable
  Future<void> Function(String) get setter;
  @override
  @JsonKey(ignore: true)
  $NullInstanceCopyWith<NullInstance> get copyWith;
}

/// @nodoc
abstract class $BoolInstanceCopyWith<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  factory $BoolInstanceCopyWith(
          BoolInstance value, $Res Function(BoolInstance) then) =
      _$BoolInstanceCopyWithImpl<$Res>;
  @override
  $Res call(
      {String displayString,
      String instanceRefId,
      @nullable Future<void> Function(String) setter});
}

/// @nodoc
class _$BoolInstanceCopyWithImpl<$Res>
    extends _$InstanceDetailsCopyWithImpl<$Res>
    implements $BoolInstanceCopyWith<$Res> {
  _$BoolInstanceCopyWithImpl(
      BoolInstance _value, $Res Function(BoolInstance) _then)
      : super(_value, (v) => _then(v as BoolInstance));

  @override
  BoolInstance get _value => super._value as BoolInstance;

  @override
  $Res call({
    Object displayString = freezed,
    Object instanceRefId = freezed,
    Object setter = freezed,
  }) {
    return _then(BoolInstance(
      displayString == freezed ? _value.displayString : displayString as String,
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
    ));
  }
}

/// @nodoc
class _$BoolInstance extends BoolInstance {
  _$BoolInstance(this.displayString,
      {@required this.instanceRefId, @required @nullable this.setter})
      : assert(displayString != null),
        assert(instanceRefId != null),
        super._();

  @override
  final String displayString;
  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString() {
    return 'InstanceDetails.boolean(displayString: $displayString, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is BoolInstance &&
            (identical(other.displayString, displayString) ||
                const DeepCollectionEquality()
                    .equals(other.displayString, displayString)) &&
            (identical(other.instanceRefId, instanceRefId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceRefId, instanceRefId)) &&
            (identical(other.setter, setter) ||
                const DeepCollectionEquality().equals(other.setter, setter)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(displayString) ^
      const DeepCollectionEquality().hash(instanceRefId) ^
      const DeepCollectionEquality().hash(setter);

  @JsonKey(ignore: true)
  @override
  $BoolInstanceCopyWith<BoolInstance> get copyWith =>
      _$BoolInstanceCopyWithImpl<BoolInstance>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return boolean(displayString, instanceRefId, setter);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (boolean != null) {
      return boolean(displayString, instanceRefId, setter);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return boolean(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (boolean != null) {
      return boolean(this);
    }
    return orElse();
  }
}

abstract class BoolInstance extends InstanceDetails {
  BoolInstance._() : super._();
  factory BoolInstance(String displayString,
          {@required String instanceRefId,
          @required @nullable Future<void> Function(String) setter}) =
      _$BoolInstance;

  String get displayString;
  @override
  String get instanceRefId;
  @override
  @nullable
  Future<void> Function(String) get setter;
  @override
  @JsonKey(ignore: true)
  $BoolInstanceCopyWith<BoolInstance> get copyWith;
}

/// @nodoc
abstract class $NumInstanceCopyWith<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  factory $NumInstanceCopyWith(
          NumInstance value, $Res Function(NumInstance) then) =
      _$NumInstanceCopyWithImpl<$Res>;
  @override
  $Res call(
      {String displayString,
      String instanceRefId,
      @nullable Future<void> Function(String) setter});
}

/// @nodoc
class _$NumInstanceCopyWithImpl<$Res>
    extends _$InstanceDetailsCopyWithImpl<$Res>
    implements $NumInstanceCopyWith<$Res> {
  _$NumInstanceCopyWithImpl(
      NumInstance _value, $Res Function(NumInstance) _then)
      : super(_value, (v) => _then(v as NumInstance));

  @override
  NumInstance get _value => super._value as NumInstance;

  @override
  $Res call({
    Object displayString = freezed,
    Object instanceRefId = freezed,
    Object setter = freezed,
  }) {
    return _then(NumInstance(
      displayString == freezed ? _value.displayString : displayString as String,
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
    ));
  }
}

/// @nodoc
class _$NumInstance extends NumInstance {
  _$NumInstance(this.displayString,
      {@required this.instanceRefId, @required @nullable this.setter})
      : assert(displayString != null),
        assert(instanceRefId != null),
        super._();

  @override
  final String displayString;
  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString() {
    return 'InstanceDetails.number(displayString: $displayString, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is NumInstance &&
            (identical(other.displayString, displayString) ||
                const DeepCollectionEquality()
                    .equals(other.displayString, displayString)) &&
            (identical(other.instanceRefId, instanceRefId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceRefId, instanceRefId)) &&
            (identical(other.setter, setter) ||
                const DeepCollectionEquality().equals(other.setter, setter)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(displayString) ^
      const DeepCollectionEquality().hash(instanceRefId) ^
      const DeepCollectionEquality().hash(setter);

  @JsonKey(ignore: true)
  @override
  $NumInstanceCopyWith<NumInstance> get copyWith =>
      _$NumInstanceCopyWithImpl<NumInstance>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return number(displayString, instanceRefId, setter);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (number != null) {
      return number(displayString, instanceRefId, setter);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return number(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (number != null) {
      return number(this);
    }
    return orElse();
  }
}

abstract class NumInstance extends InstanceDetails {
  NumInstance._() : super._();
  factory NumInstance(String displayString,
          {@required String instanceRefId,
          @required @nullable Future<void> Function(String) setter}) =
      _$NumInstance;

  String get displayString;
  @override
  String get instanceRefId;
  @override
  @nullable
  Future<void> Function(String) get setter;
  @override
  @JsonKey(ignore: true)
  $NumInstanceCopyWith<NumInstance> get copyWith;
}

/// @nodoc
abstract class $StringInstanceCopyWith<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  factory $StringInstanceCopyWith(
          StringInstance value, $Res Function(StringInstance) then) =
      _$StringInstanceCopyWithImpl<$Res>;
  @override
  $Res call(
      {String displayString,
      String instanceRefId,
      @nullable Future<void> Function(String) setter});
}

/// @nodoc
class _$StringInstanceCopyWithImpl<$Res>
    extends _$InstanceDetailsCopyWithImpl<$Res>
    implements $StringInstanceCopyWith<$Res> {
  _$StringInstanceCopyWithImpl(
      StringInstance _value, $Res Function(StringInstance) _then)
      : super(_value, (v) => _then(v as StringInstance));

  @override
  StringInstance get _value => super._value as StringInstance;

  @override
  $Res call({
    Object displayString = freezed,
    Object instanceRefId = freezed,
    Object setter = freezed,
  }) {
    return _then(StringInstance(
      displayString == freezed ? _value.displayString : displayString as String,
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
    ));
  }
}

/// @nodoc
class _$StringInstance extends StringInstance {
  _$StringInstance(this.displayString,
      {@required this.instanceRefId, @required @nullable this.setter})
      : assert(displayString != null),
        assert(instanceRefId != null),
        super._();

  @override
  final String displayString;
  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString() {
    return 'InstanceDetails.string(displayString: $displayString, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is StringInstance &&
            (identical(other.displayString, displayString) ||
                const DeepCollectionEquality()
                    .equals(other.displayString, displayString)) &&
            (identical(other.instanceRefId, instanceRefId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceRefId, instanceRefId)) &&
            (identical(other.setter, setter) ||
                const DeepCollectionEquality().equals(other.setter, setter)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(displayString) ^
      const DeepCollectionEquality().hash(instanceRefId) ^
      const DeepCollectionEquality().hash(setter);

  @JsonKey(ignore: true)
  @override
  $StringInstanceCopyWith<StringInstance> get copyWith =>
      _$StringInstanceCopyWithImpl<StringInstance>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return string(displayString, instanceRefId, setter);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (string != null) {
      return string(displayString, instanceRefId, setter);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return string(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (string != null) {
      return string(this);
    }
    return orElse();
  }
}

abstract class StringInstance extends InstanceDetails {
  StringInstance._() : super._();
  factory StringInstance(String displayString,
          {@required String instanceRefId,
          @required @nullable Future<void> Function(String) setter}) =
      _$StringInstance;

  String get displayString;
  @override
  String get instanceRefId;
  @override
  @nullable
  Future<void> Function(String) get setter;
  @override
  @JsonKey(ignore: true)
  $StringInstanceCopyWith<StringInstance> get copyWith;
}

/// @nodoc
abstract class $MapInstanceCopyWith<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  factory $MapInstanceCopyWith(
          MapInstance value, $Res Function(MapInstance) then) =
      _$MapInstanceCopyWithImpl<$Res>;
  @override
  $Res call(
      {List<InstanceDetails> keys,
      int hash,
      String instanceRefId,
      @nullable Future<void> Function(String) setter});
}

/// @nodoc
class _$MapInstanceCopyWithImpl<$Res>
    extends _$InstanceDetailsCopyWithImpl<$Res>
    implements $MapInstanceCopyWith<$Res> {
  _$MapInstanceCopyWithImpl(
      MapInstance _value, $Res Function(MapInstance) _then)
      : super(_value, (v) => _then(v as MapInstance));

  @override
  MapInstance get _value => super._value as MapInstance;

  @override
  $Res call({
    Object keys = freezed,
    Object hash = freezed,
    Object instanceRefId = freezed,
    Object setter = freezed,
  }) {
    return _then(MapInstance(
      keys == freezed ? _value.keys : keys as List<InstanceDetails>,
      hash: hash == freezed ? _value.hash : hash as int,
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
    ));
  }
}

/// @nodoc
class _$MapInstance extends MapInstance {
  _$MapInstance(this.keys,
      {@required this.hash,
      @required this.instanceRefId,
      @required @nullable this.setter})
      : assert(keys != null),
        assert(hash != null),
        assert(instanceRefId != null),
        super._();

  @override
  final List<InstanceDetails> keys;
  @override
  final int hash;
  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString() {
    return 'InstanceDetails.map(keys: $keys, hash: $hash, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is MapInstance &&
            (identical(other.keys, keys) ||
                const DeepCollectionEquality().equals(other.keys, keys)) &&
            (identical(other.hash, hash) ||
                const DeepCollectionEquality().equals(other.hash, hash)) &&
            (identical(other.instanceRefId, instanceRefId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceRefId, instanceRefId)) &&
            (identical(other.setter, setter) ||
                const DeepCollectionEquality().equals(other.setter, setter)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(keys) ^
      const DeepCollectionEquality().hash(hash) ^
      const DeepCollectionEquality().hash(instanceRefId) ^
      const DeepCollectionEquality().hash(setter);

  @JsonKey(ignore: true)
  @override
  $MapInstanceCopyWith<MapInstance> get copyWith =>
      _$MapInstanceCopyWithImpl<MapInstance>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return map(keys, hash, instanceRefId, setter);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (map != null) {
      return map(keys, hash, instanceRefId, setter);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return map(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (map != null) {
      return map(this);
    }
    return orElse();
  }
}

abstract class MapInstance extends InstanceDetails {
  MapInstance._() : super._();
  factory MapInstance(List<InstanceDetails> keys,
          {@required int hash,
          @required String instanceRefId,
          @required @nullable Future<void> Function(String) setter}) =
      _$MapInstance;

  List<InstanceDetails> get keys;
  int get hash;
  @override
  String get instanceRefId;
  @override
  @nullable
  Future<void> Function(String) get setter;
  @override
  @JsonKey(ignore: true)
  $MapInstanceCopyWith<MapInstance> get copyWith;
}

/// @nodoc
abstract class $ListInstanceCopyWith<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  factory $ListInstanceCopyWith(
          ListInstance value, $Res Function(ListInstance) then) =
      _$ListInstanceCopyWithImpl<$Res>;
  @override
  $Res call(
      {@nullable int length,
      int hash,
      String instanceRefId,
      @nullable Future<void> Function(String) setter});
}

/// @nodoc
class _$ListInstanceCopyWithImpl<$Res>
    extends _$InstanceDetailsCopyWithImpl<$Res>
    implements $ListInstanceCopyWith<$Res> {
  _$ListInstanceCopyWithImpl(
      ListInstance _value, $Res Function(ListInstance) _then)
      : super(_value, (v) => _then(v as ListInstance));

  @override
  ListInstance get _value => super._value as ListInstance;

  @override
  $Res call({
    Object length = freezed,
    Object hash = freezed,
    Object instanceRefId = freezed,
    Object setter = freezed,
  }) {
    return _then(ListInstance(
      length: length == freezed ? _value.length : length as int,
      hash: hash == freezed ? _value.hash : hash as int,
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
    ));
  }
}

/// @nodoc
class _$ListInstance extends ListInstance {
  _$ListInstance(
      {@required @nullable this.length,
      @required this.hash,
      @required this.instanceRefId,
      @required @nullable this.setter})
      : assert(hash != null),
        assert(instanceRefId != null),
        super._();

  @override
  @nullable
  final int length;
  @override
  final int hash;
  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString() {
    return 'InstanceDetails.list(length: $length, hash: $hash, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is ListInstance &&
            (identical(other.length, length) ||
                const DeepCollectionEquality().equals(other.length, length)) &&
            (identical(other.hash, hash) ||
                const DeepCollectionEquality().equals(other.hash, hash)) &&
            (identical(other.instanceRefId, instanceRefId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceRefId, instanceRefId)) &&
            (identical(other.setter, setter) ||
                const DeepCollectionEquality().equals(other.setter, setter)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(length) ^
      const DeepCollectionEquality().hash(hash) ^
      const DeepCollectionEquality().hash(instanceRefId) ^
      const DeepCollectionEquality().hash(setter);

  @JsonKey(ignore: true)
  @override
  $ListInstanceCopyWith<ListInstance> get copyWith =>
      _$ListInstanceCopyWithImpl<ListInstance>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return list(length, hash, instanceRefId, setter);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (list != null) {
      return list(length, hash, instanceRefId, setter);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return list(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (list != null) {
      return list(this);
    }
    return orElse();
  }
}

abstract class ListInstance extends InstanceDetails {
  ListInstance._() : super._();
  factory ListInstance(
          {@required @nullable int length,
          @required int hash,
          @required String instanceRefId,
          @required @nullable Future<void> Function(String) setter}) =
      _$ListInstance;

  @nullable
  int get length;
  int get hash;
  @override
  String get instanceRefId;
  @override
  @nullable
  Future<void> Function(String) get setter;
  @override
  @JsonKey(ignore: true)
  $ListInstanceCopyWith<ListInstance> get copyWith;
}

/// @nodoc
abstract class $ObjectInstanceCopyWith<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  factory $ObjectInstanceCopyWith(
          ObjectInstance value, $Res Function(ObjectInstance) then) =
      _$ObjectInstanceCopyWithImpl<$Res>;
  @override
  $Res call(
      {List<ObjectField> fields,
      String type,
      int hash,
      String instanceRefId,
      @nullable Future<void> Function(String) setter,
      EvalOnDartLibrary evalForInstance});
}

/// @nodoc
class _$ObjectInstanceCopyWithImpl<$Res>
    extends _$InstanceDetailsCopyWithImpl<$Res>
    implements $ObjectInstanceCopyWith<$Res> {
  _$ObjectInstanceCopyWithImpl(
      ObjectInstance _value, $Res Function(ObjectInstance) _then)
      : super(_value, (v) => _then(v as ObjectInstance));

  @override
  ObjectInstance get _value => super._value as ObjectInstance;

  @override
  $Res call({
    Object fields = freezed,
    Object type = freezed,
    Object hash = freezed,
    Object instanceRefId = freezed,
    Object setter = freezed,
    Object evalForInstance = freezed,
  }) {
    return _then(ObjectInstance(
      fields == freezed ? _value.fields : fields as List<ObjectField>,
      type: type == freezed ? _value.type : type as String,
      hash: hash == freezed ? _value.hash : hash as int,
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
      evalForInstance: evalForInstance == freezed
          ? _value.evalForInstance
          : evalForInstance as EvalOnDartLibrary,
    ));
  }
}

/// @nodoc
class _$ObjectInstance extends ObjectInstance {
  _$ObjectInstance(this.fields,
      {@required this.type,
      @required this.hash,
      @required this.instanceRefId,
      @required @nullable this.setter,
      @required this.evalForInstance})
      : assert(fields != null),
        assert(type != null),
        assert(hash != null),
        assert(instanceRefId != null),
        assert(evalForInstance != null),
        super._();

  @override
  final List<ObjectField> fields;
  @override
  final String type;
  @override
  final int hash;
  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;
  @override

  /// An [EvalOnDartLibrary] associated with the library of this object
  ///
  /// This allows to edit private properties.
  final EvalOnDartLibrary evalForInstance;

  @override
  String toString() {
    return 'InstanceDetails.object(fields: $fields, type: $type, hash: $hash, instanceRefId: $instanceRefId, setter: $setter, evalForInstance: $evalForInstance)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is ObjectInstance &&
            (identical(other.fields, fields) ||
                const DeepCollectionEquality().equals(other.fields, fields)) &&
            (identical(other.type, type) ||
                const DeepCollectionEquality().equals(other.type, type)) &&
            (identical(other.hash, hash) ||
                const DeepCollectionEquality().equals(other.hash, hash)) &&
            (identical(other.instanceRefId, instanceRefId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceRefId, instanceRefId)) &&
            (identical(other.setter, setter) ||
                const DeepCollectionEquality().equals(other.setter, setter)) &&
            (identical(other.evalForInstance, evalForInstance) ||
                const DeepCollectionEquality()
                    .equals(other.evalForInstance, evalForInstance)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(fields) ^
      const DeepCollectionEquality().hash(type) ^
      const DeepCollectionEquality().hash(hash) ^
      const DeepCollectionEquality().hash(instanceRefId) ^
      const DeepCollectionEquality().hash(setter) ^
      const DeepCollectionEquality().hash(evalForInstance);

  @JsonKey(ignore: true)
  @override
  $ObjectInstanceCopyWith<ObjectInstance> get copyWith =>
      _$ObjectInstanceCopyWithImpl<ObjectInstance>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return object(fields, type, hash, instanceRefId, setter, evalForInstance);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (object != null) {
      return object(fields, type, hash, instanceRefId, setter, evalForInstance);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return object(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (object != null) {
      return object(this);
    }
    return orElse();
  }
}

abstract class ObjectInstance extends InstanceDetails {
  ObjectInstance._() : super._();
  factory ObjectInstance(List<ObjectField> fields,
      {@required String type,
      @required int hash,
      @required String instanceRefId,
      @required @nullable Future<void> Function(String) setter,
      @required EvalOnDartLibrary evalForInstance}) = _$ObjectInstance;

  List<ObjectField> get fields;
  String get type;
  int get hash;
  @override
  String get instanceRefId;
  @override
  @nullable
  Future<void> Function(String) get setter;

  /// An [EvalOnDartLibrary] associated with the library of this object
  ///
  /// This allows to edit private properties.
  EvalOnDartLibrary get evalForInstance;
  @override
  @JsonKey(ignore: true)
  $ObjectInstanceCopyWith<ObjectInstance> get copyWith;
}

/// @nodoc
abstract class $EnumInstanceCopyWith<$Res>
    implements $InstanceDetailsCopyWith<$Res> {
  factory $EnumInstanceCopyWith(
          EnumInstance value, $Res Function(EnumInstance) then) =
      _$EnumInstanceCopyWithImpl<$Res>;
  @override
  $Res call(
      {String type,
      String value,
      @nullable Future<void> Function(String) setter,
      String instanceRefId});
}

/// @nodoc
class _$EnumInstanceCopyWithImpl<$Res>
    extends _$InstanceDetailsCopyWithImpl<$Res>
    implements $EnumInstanceCopyWith<$Res> {
  _$EnumInstanceCopyWithImpl(
      EnumInstance _value, $Res Function(EnumInstance) _then)
      : super(_value, (v) => _then(v as EnumInstance));

  @override
  EnumInstance get _value => super._value as EnumInstance;

  @override
  $Res call({
    Object type = freezed,
    Object value = freezed,
    Object setter = freezed,
    Object instanceRefId = freezed,
  }) {
    return _then(EnumInstance(
      type: type == freezed ? _value.type : type as String,
      value: value == freezed ? _value.value : value as String,
      setter: setter == freezed
          ? _value.setter
          : setter as Future<void> Function(String),
      instanceRefId: instanceRefId == freezed
          ? _value.instanceRefId
          : instanceRefId as String,
    ));
  }
}

/// @nodoc
class _$EnumInstance extends EnumInstance {
  _$EnumInstance(
      {@required this.type,
      @required this.value,
      @required @nullable this.setter,
      @required this.instanceRefId})
      : assert(type != null),
        assert(value != null),
        assert(instanceRefId != null),
        super._();

  @override
  final String type;
  @override
  final String value;
  @override
  @nullable
  final Future<void> Function(String) setter;
  @override
  final String instanceRefId;

  @override
  String toString() {
    return 'InstanceDetails.enumeration(type: $type, value: $value, setter: $setter, instanceRefId: $instanceRefId)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is EnumInstance &&
            (identical(other.type, type) ||
                const DeepCollectionEquality().equals(other.type, type)) &&
            (identical(other.value, value) ||
                const DeepCollectionEquality().equals(other.value, value)) &&
            (identical(other.setter, setter) ||
                const DeepCollectionEquality().equals(other.setter, setter)) &&
            (identical(other.instanceRefId, instanceRefId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceRefId, instanceRefId)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(type) ^
      const DeepCollectionEquality().hash(value) ^
      const DeepCollectionEquality().hash(setter) ^
      const DeepCollectionEquality().hash(instanceRefId);

  @JsonKey(ignore: true)
  @override
  $EnumInstanceCopyWith<EnumInstance> get copyWith =>
      _$EnumInstanceCopyWithImpl<EnumInstance>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult nill(String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult boolean(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult number(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult string(String displayString, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, int hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<ObjectField> fields,
            String type,
            int hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter,
            EvalOnDartLibrary evalForInstance),
    @required
        TResult enumeration(
            String type,
            String value,
            @nullable Future<void> Function(String) setter,
            String instanceRefId),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return enumeration(type, value, setter, instanceRefId);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult nill(
        String instanceRefId, @nullable Future<void> Function(String) setter),
    TResult boolean(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult number(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult string(String displayString, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult map(List<InstanceDetails> keys, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, int hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<ObjectField> fields,
        String type,
        int hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (enumeration != null) {
      return enumeration(type, value, setter, instanceRefId);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult nill(NullInstance value),
    @required TResult boolean(BoolInstance value),
    @required TResult number(NumInstance value),
    @required TResult string(StringInstance value),
    @required TResult map(MapInstance value),
    @required TResult list(ListInstance value),
    @required TResult object(ObjectInstance value),
    @required TResult enumeration(EnumInstance value),
  }) {
    assert(nill != null);
    assert(boolean != null);
    assert(number != null);
    assert(string != null);
    assert(map != null);
    assert(list != null);
    assert(object != null);
    assert(enumeration != null);
    return enumeration(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult nill(NullInstance value),
    TResult boolean(BoolInstance value),
    TResult number(NumInstance value),
    TResult string(StringInstance value),
    TResult map(MapInstance value),
    TResult list(ListInstance value),
    TResult object(ObjectInstance value),
    TResult enumeration(EnumInstance value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (enumeration != null) {
      return enumeration(this);
    }
    return orElse();
  }
}

abstract class EnumInstance extends InstanceDetails {
  EnumInstance._() : super._();
  factory EnumInstance(
      {@required String type,
      @required String value,
      @required @nullable Future<void> Function(String) setter,
      @required String instanceRefId}) = _$EnumInstance;

  String get type;
  String get value;
  @override
  @nullable
  Future<void> Function(String) get setter;
  @override
  String get instanceRefId;
  @override
  @JsonKey(ignore: true)
  $EnumInstanceCopyWith<EnumInstance> get copyWith;
}

/// @nodoc
class _$InstancePathTearOff {
  const _$InstancePathTearOff();

// ignore: unused_element
  _InstancePathFromInstanceId fromInstanceId(@nullable String instanceId,
      {List<PathToProperty> pathToProperty = const []}) {
    return _InstancePathFromInstanceId(
      instanceId,
      pathToProperty: pathToProperty,
    );
  }

// ignore: unused_element
  _InstancePathFromProviderId fromProviderId(String providerId,
      {List<PathToProperty> pathToProperty = const []}) {
    return _InstancePathFromProviderId(
      providerId,
      pathToProperty: pathToProperty,
    );
  }
}

/// @nodoc
// ignore: unused_element
const $InstancePath = _$InstancePathTearOff();

/// @nodoc
mixin _$InstancePath {
  List<PathToProperty> get pathToProperty;

  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult fromInstanceId(
            @nullable String instanceId, List<PathToProperty> pathToProperty),
    @required
        TResult fromProviderId(
            String providerId, List<PathToProperty> pathToProperty),
  });
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult fromInstanceId(
        @nullable String instanceId, List<PathToProperty> pathToProperty),
    TResult fromProviderId(
        String providerId, List<PathToProperty> pathToProperty),
    @required TResult orElse(),
  });
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult fromInstanceId(_InstancePathFromInstanceId value),
    @required TResult fromProviderId(_InstancePathFromProviderId value),
  });
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult fromInstanceId(_InstancePathFromInstanceId value),
    TResult fromProviderId(_InstancePathFromProviderId value),
    @required TResult orElse(),
  });

  @JsonKey(ignore: true)
  $InstancePathCopyWith<InstancePath> get copyWith;
}

/// @nodoc
abstract class $InstancePathCopyWith<$Res> {
  factory $InstancePathCopyWith(
          InstancePath value, $Res Function(InstancePath) then) =
      _$InstancePathCopyWithImpl<$Res>;
  $Res call({List<PathToProperty> pathToProperty});
}

/// @nodoc
class _$InstancePathCopyWithImpl<$Res> implements $InstancePathCopyWith<$Res> {
  _$InstancePathCopyWithImpl(this._value, this._then);

  final InstancePath _value;
  // ignore: unused_field
  final $Res Function(InstancePath) _then;

  @override
  $Res call({
    Object pathToProperty = freezed,
  }) {
    return _then(_value.copyWith(
      pathToProperty: pathToProperty == freezed
          ? _value.pathToProperty
          : pathToProperty as List<PathToProperty>,
    ));
  }
}

/// @nodoc
abstract class _$InstancePathFromInstanceIdCopyWith<$Res>
    implements $InstancePathCopyWith<$Res> {
  factory _$InstancePathFromInstanceIdCopyWith(
          _InstancePathFromInstanceId value,
          $Res Function(_InstancePathFromInstanceId) then) =
      __$InstancePathFromInstanceIdCopyWithImpl<$Res>;
  @override
  $Res call({@nullable String instanceId, List<PathToProperty> pathToProperty});
}

/// @nodoc
class __$InstancePathFromInstanceIdCopyWithImpl<$Res>
    extends _$InstancePathCopyWithImpl<$Res>
    implements _$InstancePathFromInstanceIdCopyWith<$Res> {
  __$InstancePathFromInstanceIdCopyWithImpl(_InstancePathFromInstanceId _value,
      $Res Function(_InstancePathFromInstanceId) _then)
      : super(_value, (v) => _then(v as _InstancePathFromInstanceId));

  @override
  _InstancePathFromInstanceId get _value =>
      super._value as _InstancePathFromInstanceId;

  @override
  $Res call({
    Object instanceId = freezed,
    Object pathToProperty = freezed,
  }) {
    return _then(_InstancePathFromInstanceId(
      instanceId == freezed ? _value.instanceId : instanceId as String,
      pathToProperty: pathToProperty == freezed
          ? _value.pathToProperty
          : pathToProperty as List<PathToProperty>,
    ));
  }
}

/// @nodoc
class _$_InstancePathFromInstanceId extends _InstancePathFromInstanceId {
  const _$_InstancePathFromInstanceId(@nullable this.instanceId,
      {this.pathToProperty = const []})
      : assert(pathToProperty != null),
        super._();

  @override
  @nullable
  final String instanceId;
  @JsonKey(defaultValue: const [])
  @override
  final List<PathToProperty> pathToProperty;

  @override
  String toString() {
    return 'InstancePath.fromInstanceId(instanceId: $instanceId, pathToProperty: $pathToProperty)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _InstancePathFromInstanceId &&
            (identical(other.instanceId, instanceId) ||
                const DeepCollectionEquality()
                    .equals(other.instanceId, instanceId)) &&
            (identical(other.pathToProperty, pathToProperty) ||
                const DeepCollectionEquality()
                    .equals(other.pathToProperty, pathToProperty)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(instanceId) ^
      const DeepCollectionEquality().hash(pathToProperty);

  @JsonKey(ignore: true)
  @override
  _$InstancePathFromInstanceIdCopyWith<_InstancePathFromInstanceId>
      get copyWith => __$InstancePathFromInstanceIdCopyWithImpl<
          _InstancePathFromInstanceId>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult fromInstanceId(
            @nullable String instanceId, List<PathToProperty> pathToProperty),
    @required
        TResult fromProviderId(
            String providerId, List<PathToProperty> pathToProperty),
  }) {
    assert(fromInstanceId != null);
    assert(fromProviderId != null);
    return fromInstanceId(instanceId, pathToProperty);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult fromInstanceId(
        @nullable String instanceId, List<PathToProperty> pathToProperty),
    TResult fromProviderId(
        String providerId, List<PathToProperty> pathToProperty),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (fromInstanceId != null) {
      return fromInstanceId(instanceId, pathToProperty);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult fromInstanceId(_InstancePathFromInstanceId value),
    @required TResult fromProviderId(_InstancePathFromProviderId value),
  }) {
    assert(fromInstanceId != null);
    assert(fromProviderId != null);
    return fromInstanceId(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult fromInstanceId(_InstancePathFromInstanceId value),
    TResult fromProviderId(_InstancePathFromProviderId value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (fromInstanceId != null) {
      return fromInstanceId(this);
    }
    return orElse();
  }
}

abstract class _InstancePathFromInstanceId extends InstancePath {
  const _InstancePathFromInstanceId._() : super._();
  const factory _InstancePathFromInstanceId(@nullable String instanceId,
      {List<PathToProperty> pathToProperty}) = _$_InstancePathFromInstanceId;

  @nullable
  String get instanceId;
  @override
  List<PathToProperty> get pathToProperty;
  @override
  @JsonKey(ignore: true)
  _$InstancePathFromInstanceIdCopyWith<_InstancePathFromInstanceId>
      get copyWith;
}

/// @nodoc
abstract class _$InstancePathFromProviderIdCopyWith<$Res>
    implements $InstancePathCopyWith<$Res> {
  factory _$InstancePathFromProviderIdCopyWith(
          _InstancePathFromProviderId value,
          $Res Function(_InstancePathFromProviderId) then) =
      __$InstancePathFromProviderIdCopyWithImpl<$Res>;
  @override
  $Res call({String providerId, List<PathToProperty> pathToProperty});
}

/// @nodoc
class __$InstancePathFromProviderIdCopyWithImpl<$Res>
    extends _$InstancePathCopyWithImpl<$Res>
    implements _$InstancePathFromProviderIdCopyWith<$Res> {
  __$InstancePathFromProviderIdCopyWithImpl(_InstancePathFromProviderId _value,
      $Res Function(_InstancePathFromProviderId) _then)
      : super(_value, (v) => _then(v as _InstancePathFromProviderId));

  @override
  _InstancePathFromProviderId get _value =>
      super._value as _InstancePathFromProviderId;

  @override
  $Res call({
    Object providerId = freezed,
    Object pathToProperty = freezed,
  }) {
    return _then(_InstancePathFromProviderId(
      providerId == freezed ? _value.providerId : providerId as String,
      pathToProperty: pathToProperty == freezed
          ? _value.pathToProperty
          : pathToProperty as List<PathToProperty>,
    ));
  }
}

/// @nodoc
class _$_InstancePathFromProviderId extends _InstancePathFromProviderId {
  const _$_InstancePathFromProviderId(this.providerId,
      {this.pathToProperty = const []})
      : assert(providerId != null),
        assert(pathToProperty != null),
        super._();

  @override
  final String providerId;
  @JsonKey(defaultValue: const [])
  @override
  final List<PathToProperty> pathToProperty;

  @override
  String toString() {
    return 'InstancePath.fromProviderId(providerId: $providerId, pathToProperty: $pathToProperty)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is _InstancePathFromProviderId &&
            (identical(other.providerId, providerId) ||
                const DeepCollectionEquality()
                    .equals(other.providerId, providerId)) &&
            (identical(other.pathToProperty, pathToProperty) ||
                const DeepCollectionEquality()
                    .equals(other.pathToProperty, pathToProperty)));
  }

  @override
  int get hashCode =>
      runtimeType.hashCode ^
      const DeepCollectionEquality().hash(providerId) ^
      const DeepCollectionEquality().hash(pathToProperty);

  @JsonKey(ignore: true)
  @override
  _$InstancePathFromProviderIdCopyWith<_InstancePathFromProviderId>
      get copyWith => __$InstancePathFromProviderIdCopyWithImpl<
          _InstancePathFromProviderId>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object>({
    @required
        TResult fromInstanceId(
            @nullable String instanceId, List<PathToProperty> pathToProperty),
    @required
        TResult fromProviderId(
            String providerId, List<PathToProperty> pathToProperty),
  }) {
    assert(fromInstanceId != null);
    assert(fromProviderId != null);
    return fromProviderId(providerId, pathToProperty);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object>({
    TResult fromInstanceId(
        @nullable String instanceId, List<PathToProperty> pathToProperty),
    TResult fromProviderId(
        String providerId, List<PathToProperty> pathToProperty),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (fromProviderId != null) {
      return fromProviderId(providerId, pathToProperty);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object>({
    @required TResult fromInstanceId(_InstancePathFromInstanceId value),
    @required TResult fromProviderId(_InstancePathFromProviderId value),
  }) {
    assert(fromInstanceId != null);
    assert(fromProviderId != null);
    return fromProviderId(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object>({
    TResult fromInstanceId(_InstancePathFromInstanceId value),
    TResult fromProviderId(_InstancePathFromProviderId value),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (fromProviderId != null) {
      return fromProviderId(this);
    }
    return orElse();
  }
}

abstract class _InstancePathFromProviderId extends InstancePath {
  const _InstancePathFromProviderId._() : super._();
  const factory _InstancePathFromProviderId(String providerId,
      {List<PathToProperty> pathToProperty}) = _$_InstancePathFromProviderId;

  String get providerId;
  @override
  List<PathToProperty> get pathToProperty;
  @override
  @JsonKey(ignore: true)
  _$InstancePathFromProviderIdCopyWith<_InstancePathFromProviderId>
      get copyWith;
}
