import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../enum_deserializer.dart';

const Type boxConstraintsType = BoxConstraints;

Constraints deserializeConstraints(Map<String, Object> json) {
  // TODO(albertusangga): Support SliverConstraint
  if (json == null || json['type'] != boxConstraintsType.toString())
    return null;
  return BoxConstraints(
    minWidth: json['minWidth'],
    maxWidth: json['hasBoundedWidth'] ? json['maxWidth'] : double.infinity,
    minHeight: json['minHeight'],
    maxHeight: json['hasBoundedHeight'] ? json['maxHeight'] : double.infinity,
  );
}

/// TODO(albertusangga): Move this to [RemoteDiagnosticsNode] once dart:html app is removed
@immutable
class RenderFlexProperties {
  const RenderFlexProperties({
    this.direction,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.crossAxisAlignment,
    this.textDirection,
    this.verticalDirection,
    this.textBaseline,
  });

  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline textBaseline;

  static final directionDeserializer = EnumDeserializer<Axis>(Axis.values);
  static final mainAxisAlignmentDeserializer =
      EnumDeserializer<MainAxisAlignment>(MainAxisAlignment.values);
  static final mainAxisSizeDeserializer =
      EnumDeserializer<MainAxisSize>(MainAxisSize.values);
  static final crossAxisAlignmentDeserializer =
      EnumDeserializer<CrossAxisAlignment>(CrossAxisAlignment.values);
  static final textDirectionDeserializer =
      EnumDeserializer<TextDirection>(TextDirection.values);
  static final verticalDirectionDeserializer =
      EnumDeserializer<VerticalDirection>(VerticalDirection.values);
  static final textBaselineDeserializer =
      EnumDeserializer<TextBaseline>(TextBaseline.values);

  static RenderFlexProperties fromJson(Map<String, Object> renderObjectJson) {
    final List<dynamic> properties = renderObjectJson['properties'];
    // TODO(albertusangga) should we do some checking in the validity of the API contract here?
    final Map<String, Object> data = Map.fromEntries(
      properties.map(
        (property) => MapEntry<String, Object>(
          property['name'],
          property['description'],
        ),
      ),
    );

    return RenderFlexProperties(
      direction: directionDeserializer.deserialize(data['direction']),
      mainAxisAlignment:
          mainAxisAlignmentDeserializer.deserialize(data['mainAxisAlignment']),
      mainAxisSize: mainAxisSizeDeserializer.deserialize(data['mainAxisSize']),
      crossAxisAlignment: crossAxisAlignmentDeserializer
          .deserialize(data['crossAxisAlignment']),
      textDirection:
          textDirectionDeserializer.deserialize(data['textDirection']),
      verticalDirection:
          verticalDirectionDeserializer.deserialize(data['verticalDirection']),
      textBaseline: textBaselineDeserializer.deserialize(data['textBaseline']),
    );
  }

  Type get type => direction == Axis.horizontal ? Row : Column;
}
