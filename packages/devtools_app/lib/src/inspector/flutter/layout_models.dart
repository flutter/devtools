import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// TODO(albertusangga): Move this to [RemoteDiagnosticsNode] once dart:html app is removed
@immutable
class FlexProperties {
  const FlexProperties({
    this.direction,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.crossAxisAlignment,
    this.textDirection,
    this.verticalDirection,
    this.textBaseline,
    this.size,
  });

  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline textBaseline;
  final Size size;

  // TODO(albertusangga): Research better way to serialzie & deserialize enum value in Dart
  static Object enumFromString(
    List<Object> enumValues,
    String enumToStringValue,
  ) {
    return enumValues.firstWhere(
      (enumValue) => enumValue.toString() == enumToStringValue,
      orElse: () => null,
    );
  }

  /// Deserialize Flex properties from DiagnosticsNode to actual object
  static FlexProperties fromJson(Map<String, Object> data) {
    final Map<String, dynamic> sizeJson = data['size'];
    final Size size = sizeJson == null ||
            sizeJson['height'] == null ||
            sizeJson['width'] == null
        ? null
        : Size(sizeJson['width'], sizeJson['height']);
    return FlexProperties(
      direction: enumFromString(Axis.values, data['direction']),
      mainAxisAlignment:
          enumFromString(MainAxisAlignment.values, data['mainAxisAlignment']),
      mainAxisSize: enumFromString(MainAxisSize.values, data['mainAxisSize']),
      crossAxisAlignment:
          enumFromString(CrossAxisAlignment.values, data['crossAxisAlignment']),
      textDirection:
          enumFromString(TextDirection.values, data['textDirection']),
      verticalDirection:
          enumFromString(VerticalDirection.values, data['verticalDirection']),
      textBaseline: enumFromString(TextBaseline.values, data['textBaseline']),
      size: size,
    );
  }

  Type get type => direction == Axis.horizontal ? Row : Column;
}
