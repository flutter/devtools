// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/enum_utils.dart';
import '../primitives/utils.dart';
import '../ui/icons.dart';
import 'object_group_api.dart';
import 'primitives/instance_ref.dart';
import 'primitives/source_location.dart';

final diagnosticLevelUtils = EnumUtils<DiagnosticLevel>(DiagnosticLevel.values);

final treeStyleUtils =
    EnumUtils<DiagnosticsTreeStyle>(DiagnosticsTreeStyle.values);

/// Defines diagnostics data for a [value].
///
/// [RemoteDiagnosticsNode] provides a high quality multi-line string dump via
/// [toStringDeep]. The core members are the [name], [toDescription],
/// [getProperties], [value], and [getChildren]. All other members exist
/// typically to provide hints for how [toStringDeep] and debugging tools should
/// format output.
///
/// See also:
///
/// * DiagnosticsNode class defined at https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/foundation/diagnostics.dart
/// The difference is the class hierarchy is collapsed here as in
/// package:flutter the subclasses exist more to simplify creation
/// of Diagnostics than because the class hierarchy of Diagnostics is
/// important. If you need to determine the exact Diagnostic class on the
/// Dart side you can use the value of type. The raw Dart object value is
/// also available via the getValue() method.
class RemoteDiagnosticsNode extends DiagnosticableTree {
  RemoteDiagnosticsNode(
    this.json,
    this.objectGroupApi,
    this.isProperty,
    this.parent,
  );

  /// Stores the [TextStyle] that was used when building the description.
  ///
  /// When not set, then the description has not been built yet.
  /// This style is used when approximating the length of the
  /// [DiagnosticsNodeDescription], to ensure we are approximating the content
  /// area using the right style.
  TextStyle? descriptionTextStyleFromBuild;

  static final CustomIconMaker iconMaker = CustomIconMaker();

  static BoxConstraints deserializeConstraints(Map<String, Object?> json) {
    return BoxConstraints(
      minWidth: double.parse(json['minWidth'] as String? ?? '0.0'),
      maxWidth: double.parse(json['maxWidth'] as String? ?? 'Infinity'),
      minHeight: double.parse(json['minHeight'] as String? ?? '0.0'),
      maxHeight: double.parse(json['maxHeight'] as String? ?? 'Infinity'),
    );
  }

  static BoxParentData deserializeParentData(Map<String, Object?> json) {
    return BoxParentData()
      ..offset = Offset(
        double.parse(json['offsetX'] as String? ?? '0.0'),
        double.parse(json['offsetY'] as String? ?? '0.0'),
      );
  }

  static Size deserializeSize(Map<String, Object> json) {
    return Size(
      double.parse(json['width'] as String),
      double.parse(json['height'] as String),
    );
  }

  static FlexFit deserializeFlexFit(String? flexFit) {
    if (flexFit == 'tight') return FlexFit.tight;
    return FlexFit.loose;
  }

  /// This node's parent (if it's been set).
  RemoteDiagnosticsNode? parent;

  Future<String>? propertyDocFuture;

  List<RemoteDiagnosticsNode>? cachedProperties;

  /// Service used to retrieve more detailed information about the value of
  /// the property and its children and properties.
  final InspectorObjectGroupApi<RemoteDiagnosticsNode>? objectGroupApi;

  /// JSON describing the diagnostic node.
  final Map<String, Object?> json;

  Future<Map<String, InstanceRef>?>? _valueProperties;

  final bool isProperty;

  // TODO(albertusangga): Refactor to cleaner/more robust solution
  bool get isFlex => ['Row', 'Column', 'Flex'].contains(widgetRuntimeType);

  bool get isBox => json['isBox'] == true;

  int? get flexFactor => json['flexFactor'] as int?;

  FlexFit get flexFit => deserializeFlexFit(json['flexFit'] as String?);

  RemoteDiagnosticsNode? get renderObject {
    if (_renderObject != null) return _renderObject;
    final data = json['renderObject'];
    if (data == null) return null;
    _renderObject = RemoteDiagnosticsNode(
      data as Map<String, Object?>? ?? {},
      objectGroupApi,
      false,
      null,
    );
    return _renderObject;
  }

  RemoteDiagnosticsNode? _renderObject;

  RemoteDiagnosticsNode? get parentRenderElement {
    final data = json['parentRenderElement'];
    if (data == null) return null;
    _parentRenderElement = RemoteDiagnosticsNode(
      data as Map<String, Object?>? ?? {},
      objectGroupApi,
      false,
      null,
    );
    return _parentRenderElement;
  }

