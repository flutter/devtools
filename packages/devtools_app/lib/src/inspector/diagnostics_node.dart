// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library diagnostics_node;

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/icons.dart';
import '../utils.dart';
import 'enum_utils.dart';
import 'flutter_widget.dart';
import 'inspector_service.dart';

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
    this.inspectorService,
    this.isProperty,
    this.parent,
  );

  static final CustomIconMaker iconMaker = CustomIconMaker();

  /// This node's parent (if it's been set).
  RemoteDiagnosticsNode parent;

  Future<String> propertyDocFuture;

  List<RemoteDiagnosticsNode> cachedProperties;

  /// Service used to retrieve more detailed information about the value of
  /// the property and its children and properties.
  final FutureOr<ObjectGroup> inspectorService;

  /// JSON describing the diagnostic node.
  final Map<String, Object> json;

  Future<Map<String, InstanceRef>> _valueProperties;

  final bool isProperty;

  bool get isFlex => getBooleanMember('isFlex', false);

  int get flexFactor => json['flexFactor'];

  Map<String, Object> get constraints => json['constraints'];

  Map<String, Object> get renderObject => json['renderObject'];

  Map<String, Object> get size => json['size'];

  @override
  bool operator ==(dynamic other) {
    if (other is! RemoteDiagnosticsNode) return false;
    return dartDiagnosticRef == other.dartDiagnosticRef;
  }

  @override
  int get hashCode => dartDiagnosticRef.hashCode;

  /// Separator text to show between property names and values.
  String get separator => showSeparator ? ':' : '';

  /// Label describing the [RemoteDiagnosticsNode], typically shown before a separator
  /// (see [showSeparator]).
  ///
  /// The name should be omitted if the [showName] property is false.
  String get name => getStringMember('name');

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
  String get description => getStringMember('description');

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
  String getEmptyBodyDescription() => getStringMember('emptyBodyDescription');

  /// Hint for how the node should be displayed.
  DiagnosticsTreeStyle get style {
    return _style ??= getStyleMember('style', DiagnosticsTreeStyle.sparse);
  }

  DiagnosticsTreeStyle _style;

  set style(DiagnosticsTreeStyle style) {
    _style = style;
  }

  /// Dart class defining the diagnostic node.
  /// For example, DiagnosticProperty<Color>, IntProperty, StringProperty, etc.
  /// This should rarely be required except for cases where custom rendering is desired
  /// of a specific Dart diagnostic class.
  String get type => getStringMember('type');

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
  String get unit => getStringMember('unit');

  bool get hasUnit => json.containsKey('unit');

  /// String describing just the numeric [value] without a unit suffix.
  ///
  /// Only specified for Number properties.
  String get numberToString => getStringMember('numberToString');

  bool get hasNumberToString => json.containsKey('numberToString');

  /// Description to use if the property [value] is true.
  ///
  /// If not specified and [value] equals true the property's priority [level]
  /// will be [DiagnosticLevel.hidden].
  ///
  /// Only applies to Flag properties.
  String get ifTrue => getStringMember('ifTrue');

  bool get hasIfTrue => json.containsKey('ifTrue');

  /// Description to use if the property value is false.
  ///
  /// If not specified and [value] equals false, the property's priority [level]
  /// will be [DiagnosticLevel.hidden].
  ///
  /// Only applies to Flag properties.
  String get ifFalse => getStringMember('ifFalse');

  bool get hasIfFalse => json.containsKey('ifFalse');

  /// Value as a List of strings.
  ///
  /// The raw value can always be extracted with the regular observatory protocol.
  ///
  /// Only applies to IterableProperty.
  List<String> get values {
    final List<Object> rawValues = json['values'];
    if (rawValues == null) {
      return null;
    }
    return rawValues.toList();
  }

  bool get hasValues => json.containsKey('values');

  /// Description to use if the property [value] is not null.
  ///
  /// If the property [value] is not null and [ifPresent] is null, the
  /// [level] for the property is [DiagnosticsLevel.hidden] and the description
  /// from superclass is used.
  ///
  /// Only specified for ObjectFlagProperty.
  String get ifPresent => getStringMember('ifPresent');

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
  String get defaultValue => getStringMember('defaultValue');

  /// Whether a property has a default value.
  bool get hasDefaultValue => json.containsKey('defaultValue');

  /// Description if the property description would otherwise be empty.
  ///
  /// Consider showing the property value in gray in an IDE if the description matches
  /// ifEmpty.
  String get ifEmpty => getStringMember('ifEmpty');

  /// Description if the property [value] is null.
  String get ifNull => getStringMember('ifNull');

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
  String get exception => getStringMember('exception');

  /// Whether accessing the property throws an exception.
  bool get hasException => json.containsKey('exception');

  bool get hasCreationLocation {
    return _creationLocation != null || json.containsKey('creationLocation');
  }

  /// Location id compatible with rebuild location tracking code.
  int get locationId => JsonUtils.getIntMember(json, 'locationId');

  set creationLocation(InspectorSourceLocation location) {
    _creationLocation = location;
  }

  InspectorSourceLocation _creationLocation;

  InspectorSourceLocation get creationLocation {
    if (_creationLocation != null) {
      return _creationLocation;
    }
    if (!hasCreationLocation) {
      return null;
    }
    _creationLocation = InspectorSourceLocation(json['creationLocation'], null);
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
  String get propertyType => getStringMember('propertyType');

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
  /// displayed as trees of diagnosticable properties and children.
  ///
  /// TODO(jacobr): add helpers to get the properties and children of
  /// this diagnosticable value even if getChildren and getProperties
  /// would return null. This will allow showing nested data for properties
  /// that don't show children by default in other debugging output but
  /// could.
  bool get isDiagnosticableValue {
    return getBooleanMember('isDiagnosticableValue', false);
  }

  String getStringMember(String memberName) {
    return JsonUtils.getStringMember(json, memberName);
  }

  bool getBooleanMember(String memberName, bool defaultValue) {
    if (json[memberName] == null) {
      return defaultValue;
    }
    return json[memberName];
  }

  DiagnosticLevel getLevelMember(
      String memberName, DiagnosticLevel defaultValue) {
    final String value = json[memberName];
    if (value == null) {
      return defaultValue;
    }
    final level = diagnosticLevelUtils.enumEntry(value);
    assert(level != null, 'Unabled to find level for $value');
    return level ?? defaultValue;
  }

  DiagnosticsTreeStyle getStyleMember(
      String memberName, DiagnosticsTreeStyle defaultValue) {
    if (!json.containsKey(memberName)) {
      return defaultValue;
    }
    final String value = json[memberName];
    if (value == null) {
      return defaultValue;
    }
    final style = treeStyleUtils.enumEntry(value);
    assert(style != null);
    return style ?? defaultValue;
  }

  /// Returns a reference to the value the DiagnosticsNode object is describing.
  InspectorInstanceRef get valueRef => InspectorInstanceRef(json['valueId']);

  bool isEnumProperty() {
    return type != null && type.startsWith('EnumProperty<');
  }

  /// Returns a list of raw Dart property values of the Dart value of this
  /// property that are useful for custom display of the property value.
  /// For example, get the red, green, and blue components of color.
  ///
  /// Unfortunately we cannot just use the list of fields from the Observatory
  /// Instance object for the Dart value because much of the relevant
  /// information to display good visualizations of Flutter values is stored
  /// in properties not in fields.
  Future<Map<String, InstanceRef>> get valueProperties async {
    if (_valueProperties == null) {
      if (propertyType == null || valueRef?.id == null) {
        _valueProperties = Future.value(null);
        return _valueProperties;
      }
      if (isEnumProperty()) {
        // Populate all the enum property values.
        return (await inspectorService)?.getEnumPropertyValues(valueRef);
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
          _valueProperties = Future.value(null);
          return _valueProperties;
      }
      _valueProperties = (await inspectorService)
          ?.getDartObjectProperties(valueRef, propertyNames);
    }
    return _valueProperties;
  }

  Map<String, Object> get valuePropertiesJson => json['valueProperties'];

  bool get hasChildren {
    // In the summary tree, json['hasChildren']==true when the node has details
    // tree children so we need to first check whether the list of children for
    // the node in the tree was specified. If there is an empty list of children
    // that indicates the node should have no children in the tree while if the
    // 'children' property is not specified it means we do not know whether
    // there is a list of children and need to query the server to find out.
    final List children = json['children'];
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

  String get widgetRuntimeType => getStringMember('widgetRuntimeType');

  /// Check whether children are already available.
  bool get childrenReady {
    return json.containsKey('children') || _children != null || !hasChildren;
  }

  Future<List<RemoteDiagnosticsNode>> get children {
    _computeChildren();
    return _childrenFuture;
  }

  List<RemoteDiagnosticsNode> get childrenNow {
    _maybePopulateChildren();
    return _children;
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

  Future<List<RemoteDiagnosticsNode>> _getChildrenHelper() async {
    return (await inspectorService)?.getChildren(
      dartDiagnosticRef,
      isSummaryTree,
      this,
    );
  }

  void _maybePopulateChildren() {
    if (!hasChildren || _children != null) {
      return;
    }

    final List<Object> jsonArray = json['children'];
    if (jsonArray?.isNotEmpty == true) {
      final List<RemoteDiagnosticsNode> nodes = [];
      for (Map<String, Object> element in jsonArray) {
        final child =
            RemoteDiagnosticsNode(element, inspectorService, false, parent);
        child.parent = this;
        nodes.add(child);
      }
      _children = nodes;
    }
  }

  Future<List<RemoteDiagnosticsNode>> _childrenFuture;
  List<RemoteDiagnosticsNode> _children;

  /// Reference the actual Dart DiagnosticsNode object this object is referencing.
  InspectorInstanceRef get dartDiagnosticRef {
    return InspectorInstanceRef(json['objectId']);
  }

  /// Properties to show inline in the widget tree.
  List<RemoteDiagnosticsNode> get inlineProperties {
    if (cachedProperties == null) {
      cachedProperties = [];
      if (json.containsKey('properties')) {
        final List<Object> jsonArray = json['properties'];
        for (Map<String, Object> element in jsonArray) {
          cachedProperties.add(
              RemoteDiagnosticsNode(element, inspectorService, true, parent));
        }
        trackPropertiesMatchingParameters(cachedProperties);
      }
    }
    return cachedProperties;
  }

  Future<List<RemoteDiagnosticsNode>> getProperties(
      ObjectGroup objectGroup) async {
    return trackPropertiesMatchingParameters(
        await objectGroup.getProperties(dartDiagnosticRef));
  }

  List<RemoteDiagnosticsNode> trackPropertiesMatchingParameters(
      List<RemoteDiagnosticsNode> nodes) {
    // Map locations to property nodes where available.
    final List<InspectorSourceLocation> parameterLocations =
        creationLocation?.getParameterLocations();
    if (parameterLocations != null) {
      final Map<String, InspectorSourceLocation> names = {};
      for (InspectorSourceLocation location in parameterLocations) {
        final String name = location.getName();
        if (name != null) {
          names[name] = location;
        }
      }
      for (RemoteDiagnosticsNode node in nodes) {
        node.parent = this;
        final String name = node.name;
        if (name != null) {
          final InspectorSourceLocation parameterLocation = names[name];
          if (parameterLocation != null) {
            node.creationLocation = parameterLocation;
          }
        }
      }
    }
    return nodes;
  }

  Future<String> get propertyDoc {
    propertyDocFuture ??= _createPropertyDocFuture();
    return propertyDocFuture;
  }

  Future<String> _createPropertyDocFuture() async {
    // TODO(jacobr): We need access to the analyzer to support this feature.
    /*
    if (parent != null) {
      DartVmServiceValue vmValue = inspectorService.toDartVmServiceValueForSourceLocation(parent.getValueRef());
      if (vmValue == null) {
       return null;
      }
      return inspectorService.getPropertyLocation(vmValue.getInstanceRef(), getName())
          .thenApplyAsync((XSourcePosition sourcePosition) -> {
      if (sourcePosition != null) {
      final VirtualFile file = sourcePosition.getFile();
      final int offset = sourcePosition.getOffset();

      final Project project = getProject(file);
      if (project != null) {
      final List<HoverInformation> hovers =
      DartAnalysisServerService.getInstance(project).analysis_getHover(file, offset);
      if (!hovers.isEmpty()) {
      return hovers.get(0).getDartdoc();
      }
      }
      }
      return 'Unable to find property source';
      });
      });
    }
*/
    return Future.value('Unable to find property source');
  }

  FlutterWidget get widget {
    return Catalog.instance?.getWidget(widgetRuntimeType);
  }

  DevToolsIcon get icon {
    if (isProperty) return null;
    DevToolsIcon icon = widget?.icon;
    if (icon == null && widgetRuntimeType != null) {
      icon ??= iconMaker.fromWidgetName(widgetRuntimeType);
    }
    return icon;
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
    if (node == null) {
      return false;
    }
    final entries = json.entries;
    if (entries.length != node.json.entries.length) {
      return false;
    }
    for (var entry in entries) {
      final String key = entry.key;
      if (key == 'objectId' || key == 'valueId') {
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
    for (var property in inlineProperties) {
      properties.add(DiagnosticsProperty(property.name, property));
    }
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final children = childrenNow;
    if (children == null || children.isEmpty) return const <DiagnosticsNode>[];
    final regularChildren = <DiagnosticsNode>[];
    for (var child in children) {
      regularChildren.add(child.toDiagnosticsNode());
    }
    return regularChildren;
  }

  @override
  DiagnosticsNode toDiagnosticsNode({String name, DiagnosticsTreeStyle style}) {
    return super.toDiagnosticsNode(
      name: name ?? this.name,
      style: style ?? DiagnosticsTreeStyle.sparse,
    );
  }

  @override
  String toStringShort() {
    return description;
  }

  Future<void> setSelectionInspector(bool uiAlreadyUpdated) async {
    await (await inspectorService)
        ?.setSelectionInspector(valueRef, uiAlreadyUpdated);
  }
}

class InspectorSourceLocation {
  InspectorSourceLocation(this.json, this.parent);

  final Map<String, Object> json;
  final InspectorSourceLocation parent;

  String get path => JsonUtils.getStringMember(json, 'file');

  String getFile() {
    final fileName = path;
    if (fileName == null) {
      return parent != null ? parent.getFile() : null;
    }

    return fileName;
  }

  int getLine() => JsonUtils.getIntMember(json, 'line');

  String getName() => JsonUtils.getStringMember(json, 'name');

  int getColumn() => JsonUtils.getIntMember(json, 'column');

  SourcePosition getXSourcePosition() {
    final file = getFile();
    if (file == null) {
      return null;
    }
    final int line = getLine();
    final int column = getColumn();
    if (line < 0 || column < 0) {
      return null;
    }
    return SourcePosition(file: file, line: line - 1, column: column - 1);
  }

  List<InspectorSourceLocation> getParameterLocations() {
    if (json.containsKey('parameterLocations')) {
      final List<Object> parametersJson = json['parameterLocations'];
      final List<InspectorSourceLocation> ret = [];
      for (int i = 0; i < parametersJson.length; ++i) {
        ret.add(InspectorSourceLocation(parametersJson[i], this));
      }
      return ret;
    }
    return null;
  }
}

class SourcePosition {
  const SourcePosition({this.file, this.line, this.column});

  final String file;
  final int line;
  final int column;
}
