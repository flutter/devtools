import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../globals.dart';
import 'diagnostics_node.dart';
import 'inspector_service.dart';
import 'inspector_service_polyfill.dart';

extension InspectorFlutterService on ObjectGroup {
  Future<void> invokeSetFlexProperties(
    InspectorInstanceRef ref,
    MainAxisAlignment mainAxisAlignment,
    CrossAxisAlignment crossAxisAlignment,
  ) async {
    if (ref == null) return null;
    await invokeServiceExtensionMethod(
      RegistrableServiceExtension.setFlexProperties,
      {
        'id': ref.id,
        'mainAxisAlignment': '$mainAxisAlignment',
        'crossAxisAlignment': '$crossAxisAlignment',
      },
    );
  }

  Future<void> invokeSetFlexFactor(
    InspectorInstanceRef ref,
    int flexFactor,
  ) async {
    if (ref == null) return null;
    await invokeServiceExtensionMethod(
      RegistrableServiceExtension.setFlexFactor,
      {'id': ref.id, 'flexFactor': '$flexFactor'},
    );
  }

  Future<void> invokeSetFlexFit(
    InspectorInstanceRef ref,
    FlexFit flexFit,
  ) async {
    if (ref == null) return null;
    await invokeServiceExtensionMethod(
      RegistrableServiceExtension.setFlexFit,
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
        .isServiceExtensionAvailable('ext.flutter.inspector.$name')) {
      await invokeInspectorPolyfill(this);
    }
    return invokeServiceMethodDaemonParams(name, parameters);
  }
}

class RegistrableServiceExtension {
  RegistrableServiceExtension({
    @required this.name,
  });

  final String name;

  static final getLayoutExplorerNode =
      RegistrableServiceExtension(name: 'getLayoutExplorerNode');
  static final setFlexFit = RegistrableServiceExtension(name: 'setFlexFit');
  static final setFlexFactor =
      RegistrableServiceExtension(name: 'setFlexFactor');
  static final setFlexProperties =
      RegistrableServiceExtension(name: 'setFlexProperties');
}
