import 'package:flutter/rendering.dart';
import 'package:vm_service/vm_service.dart';

import '../diagnostics_node.dart';
import '../inspector_service.dart';

const maxRetry = 5;

extension InspectorFlutterService on ObjectGroup {
  /// Retry eval until the resulting json is not empty,
  /// when result is null we should stop retrying because
  /// it means the object does not exist anymore.
  Future<InstanceRef> _evalUntilJsonIsNotEmpty(String command) async {
    InstanceRef result;
    int numRetries = 0;
    do {
      result = await inspectorLibrary.eval(
        command,
        isAlive: this,
      );
      numRetries += 1;
      // result.length <= 2 is used for checking empty json string which is '{}'
    } while (
        numRetries < maxRetry && result != null && (result.length ?? 0) <= 2);
    return result;
  }

  Future<InstanceRef> invokeTweakFlexProperties(
    InspectorInstanceRef ref,
    MainAxisAlignment mainAxisAlignment,
    CrossAxisAlignment crossAxisAlignment,
  ) async {
    if (ref == null) return null;
    final command = '((){'
        '  if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle)'
        '    return "{}";'
        '  dynamic object = WidgetInspectorService.instance.toObject("${ref?.id}");'
        '  if (object == null) return null;'
        '  final render = object.renderObject;'
        '  if (render is RenderFlex) {'
        '    render.mainAxisAlignment = $mainAxisAlignment;'
        '    render.crossAxisAlignment = $crossAxisAlignment;'
        '    render.markNeedsLayout();'
        '  }'
        '})()';
    return await _evalUntilJsonIsNotEmpty(command);
  }

  Future<InstanceRef> invokeTweakFlexFactor(
    InspectorInstanceRef ref,
    int flexFactor,
  ) async {
    if (ref == null) return null;
    final command = '((){'
        '  if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle)'
        '    return "{}";'
        '  dynamic object = WidgetInspectorService.instance.toObject("${ref?.id}");'
        '  if (object == null) return null;'
        '  final render = object.renderObject;'
        '  final parentData = render.parentData;'
        '  if (parentData is FlexParentData) {'
        '    parentData.flex = $flexFactor;'
        '    render.markNeedsLayout();'
        '  }'
        '})()';
    return await _evalUntilJsonIsNotEmpty(command);
  }

  Future<InstanceRef> invokeTweakFlexFit(
    InspectorInstanceRef ref,
    FlexFit flexFit,
  ) async {
    if (ref == null) return null;
    final command = '((){'
        '  if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle)'
        '    return "{}";'
        '  dynamic object = WidgetInspectorService.instance.toObject("${ref?.id}");'
        '  if (object == null) return null;'
        '  final render = object.renderObject;'
        '  final parentData = render.parentData;'
        '  if (parentData is FlexParentData) {'
        '    parentData.fit = $flexFit;'
        '    render.markNeedsLayout();'
        '  }'
        '})()';
    return await _evalUntilJsonIsNotEmpty(command);
  }

  Future<RemoteDiagnosticsNode> getSummarySubtreeWithRenderObject(
    RemoteDiagnosticsNode node, {
    int subtreeDepth = 1,
  }) async {
    if (node == null) return null;
    final id = node.dartDiagnosticRef.id;
    String command = '''
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) return '{}'; 
      final root = WidgetInspectorService.instance.toObject('$id');
      if (root == null) {
        return null;
      }
      final result =  WidgetInspectorService.instance._nodeToJson(
        root,
        InspectorSerializationDelegate(
            groupName: '$groupName',
            summaryTree: true,
            subtreeDepth: $subtreeDepth,
            includeProperties: false,
            service: WidgetInspectorService.instance,
            addAdditionalPropertiesCallback: (node, delegate) {
              final Map<String, Object> additionalJson = <String, Object>{};
              final Object value = node.value;
              if (value is Element) {
                final renderObject = value.renderObject;
                additionalJson['renderObject'] = renderObject.toDiagnosticsNode()?.toJsonMap(
                  delegate.copyWith(
                    subtreeDepth: 0,
                    includeProperties: true,
                  ),
                );
                final Constraints constraints = renderObject.constraints;
                if (constraints != null) {
                  final Map<String, Object> constraintsProperty = <String, Object>{
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
                    additionalJson['flexFit'] = describeEnum(parentData.fit ?? FlexFit.loose);
                  }
                }
              }
              return additionalJson;
            }
        ),
      );
      return WidgetInspectorService.instance._safeJsonEncode(result);
    ''';
    command = '((){${command.split('\n').join()}})()';
    return await parseDiagnosticsNodeDaemon(
      instanceRefToJson(await _evalUntilJsonIsNotEmpty(command)),
    );
  }
}
