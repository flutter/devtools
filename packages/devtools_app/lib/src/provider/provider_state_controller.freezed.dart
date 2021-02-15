// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies

part of 'provider_state_controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

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
      {@required String hash,
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
      @required String hash,
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
  ObjectInstance object(List<String> fieldsName,
      {@required String type,
      @required String hash,
      @required String instanceRefId,
      @required @nullable Future<void> Function(String) setter,
      @required EvalOnDartLibrary evalForInstance}) {
    return ObjectInstance(
      fieldsName,
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
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
class _$NullInstance extends NullInstance with DiagnosticableTreeMixin {
  _$NullInstance({this.instanceRefId, @required @nullable this.setter})
      : assert(instanceRefId == null),
        super._();

  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstanceDetails.nill(instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstanceDetails.nill'))
      ..add(DiagnosticsProperty('instanceRefId', instanceRefId))
      ..add(DiagnosticsProperty('setter', setter));
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
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
class _$BoolInstance extends BoolInstance with DiagnosticableTreeMixin {
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
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstanceDetails.boolean(displayString: $displayString, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstanceDetails.boolean'))
      ..add(DiagnosticsProperty('displayString', displayString))
      ..add(DiagnosticsProperty('instanceRefId', instanceRefId))
      ..add(DiagnosticsProperty('setter', setter));
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
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
class _$NumInstance extends NumInstance with DiagnosticableTreeMixin {
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
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstanceDetails.number(displayString: $displayString, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstanceDetails.number'))
      ..add(DiagnosticsProperty('displayString', displayString))
      ..add(DiagnosticsProperty('instanceRefId', instanceRefId))
      ..add(DiagnosticsProperty('setter', setter));
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
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
class _$StringInstance extends StringInstance with DiagnosticableTreeMixin {
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
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstanceDetails.string(displayString: $displayString, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstanceDetails.string'))
      ..add(DiagnosticsProperty('displayString', displayString))
      ..add(DiagnosticsProperty('instanceRefId', instanceRefId))
      ..add(DiagnosticsProperty('setter', setter));
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
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
      String hash,
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
      hash: hash == freezed ? _value.hash : hash as String,
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
class _$MapInstance extends MapInstance with DiagnosticableTreeMixin {
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
  final String hash;
  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstanceDetails.map(keys: $keys, hash: $hash, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstanceDetails.map'))
      ..add(DiagnosticsProperty('keys', keys))
      ..add(DiagnosticsProperty('hash', hash))
      ..add(DiagnosticsProperty('instanceRefId', instanceRefId))
      ..add(DiagnosticsProperty('setter', setter));
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
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
          {@required String hash,
          @required String instanceRefId,
          @required @nullable Future<void> Function(String) setter}) =
      _$MapInstance;

  List<InstanceDetails> get keys;
  String get hash;
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
      String hash,
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
      hash: hash == freezed ? _value.hash : hash as String,
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
class _$ListInstance extends ListInstance with DiagnosticableTreeMixin {
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
  final String hash;
  @override
  final String instanceRefId;
  @override
  @nullable
  final Future<void> Function(String) setter;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstanceDetails.list(length: $length, hash: $hash, instanceRefId: $instanceRefId, setter: $setter)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstanceDetails.list'))
      ..add(DiagnosticsProperty('length', length))
      ..add(DiagnosticsProperty('hash', hash))
      ..add(DiagnosticsProperty('instanceRefId', instanceRefId))
      ..add(DiagnosticsProperty('setter', setter));
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
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
          @required String hash,
          @required String instanceRefId,
          @required @nullable Future<void> Function(String) setter}) =
      _$ListInstance;

  @nullable
  int get length;
  String get hash;
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
      {List<String> fieldsName,
      String type,
      String hash,
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
    Object fieldsName = freezed,
    Object type = freezed,
    Object hash = freezed,
    Object instanceRefId = freezed,
    Object setter = freezed,
    Object evalForInstance = freezed,
  }) {
    return _then(ObjectInstance(
      fieldsName == freezed ? _value.fieldsName : fieldsName as List<String>,
      type: type == freezed ? _value.type : type as String,
      hash: hash == freezed ? _value.hash : hash as String,
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
class _$ObjectInstance extends ObjectInstance with DiagnosticableTreeMixin {
  _$ObjectInstance(this.fieldsName,
      {@required this.type,
      @required this.hash,
      @required this.instanceRefId,
      @required @nullable this.setter,
      @required this.evalForInstance})
      : assert(fieldsName != null),
        assert(type != null),
        assert(hash != null),
        assert(instanceRefId != null),
        assert(evalForInstance != null),
        super._();

  @override
  final List<String> fieldsName;
  @override
  final String type;
  @override
  final String hash;
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
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstanceDetails.object(fieldsName: $fieldsName, type: $type, hash: $hash, instanceRefId: $instanceRefId, setter: $setter, evalForInstance: $evalForInstance)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstanceDetails.object'))
      ..add(DiagnosticsProperty('fieldsName', fieldsName))
      ..add(DiagnosticsProperty('type', type))
      ..add(DiagnosticsProperty('hash', hash))
      ..add(DiagnosticsProperty('instanceRefId', instanceRefId))
      ..add(DiagnosticsProperty('setter', setter))
      ..add(DiagnosticsProperty('evalForInstance', evalForInstance));
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other is ObjectInstance &&
            (identical(other.fieldsName, fieldsName) ||
                const DeepCollectionEquality()
                    .equals(other.fieldsName, fieldsName)) &&
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
      const DeepCollectionEquality().hash(fieldsName) ^
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    return object(
        fieldsName, type, hash, instanceRefId, setter, evalForInstance);
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
        String instanceRefId,
        @nullable Future<void> Function(String) setter,
        EvalOnDartLibrary evalForInstance),
    TResult enumeration(String type, String value,
        @nullable Future<void> Function(String) setter, String instanceRefId),
    @required TResult orElse(),
  }) {
    assert(orElse != null);
    if (object != null) {
      return object(
          fieldsName, type, hash, instanceRefId, setter, evalForInstance);
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
  factory ObjectInstance(List<String> fieldsName,
      {@required String type,
      @required String hash,
      @required String instanceRefId,
      @required @nullable Future<void> Function(String) setter,
      @required EvalOnDartLibrary evalForInstance}) = _$ObjectInstance;

  List<String> get fieldsName;
  String get type;
  String get hash;
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
class _$EnumInstance extends EnumInstance with DiagnosticableTreeMixin {
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
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'InstanceDetails.enumeration(type: $type, value: $value, setter: $setter, instanceRefId: $instanceRefId)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'InstanceDetails.enumeration'))
      ..add(DiagnosticsProperty('type', type))
      ..add(DiagnosticsProperty('value', value))
      ..add(DiagnosticsProperty('setter', setter))
      ..add(DiagnosticsProperty('instanceRefId', instanceRefId));
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
        TResult map(
            List<InstanceDetails> keys,
            String hash,
            String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult list(@nullable int length, String hash, String instanceRefId,
            @nullable Future<void> Function(String) setter),
    @required
        TResult object(
            List<String> fieldsName,
            String type,
            String hash,
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
    TResult map(List<InstanceDetails> keys, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult list(@nullable int length, String hash, String instanceRefId,
        @nullable Future<void> Function(String) setter),
    TResult object(
        List<String> fieldsName,
        String type,
        String hash,
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
