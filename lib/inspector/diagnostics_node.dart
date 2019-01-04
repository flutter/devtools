// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library diagnostics_node;

import 'dart:async';

import 'package:devtools/inspector/flutter_widget.dart';
import 'package:devtools/inspector/inspector_service.dart';
import 'package:devtools/ui/icons.dart';
import 'package:devtools/utils.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

/// The various priority levels used to filter which diagnostics are shown and
/// omitted.
///
/// Trees of Flutter diagnostics can be very large so filtering the diagnostics
/// shown matters. Typically filtering to only show diagnostics with at least
/// level debug is appropriate.
///
/// See https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/foundation/diagnostics.dart
/// for the corresponding Dart enum.
enum DiagnosticLevel {
  /// Diagnostics that should not be shown.
  ///
  /// If a user chooses to display [hidden] diagnostics, they should not expect
  /// the diagnostics to be formatted consistently with other diagnostics and
  /// they should expect them to sometimes be be misleading. For example,
  /// [FlagProperty] and [ObjectFlagProperty] have uglier formatting when the
  /// property `value` does does not match a value with a custom flag
  /// description. An example of a misleading diagnostic is a diagnostic for
  /// a property that has no effect because some other property of the object is
  /// set in a way that causes the hidden property to have no effect.
  hidden,

  /// A diagnostic that is likely to be low value but where the diagnostic
  /// display is just as high quality as a diagnostic with a higher level.
  ///
  /// Use this level for diagnostic properties that match their default value
  /// and other cases where showing a diagnostic would not add much value such
  /// as an [IterableProperty] where the value is empty.
  fine,

  /// Diagnostics that should only be shown when performing fine grained
  /// debugging of an object.
  ///
  /// Unlike a [fine] diagnostic, these diagnostics provide important
  /// information about the object that is likely to be needed to debug. Used by
  /// properties that are important but where the property value is too verbose
  /// (e.g. 300+ characters long) to show with a higher diagnostic level.
  debug,

  /// Interesting diagnostics that should be typically shown.
  info,

  /// Very important diagnostics that indicate problematic property values.
  ///
  /// For example, use if you would write the property description
  /// message in ALL CAPS.
  warning,

  /// Diagnostics that indicate errors or unexpected conditions.
  ///
  /// For example, use for property values where computing the value throws an
  /// exception.
  error,

  /// Special level indicating that no diagnostics should be shown.
  ///
  /// Do not specify this level for diagnostics. This level is only used to
  /// filter which diagnostics are shown.
  off,
}

const Map<String, DiagnosticLevel> diagnosticLevelNames = {
  'hidden': DiagnosticLevel.hidden,
  'fine': DiagnosticLevel.fine,
  'debug': DiagnosticLevel.debug,
  'info': DiagnosticLevel.info,
  'warning': DiagnosticLevel.warning,
  'error': DiagnosticLevel.error,
  'off': DiagnosticLevel.off,
};

/// Styles for displaying a node in a [DiagnosticsNode] tree.
///
/// Generally these styles are more important for ASCII art rendering than IDE
/// rendering with the exception of DiagnosticsTreeStyle.offstage which should
/// be used to trigger custom rendering for offstage children perhaps using dashed
/// lines or by graying out offstage children.
///
/// See also: [DiagnosticsNode.toStringDeep] from https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/foundation/diagnostics.dart
/// which dumps text art trees for these  styles.
enum DiagnosticsTreeStyle {
  /// Sparse style for displaying trees.
  sparse,

  /// Connects a node to its parent typically with a dashed line.
  offstage,

  /// Slightly more compact version of the [sparse] style.
  ///
  /// Differences between dense and spare are typically only relevant for ASCII
  /// art display of trees and not for IDE display of trees.
  dense,

  /// Style that enables transitioning from nodes of one style to children of
  /// another.
  ///
  /// Typically doesn't matter for IDE support as all styles are typically
  /// all styles are compatible as far as IDE display is concerned.
  transition,