  RemoteDiagnosticsNode? _parentRenderElement;

  BoxConstraints get constraints => deserializeConstraints(
        json['constraints'] as Map<String, Object?>? ?? {},
      );

  BoxParentData get parentData =>
      deserializeParentData(json['parentData'] as Map<String, Object?>? ?? {});

  // [deserializeSize] expects a parameter of type Map<String, Object> (note the
  // non-nullable Object), so we need to first type check as a Map and then we
  // can cast to the expected type.
  Size get size => deserializeSize(
        (json['size'] as Map?)?.cast<String, Object>() ?? <String, Object>{},
      );

  bool get isLocalClass {
    final objectGroup = objectGroupApi;
    if (objectGroup != null) {
      return _isLocalClass ??= objectGroup.isLocalClass(this);
    } else {
      // TODO(jacobr): if objectGroup is a Future<ObjectGroup> we cannot compute
      // whether classes are local as for convenience we need this method to
      // return synchronously.
      return _isLocalClass = false;
    }
  }

  bool? _isLocalClass;

  @override
  bool operator ==(Object other) {
    if (other is! RemoteDiagnosticsNode) return false;
    return jsonEquality(json, other.json);
  }

  @override
  int get hashCode => jsonHashCode(json);

  @visibleForTesting
  static int jsonHashCode(Map<String, dynamic> json) {
    return const DeepCollectionEquality().hash(json);
  }

  @visibleForTesting
  static bool jsonEquality(
    Map<String, dynamic> json1,
    Map<String, dynamic> json2,
  ) {
    return const DeepCollectionEquality().equals(json1, json2);
  }

  /// Separator text to show between property names and values.
  String get separator => showSeparator ? ':' : '';

  /// Label describing the [RemoteDiagnosticsNode], typically shown before a separator
  /// (see [showSeparator]).
  ///
  /// The name should be omitted if the [showName] property is false.
  String? get name => getStringMember('name');

  /// Whether to show a separator between [name] and description.
  ///
  /// If false, name and description should be shown with no separation.
  /// `:` is typically used as a separator when displaying as text.
  bool get showSeparator => getBooleanMember('showSeparator', true);

  /// Returns a description with a short summary of the node itself not
  /// including children or properties.
  ///
  /// `parentConfiguration` specifies how the parent is rendered as text art.
  /// For example, if the parent does not line break between properties, the
  /// description of a property should also be a single line if possible.
  String? get description => getStringMember('description');

  /// Priority level of the diagnostic used to control which diagnostics should
  /// be shown and filtered.
  ///
  /// Typically this only makes sense to set to a different value than
  /// [DiagnosticLevel.info] for diagnostics representing properties. Some
  /// subclasses have a `level` argument to their constructor which influences
  /// the value returned here but other factors also influence it. For example,
  /// whether an exception is thrown computing a property value
  /// [DiagnosticLevel.error] is returned.
  DiagnosticLevel get level => getLevelMember('level', DiagnosticLevel.info);

  /// Whether the name of the property should be shown when showing the default
  /// view of the tree.
  ///
  /// This could be set to false (hiding the name) if the value's description
  /// will make the name self-evident.
  bool get showName => getBooleanMember('showName', true);

  /// Description to show if the node has no displayed properties or children.
  String? getEmptyBodyDescription() => getStringMember('emptyBodyDescription');

  late DiagnosticsTreeStyle style =
      getStyleMember('style', DiagnosticsTreeStyle.sparse);

  /// Dart class defining the diagnostic node.
  /// For example, DiagnosticProperty<Color>, IntProperty, StringProperty, etc.
  /// This should rarely be required except for cases where custom rendering is desired
  /// of a specific Dart diagnostic class.
  String? get type => getStringMember('type');

  /// Whether the description is enclosed in double quotes.
  ///
  /// Only relevant for String properties.
  bool get isQuoted => getBooleanMember('quoted', false);

  bool get hasIsQuoted => json.containsKey('quoted');

  /// Optional unit the [value] is measured in.
  ///
  /// Unit must be acceptable to display immediately after a number with no
  /// spaces. For example: 'physical pixels per logical pixel' should be a
  /// [tooltip] not a [unit].
  ///
  /// Only specified for Number properties.
  String? get unit => getStringMember('unit');

  bool get hasUnit => json.containsKey('unit');

  /// String describing just the numeric [value] without a unit suffix.
  ///
  /// Only specified for Number properties.
  String? get numberToString => getStringMember('numberToString');

  bool get hasNumberToString => json.containsKey('numberToString');

