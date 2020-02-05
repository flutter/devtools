import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../globals.dart';
import '../diagnostics_node.dart';
import '../inspector_service.dart';

const toEnumEntryCodeDefinition = '''
  T toEnumEntry<T>(List<T> enumEntries, String name) {
    for (T entry in enumEntries) {
      if (entry.toString() == name) {
        return entry;
      }
    }
    return null;
  }
''';

extension InspectorFlutterService on ObjectGroup {
  Future<void> invokeTweakFlexProperties(
    InspectorInstanceRef ref,
    MainAxisAlignment mainAxisAlignment,
    CrossAxisAlignment crossAxisAlignment,
  ) async {
    if (ref == null) return null;
    await invokeServiceExtensionMethod(
      RegistrableServiceExtension.tweakFlexProperties,
      {
        'id': ref.id,
        'mainAxisAlignment': '$mainAxisAlignment',
        'crossAxisAlignment': '$crossAxisAlignment',
      },
    );
  }

  Future<void> invokeTweakFlexFactor(
    InspectorInstanceRef ref,
    int flexFactor,
  ) async {
    if (ref == null) return null;
    await invokeServiceExtensionMethod(
      RegistrableServiceExtension.tweakFlexFactor,
      {'id': ref.id, 'flexFactor': '$flexFactor'},
    );
  }

  Future<void> invokeTweakFlexFit(
    InspectorInstanceRef ref,
    FlexFit flexFit,
  ) async {
    if (ref == null) return null;
    await invokeServiceExtensionMethod(
      RegistrableServiceExtension.tweakFlexFit,
      {'id': ref.id, 'flexFit': '$flexFit'},
    );
  }

  Future<RemoteDiagnosticsNode> getLayoutExplorerNode(
    RemoteDiagnosticsNode node, {
    int subtreeDepth = 1,
  }) async {
    if (node == null) return null;
    return parseDiagnosticsNodeDaemon(invokeServiceExtensionMethod(
      RegistrableServiceExtension.getLayoutExplorerNode,
      {
        'groupName': groupName,
        'id': node.dartDiagnosticRef.id,
        'subtreeDepth': '$subtreeDepth',
      },
    ));
  }

  Future<Object> invokeServiceExtensionMethod(
    RegistrableServiceExtension extension,
    Map<String, String> parameters,
  ) async {
    final name = extension.name;
    if (!serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(name)) {
      String expression = '''
        ${extension.callbackDefinition}
        WidgetInspectorService.instance.registerServiceExtension(
          name: '$name',
          callback: $name
        );
      ''';
      expression = '((){${expression.split('\n').join()}})()';
      await inspectorLibrary.eval(expression, isAlive: this);
    }
    return invokeServiceMethodDaemonParams(name, parameters);
  }
}

class RegistrableServiceExtension {
  RegistrableServiceExtension({
    @required this.name,
    @required this.statements,
    this.requireEnumDeserialization = false,
  });

  final String name;

  /// Statements inside the callback.
  /// Should end with ';'
  /// To deserialize the required parameters, use variable 'parameters'.
  /// See [getLayoutExplorerNode] for example.
  final String statements;

  // Whether this callback need to deserialize enum values or not.
  final bool requireEnumDeserialization;

  // Generated ServiceExtensionCallback definition
  String get callbackDefinition {
    return '''
      ${requireEnumDeserialization ? toEnumEntryCodeDefinition : ''}
      Future<Map<String, dynamic>> $name(Map<String, String> parameters){
        $statements
      }
    ''';
  }