  /// Suggestion to render the tree just using whitespace without connecting
  /// parents to children using lines.
  whitespace,

  /// Render the tree on a single line without showing children.
  singleLine,
}

const Map<String, DiagnosticsTreeStyle> treeStyleValues = {
  'sparse': DiagnosticsTreeStyle.sparse,
  'offstage': DiagnosticsTreeStyle.offstage,
  'dense': DiagnosticsTreeStyle.dense,
  'transition': DiagnosticsTreeStyle.transition,
  'whitespace': DiagnosticsTreeStyle.whitespace,
  'singleLine': DiagnosticsTreeStyle.singleLine,
};

/// Defines diagnostics data for a [value].
///
/// [DiagnosticsNode] provides a high quality multi-line string dump via
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

class DiagnosticsNode {
  DiagnosticsNode(
    this.json,
    this.inspectorService,
    this.isProperty,
    this.parent,
  );

  static final CustomIconMaker iconMaker = CustomIconMaker();

  /// This node's parent (if it's been set).
  DiagnosticsNode parent;

  Future<String> propertyDocFuture;

  List<DiagnosticsNode> cachedProperties;

  /// Service used to retrieve more detailed information about the value of
  /// the property and its children and properties.
  final ObjectGroup inspectorService;

  /// JSON describing the diagnostic node.
  final Map<String, Object> json;

  Future<Map<String, InstanceRef>> _valueProperties;

  final bool isProperty;

  @override
  bool operator ==(dynamic other) {
    if (other is! DiagnosticsNode) return false;
    return getDartDiagnosticRef() == other.getDartDiagnosticRef();
  }

  @override
  int get hashCode => getDartDiagnosticRef().hashCode;

  @override
  String toString() {
    if (name == null || name.isEmpty || !showName) {
      return description;
    }

    return '$name$separator $description';
  }

  /// Separator text to show between property names and values.
  String get separator {
    return showSeparator ? ':' : '';
  }

  /// Label describing the [DiagnosticsNode], typically shown before a separator
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
    return getStyleMember('style', DiagnosticsTreeStyle.sparse);
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

  bool get hasIfPresen => json.containsKey('ifPresent');

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