  /// Description to use if the property [value] is true.
  ///
  /// If not specified and [value] equals true the property's priority [level]
  /// will be [DiagnosticLevel.hidden].
  ///
  /// Only applies to Flag properties.
  String? get ifTrue => getStringMember('ifTrue');

  bool get hasIfTrue => json.containsKey('ifTrue');

  /// Description to use if the property value is false.
  ///
  /// If not specified and [value] equals false, the property's priority [level]
  /// will be [DiagnosticLevel.hidden].
  ///
  /// Only applies to Flag properties.
  String? get ifFalse => getStringMember('ifFalse');

  bool get hasIfFalse => json.containsKey('ifFalse');

  /// Value as a List of strings.
  ///
  /// The raw value can always be extracted with the regular observatory protocol.
  ///
  /// Only applies to IterableProperty.
  List<String>? get values {
    final rawValues = json['values'] as List<Object?>?;
    if (rawValues == null) {
      return null;
    }
    return List<String>.from(rawValues);
  }

  /// Whether each of the values is itself a primitive value.
  ///
  /// For example, bool|num|string are primitive values. This is useful as for
  /// non-primitive values, the user may want to view the value with an
  /// interactive object debugger view to get more information on what the value
  /// is.
  List<bool>? get primitiveValues {
    final rawValues = json['primitiveValues'] as List<Object?>?;
    if (rawValues == null) {
      return null;
    }
    return List<bool>.from(rawValues);
  }

  bool get hasValues => json.containsKey('values');

  /// Description to use if the property [value] is not null.
  ///
  /// If the property [value] is not null and [ifPresent] is null, the
  /// [level] for the property is [DiagnosticsLevel.hidden] and the description
  /// from superclass is used.
  ///
  /// Only specified for ObjectFlagProperty.
  String? get ifPresent => getStringMember('ifPresent');

  bool get hasIfPresent => json.containsKey('ifPresent');

  /// If the [value] of the property equals [defaultValue] the priority [level]
  /// of the property is downgraded to [DiagnosticLevel.fine] as the property
  /// value is uninteresting.
  ///
  /// This is the default value of the object represented as a String.
  /// The actual Dart object representing the defaultValue can also be accessed via
  /// the observatory protocol. We can add a convenience helper method to access it here
  /// if there is a use case.
  ///
  /// Typically you shouldn't need to worry about the default value as the underlying
  /// machinery will generate appropriate description and priority level based on the
  /// default value.
  String? get defaultValue => getStringMember('defaultValue');

  /// Whether a property has a default value.
  bool get hasDefaultValue => json.containsKey('defaultValue');

  /// Description if the property description would otherwise be empty.
  ///
  /// Consider showing the property value in gray in an IDE if the description matches
  /// ifEmpty.
  String? get ifEmpty => getStringMember('ifEmpty');

  /// Description if the property [value] is null.
  String? get ifNull => getStringMember('ifNull');

  bool get allowWrap => getBooleanMember('allowWrap', true);

  /// Optional tooltip typically describing the property.
  ///
  /// Example tooltip: 'physical pixels per logical pixel'
  ///
  /// If present, the tooltip is added in parenthesis after the raw value when
  /// generating the string description.
  String get tooltip => getStringMember('tooltip') ?? '';

  bool get hasTooltip => json.containsKey('tooltip');

  /// Whether a [value] of null causes the property to have [level]
  /// [DiagnosticLevel.warning] warning that the property is missing a [value].
  bool get missingIfNull => getBooleanMember('missingIfNull', false);

  /// String representation of exception thrown if accessing the property
  /// [value] threw an exception.
  String? get exception => getStringMember('exception');

  /// Whether accessing the property throws an exception.
  bool get hasException => json.containsKey('exception');

  bool get hasCreationLocation {
    return _creationLocation != null || json.containsKey('creationLocation');
  }

  /// Location id compatible with rebuild location tracking code.
  int get locationId => JsonUtils.getIntMember(json, 'locationId');

  set creationLocation(InspectorSourceLocation? location) {
    _creationLocation = location;
  }

  InspectorSourceLocation? _creationLocation;

  InspectorSourceLocation? get creationLocation {
    if (_creationLocation != null) {
      return _creationLocation;
    }
    if (!hasCreationLocation) {
      return null;
    }
    _creationLocation = InspectorSourceLocation(
      json['creationLocation'] as Map<String, Object?>? ?? {},
      null,
    );
    return _creationLocation;
  }