  static final getLayoutExplorerNode = RegistrableServiceExtension(
    name: 'getLayoutExplorerNode',
    statements: '''
        final String id = parameters['id'];
        final int subtreeDepth = int.parse(parameters['subtreeDepth']);
        final String groupName = parameters['groupName'];
        Map<String, Object> result = {};
        final instance = WidgetInspectorService.instance;
        final root = instance.toObject(id);
        if (root == null) {
          result = null;
        } else {
          result = instance._nodeToJson(
            root,
            InspectorSerializationDelegate(
              groupName: groupName,
              summaryTree: true,
              subtreeDepth: subtreeDepth,
              includeProperties: false,
              service: instance,
              addAdditionalPropertiesCallback: (node, delegate) {
                final Map<String, Object> additionalJson = <String, Object>{};
                final Object value = node.value;
                if (value is Element) {
                  final renderObject = value.renderObject;
                  additionalJson['renderObject'] =
                      renderObject.toDiagnosticsNode()?.toJsonMap(
                        delegate.copyWith(
                          subtreeDepth: 0,
                          includeProperties: true,
                        ),
                      );
                  final Constraints constraints = renderObject.constraints;
                  if (constraints != null) {
                    final Map<String, Object> constraintsProperty = <
                        String,
                        Object>{
                      'type': constraints.runtimeType.toString(),
                      'description': constraints.toString(),
                    };
                    if (constraints is BoxConstraints) {
                      constraintsProperty.addAll(<String, Object>{
                        'minWidth': constraints.minWidth.toString(),
                        'minHeight': constraints.minHeight.toString(),
                        'maxWidth': constraints.maxWidth.toString(),
                        'maxHeight': constraints.maxHeight.toString(),
                      });
                    }
                    additionalJson['constraints'] = constraintsProperty;
                  }
                  if (renderObject is RenderBox) {
                    additionalJson['size'] = <String, Object>{
                      'width': renderObject.size.width.toString(),
                      'height': renderObject.size.height.toString(),
                    };

                    final ParentData parentData = renderObject.parentData;
                    if (parentData is FlexParentData) {
                      additionalJson['flexFactor'] = parentData.flex;
                      additionalJson['flexFit'] =
                          describeEnum(parentData.fit ?? FlexFit.tight);
                    }
                  }
                }
                return additionalJson;
              }
            ),
          );
        }
        return Future<Map<String, Object>>.value(<String, Object>{
          'result': result,
        });
      ''',
  );

  static final tweakFlexFit = RegistrableServiceExtension(
    name: 'tweakFlexFit',
    statements: '''
      final String id = parameters['id'];
      final FlexFit flexFit =
          toEnumEntry<FlexFit>(FlexFit.values, parameters['flexFit']);
      dynamic object = WidgetInspectorService.instance.toObject(id);
      if (object == null) return null;
      final render = object.renderObject;
      final parentData = render.parentData;
      if (parentData is FlexParentData) {
        parentData.fit = flexFit;
        render.markNeedsLayout();
      }
    ''',
    requireEnumDeserialization: true,
  );
  static final tweakFlexFactor = RegistrableServiceExtension(
    name: 'tweakFlexFactor',
    statements: '''
      final String id = parameters['id'];
      final String flexFactor = parameters['flexFactor'];
      final int factor = flexFactor == "null" ? null : int.parse(flexFactor);
      final dynamic object = WidgetInspectorService.instance.toObject(id);
      if (object == null) return null;
      final render = object.renderObject;
      final parentData = render.parentData;
      if (parentData is FlexParentData) {
        parentData.flex = factor;
        render.markNeedsLayout();
      }
    ''',
  );
  static final tweakFlexProperties = RegistrableServiceExtension(
    name: 'tweakFlexProperties',
    statements: '''
      final String id = parameters['id'];
      final MainAxisAlignment mainAxisAlignment = toEnumEntry<MainAxisAlignment>(
        MainAxisAlignment.values,
        parameters['mainAxisAlignment'],
      );
      final CrossAxisAlignment crossAxisAlignment = toEnumEntry<CrossAxisAlignment>(
        CrossAxisAlignment.values,
        parameters['crossAxisAlignment'],
      );
      final dynamic object = WidgetInspectorService.instance.toObject(id);
      if (object == null) return null;
      final render = object.renderObject;
      if (render is RenderFlex) {
        render.mainAxisAlignment = mainAxisAlignment;
        render.crossAxisAlignment = crossAxisAlignment;
        render.markNeedsLayout();
      }
    ''',
    requireEnumDeserialization: true,
  );
}