  /// Optional tooltip typically describing the property.
  ///
  /// Example tooltip: 'physical pixels per logical pixel'
  ///
  /// If present, the tooltip is added in parenthesis after the raw value when
  /// generating the string description.
  String get tooltip => getStringMember('tooltip');

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
    final level = diagnosticLevelNames[value];
    assert(level != null);
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
    final style = treeStyleValues[value];
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
  Future<Map<String, InstanceRef>> get valueProperties {
    if (_valueProperties == null) {
      if (propertyType == null || valueRef?.id == null) {
        _valueProperties = Future.value(null);
        return _valueProperties;
      }
      if (isEnumProperty()) {
        // Populate all the enum property values.
        _valueProperties = inspectorService.getEnumPropertyValues(valueRef);
        return _valueProperties;
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
      _valueProperties =
          inspectorService.getDartObjectProperties(valueRef, propertyNames);
    }
    return _valueProperties;
  }

  Map<String, Object> get valuePropertiesJson => json['valueProperties'];

  bool get hasChildren {
    if (getBooleanMember('hasChildren', false)) {
      return true;
    }
    final List children = json['children'];
    return children?.isNotEmpty == true;
  }

  bool get isCreatedByLocalProject {
    return getBooleanMember('createdByLocalProject', false);
  }

  /// Whether this node is being displayed as a full tree or a filtered tree.
  bool get isSummaryTree => getBooleanMember('summaryTree', false);

  /// Whether this node is being displayed as a full tree or a filtered tree.
  bool get isStateful => getBooleanMember('stateful', false);

  String get getWidgetRuntimeType => getStringMember('widgetRuntimeType');

  /// Check whether children are already available.
  bool get childrenReady {
    return json.containsKey('children') || _children != null || !hasChildren;
  }

  Future<List<DiagnosticsNode>> get children {
    _computeChildren();
    return _childrenFuture;
  }

  List<DiagnosticsNode> get childrenNow {
    _maybePopulateChildren();
    return _children;
  }

  Future<void> _computeChildren() async {
    _maybePopulateChildren();
    if (!hasChildren || _children != null) {
      return;
    }
    _childrenFuture = inspectorService.getChildren(
        getDartDiagnosticRef(), isSummaryTree, this);
    try {
      _children = await _childrenFuture;
    } finally {
      _children ??= [];
    }
  }

  void _maybePopulateChildren() {
    if (!hasChildren || _children != null) {
      return;
    }

    final List<Object> jsonArray = json['children'];
    if (jsonArray?.isNotEmpty == true) {
      final List<DiagnosticsNode> nodes = [];
      for (Map<String, Object> element in jsonArray) {
        final child = DiagnosticsNode(element, inspectorService, false, parent);
        child.parent = this;
        nodes.add(child);
      }
      _children = nodes;
    }
  }

  Future<List<DiagnosticsNode>> _childrenFuture;
  List<DiagnosticsNode> _children;

  /// Reference the actual Dart DiagnosticsNode object this object is referencing.
  InspectorInstanceRef getDartDiagnosticRef() {
    return InspectorInstanceRef(json['objectId']);
  }

  /// Properties to show inline in the widget tree.
  List<DiagnosticsNode> get inlineProperties {
    if (cachedProperties == null) {
      cachedProperties = [];
      if (json.containsKey('properties')) {
        final List<Object> jsonArray = json['properties'];
        for (Map<String, Object> element in jsonArray) {
          cachedProperties
              .add(DiagnosticsNode(element, inspectorService, true, parent));
        }
        trackPropertiesMatchingParameters(cachedProperties);
      }
    }
    return cachedProperties;
  }

  Future<List<DiagnosticsNode>> getProperties(ObjectGroup objectGroup) async {
    return trackPropertiesMatchingParameters(
        await objectGroup.getProperties(getDartDiagnosticRef()));
  }

  List<DiagnosticsNode> trackPropertiesMatchingParameters(
      List<DiagnosticsNode> nodes) {
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
      for (DiagnosticsNode node in nodes) {
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
    return inspectorService.inspectorService.widgetCatalog
        .getWidget(description);
  }

  Icon get icon {
    if (isProperty) return null;
    Icon icon = widget?.icon;
    icon ??= iconMaker.fromWidgetName(description);
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
  bool identicalDisplay(DiagnosticsNode node) {
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
}

Future<T> bindFutureToCompleter<T>(Future<T> future, Completer<T> completer) {
  future
      .then((v) => completer.complete(v))
      .catchError((e) => completer.completeError(e));
  return future;
}

class InspectorSourceLocation {
  InspectorSourceLocation(this.json, this.parent);

  final Map<String, Object> json;
  final InspectorSourceLocation parent;

  String getPath() {
    return JsonUtils.getStringMember(json, 'file');
  }

  String getFile() {
    final fileName = getPath();
    if (fileName == null) {
      return parent != null ? parent.getFile() : null;
    }

    // We have to strip the file:// or file:/// prefix depending on the
    // operating system to convert from paths stored as URIs to local operating
    // system paths.
    // TODO(jacobr): remove this workaround after the code in package:flutter
    // is fixed to return operating system paths instead of URIs.
    // https://github.com/flutter/flutter-intellij/issues/2217
    return fromSourceLocationUri(fileName);
  }

  int getLine() {
    return JsonUtils.getIntMember(json, 'line');
  }

  String getName() {
    return JsonUtils.getStringMember(json, 'name');
  }

  int getColumn() {
    return JsonUtils.getIntMember(json, 'column');
  }

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