  /// String representation of the type of the property [value].
  ///
  /// This is determined from the type argument `T` used to instantiate the
  /// [DiagnosticsProperty] class. This means that the type is available even if
  /// [value] is null, but it also means that the [propertyType] is only as
  /// accurate as the type provided when invoking the constructor.
  ///
  /// Generally, this is only useful for diagnostic tools that should display
  /// null values in a manner consistent with the property type. For example, a
  /// tool might display a null [Color] value as an empty rectangle instead of
  /// the word "null".
  String? get propertyType => getStringMember('propertyType');

  /// If the [value] of the property equals [defaultValue] the priority [level]
  /// of the property is downgraded to [DiagnosticLevel.fine] as the property
  /// value is uninteresting.
  ///
  /// [defaultValue] has type [T] or is [kNoDefaultValue].
  DiagnosticLevel get defaultLevel {
    return getLevelMember('defaultLevel', DiagnosticLevel.info);
  }

  /// Whether the value of the property is a Diagnosticable value itself.
  /// Optionally, properties that are themselves Diagnosticable should be
  /// displayed as trees of Diagnosticable properties and children.
  ///
  /// TODO(jacobr): add helpers to get the properties and children of
  /// this Diagnosticable value even if getChildren and getProperties
  /// would return null. This will allow showing nested data for properties
  /// that don't show children by default in other debugging output but
  /// could.
  bool get isDiagnosticableValue {
    return getBooleanMember('isDiagnosticableValue', false);
  }

  String? getStringMember(String memberName) {
    return JsonUtils.getStringMember(json, memberName);
  }

  bool getBooleanMember(String memberName, bool defaultValue) {
    if (json[memberName] == null) {
      return defaultValue;
    }

    return json[memberName] as bool;
  }

  DiagnosticLevel getLevelMember(
    String memberName,
    DiagnosticLevel defaultValue,
  ) {
    final value = json[memberName] as String?;
    if (value == null) {
      return defaultValue;
    }
    return diagnosticLevelUtils.enumEntry(value)!;
  }

  DiagnosticsTreeStyle getStyleMember(
    String memberName,
    DiagnosticsTreeStyle defaultValue,
  ) {
    if (!json.containsKey(memberName)) {
      return defaultValue;
    }
    final value = json[memberName] as String?;
    if (value == null) {
      return defaultValue;
    }
    return treeStyleUtils.enumEntry(value)!;
  }

  /// Returns a reference to the value the DiagnosticsNode object is describing.
  InspectorInstanceRef get valueRef =>
      InspectorInstanceRef(json['valueId'] as String?);

  bool isEnumProperty() {
    return type?.startsWith('EnumProperty<') ?? false;
  }

  /// Returns a list of raw Dart property values of the Dart value of this
  /// property that are useful for custom display of the property value.
  /// For example, get the red, green, and blue components of color.
  ///
  /// Unfortunately we cannot just use the list of fields from the Observatory
  /// Instance object for the Dart value because much of the relevant
  /// information to display good visualizations of Flutter values is stored
  /// in properties not in fields.
  Future<Map<String, InstanceRef>?> get valueProperties async {
    if (_valueProperties == null) {
      if (propertyType == null || valueRef.id == null) {
        return _valueProperties = Future.value();
      }
      if (isEnumProperty()) {
        // Populate all the enum property values.
        return objectGroupApi?.getEnumPropertyValues(valueRef);
      }

      List<String> propertyNames;
      // Add more cases here as visual displays for additional Dart objects
      // are added.
      switch (propertyType) {
        case 'Color':
          propertyNames = ['red', 'green', 'blue', 'alpha'];
          break;
        case 'IconData':
          propertyNames = ['codePoint'];
          break;
        default:
          return _valueProperties = Future.value();
      }
      _valueProperties =
          objectGroupApi?.getDartObjectProperties(valueRef, propertyNames);
    }
    return _valueProperties;
  }

  Map<String, Object?>? get valuePropertiesJson =>
      json['valueProperties'] as Map<String, Object?>?;

  bool get hasChildren {
    // In the summary tree, json['hasChildren']==true when the node has details
    // tree children so we need to first check whether the list of children for
    // the node in the tree was specified. If there is an empty list of children
    // that indicates the node should have no children in the tree while if the
    // 'children' property is not specified it means we do not know whether
    // there is a list of children and need to query the server to find out.
    final children = json['children'] as List<Object?>?;
    if (children != null) {
      return children.isNotEmpty;
    }
    return getBooleanMember('hasChildren', false);
  }

  bool get isCreatedByLocalProject {
    return getBooleanMember('createdByLocalProject', false);
  }

  /// Whether this node is being displayed as a full tree or a filtered tree.
  bool get isSummaryTree => getBooleanMember('summaryTree', false);

  /// Whether this node is being displayed as a full tree or a filtered tree.
  bool get isStateful => getBooleanMember('stateful', false);

  String? get widgetRuntimeType => getStringMember('widgetRuntimeType');

  /// Check whether children are already available.
  bool get childrenReady {
    return json.containsKey('children') || _children != null || !hasChildren;
  }

  Future<List<RemoteDiagnosticsNode>?> get children async {
    await _computeChildren();
    if (_children != null) return _children;
    return await _childrenFuture;
  }

  List<RemoteDiagnosticsNode> get childrenNow {
    _maybePopulateChildren();
    return _children ?? [];
  }

  Future<void> _computeChildren() async {
    _maybePopulateChildren();
    if (!hasChildren || _children != null) {
      return;
    }

    if (_childrenFuture != null) {
      await _childrenFuture;
      return;
    }

    _childrenFuture = _getChildrenHelper();
    try {
      _children = await _childrenFuture;
    } finally {
      _children ??= [];
    }
  }

  Future<List<RemoteDiagnosticsNode>> _getChildrenHelper() {
    return objectGroupApi!.getChildren(
      valueRef,
      isSummaryTree,
      this,
    );
  }

  void _maybePopulateChildren() {
    if (!hasChildren || _children != null) {
      return;
    }

    final jsonArray = json['children'] as List<Object?>?;
    if (jsonArray?.isNotEmpty == true) {
      final nodes = <RemoteDiagnosticsNode>[];
      for (final element in jsonArray!.cast<Map<String, Object?>>()) {
        final child =
            RemoteDiagnosticsNode(element, objectGroupApi, false, parent);
        child.parent = this;
        nodes.add(child);
      }
      _children = nodes;
    }
  }

  Future<List<RemoteDiagnosticsNode>>? _childrenFuture;
  List<RemoteDiagnosticsNode>? _children;

  /// Properties to show inline in the widget tree.
  List<RemoteDiagnosticsNode> get inlineProperties {
    if (cachedProperties == null) {
      cachedProperties = [];
      if (json.containsKey('properties')) {
        final jsonArray = json['properties'] as List<Object?>;
        for (final element in jsonArray.cast<Map<String, Object?>>()) {
          cachedProperties!.add(
            RemoteDiagnosticsNode(element, objectGroupApi, true, parent),
          );
        }
      }
    }
    return cachedProperties!;
  }

  Future<List<RemoteDiagnosticsNode>> getProperties(
    InspectorObjectGroupApi<RemoteDiagnosticsNode> objectGroup,
  ) async {
    return await objectGroup.getProperties(valueRef);
  }

  Widget? get icon {
    if (isProperty) return null;

    return iconMaker.fromWidgetName(widgetRuntimeType);
  }

  /// Returns true if two diagnostic nodes are indistinguishable from
  /// the perspective of a user debugging.
  ///
  /// In practice this means that all fields but the objectId and valueId
  /// properties for the DiagnosticsNode objects are identical. The valueId
  /// field may change even for properties that have not changed because in
  /// some cases such as the 'created' property for an element, the property
  /// value is created dynamically each time 'getProperties' is called.
  bool identicalDisplay(RemoteDiagnosticsNode node) {
    final entries = json.entries;
    if (entries.length != node.json.entries.length) {
      return false;
    }
    for (final entry in entries) {
      final String key = entry.key;
      if (key == 'valueId') {
        continue;
      }
      if (entry.value == node.json[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    for (final property in inlineProperties) {
      properties.add(DiagnosticsProperty(property.name, property));
    }
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final children = childrenNow;
    if (children.isEmpty) return const <DiagnosticsNode>[];
    final regularChildren = <DiagnosticsNode>[];
    for (final child in children) {
      regularChildren.add(child.toDiagnosticsNode());
    }
    return regularChildren;
  }

  @override
  DiagnosticsNode toDiagnosticsNode({
    String? name,
    DiagnosticsTreeStyle? style,
  }) {
    return super.toDiagnosticsNode(
      name: name ?? this.name,
      style: style ?? DiagnosticsTreeStyle.sparse,
    );
  }

  @override
  String toStringShort() {
    return description ?? '';
  }

  Future<void> setSelectionInspector(bool uiAlreadyUpdated) async {
    final objectGroup = objectGroupApi;
    if (objectGroup != null && objectGroup.canSetSelectionInspector) {
      await objectGroup.setSelectionInspector(valueRef, uiAlreadyUpdated);
    }
  }
}
