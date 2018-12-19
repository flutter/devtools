import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:devtools/inspector/diagnostics_node.dart';
import 'package:devtools/inspector/flutter_widget.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import '../eval_on_dart_library.dart';
import '../globals.dart';

/// Manages communication between inspector code running in the Flutter app and
/// the inspector.
class InspectorService {
  InspectorService(
    this.vmService,
    this.inspectorLibrary,
    this.supportedServiceMethods,
    this.widgetCatalog,
  ) : clients = new Set() {
    vmService.onExtensionEvent.listen(onExtensionVmServiceRecieved);
    vmService.onDebugEvent.listen(onDebugVmServiceReceived);

    // TODO(jacobr): determine what to claim the pub root directories are
    // or cleanup this code.
    /*
    assert (app.getVMServiceManager() != null);

        app.getVMServiceManager().hasServiceExtension('ext.flutter.inspector.setPubRootDirectories', (bool available) -> {
        if (!available) {
        return;
        }
        final List<String> rootDirectories = new List<>();
        for (PubRoot root : app.getPubRoots()) {
        String path = root.getRoot().getCanonicalPath();
        if (SystemInfo.isWindows) {
        // TODO(jacobr): remove after https://github.com/flutter/flutter-intellij/issues/2217.
        // The problem is setPubRootDirectories is currently expecting
        // valid URIs as opposed to windows paths.
        path = 'file:///' + path;
        }
        rootDirectories.add(path);
        }
        setPubRootDirectories(rootDirectories);
        });
        */
  }

  static int nextGroupId = 0;

  final VmService vmService;
  final Set<InspectorServiceClient> clients;
  final EvalOnDartLibrary inspectorLibrary;
  final Set<String> supportedServiceMethods;
  final Catalog widgetCatalog;

  static Future<InspectorService> create() async {
    assert(serviceManager.hasConnection);
    assert(serviceManager.service != null);
    final vmService = serviceManager.service;
    final inspectorLibrary = new EvalOnDartLibrary(
      'package:flutter/src/widgets/widget_inspector.dart',
      vmService,
    );

    final libraryFuture =
        inspectorLibrary.getLibrary(await inspectorLibrary.libraryRef, null);
    final catalogFuture = Catalog.load();
    final library = await libraryFuture;
    final catalog = await catalogFuture;
    Future<Set<String>> lookupFunctionNames() async {
      for (ClassRef classRef in library.classes) {
        if ('WidgetInspectorService' == classRef.name) {
          final classObj = await inspectorLibrary.getClass(classRef, null);
          final Set<String> functionNames = new Set();
          for (FuncRef funcRef in classObj.functions) {
            functionNames.add(funcRef.name);
          }
          return functionNames;
        }
      }
      throw new Exception('WidgetInspectorService class not found');
    }

    final supportedServiceMethods = await lookupFunctionNames();
    return new InspectorService(
      vmService,
      inspectorLibrary,
      supportedServiceMethods,
      catalog,
    );
  }

  /// Returns whether to use the Daemon API or the VM Service protocol directly.
  ///
  /// The VM Service protocol must be used when paused at a breakpoint as the
  /// Daemon API calls won't execute until after the current frame is done
  /// rendering.
  bool get useDaemonApi {
    return true;
    // TODO(jacobr): once there is a debugger, hook to it to determine whether
    // we are suspended.
    // return !app.isFlutterIsolateSuspended();
  }

  bool get isDetailsSummaryViewSupported {
    return hasServiceMethod('getSelectedSummaryWidget');
  }

  /// Use this method to write code that is backwards compatible with versions
  /// of Flutter that are too old to contain specific service methods.
  bool hasServiceMethod(String methodName) {
    return supportedServiceMethods.contains(methodName);
  }

  ObjectGroup createObjectGroup(String debugName) {
    return new ObjectGroup(debugName, this);
  }

  void dispose() {
    inspectorLibrary.dispose();
  }

  Future<Object> forceRefresh() {
    final List<Future<Object>> futures = [];
    for (InspectorServiceClient client in clients) {
      try {
        futures.add(client.onForceRefresh());
      } catch (e) {
        log(e);
      }
    }
    return Future.wait(futures);
  }

  void notifySelectionChanged() {
    for (InspectorServiceClient client in clients) {
      client.onInspectorSelectionChanged();
    }
  }

  void addClient(InspectorServiceClient client) {
    clients.add(client);
  }

  void onDebugVmServiceReceived(Event event) {
    if (event.kind == EventKind.kInspect) {
      // Make sure the WidgetInspector on the device switches to show the inspected object
      // if the inspected object is a Widget or RenderObject.

      // We create a dummy object group as this particular operation
      // doesn't actually require an object group.
      createObjectGroup('dummy').setSelection(event.inspectee, true);
      // Update the UI in IntelliJ.
      notifySelectionChanged();
    }
  }

  void onExtensionVmServiceRecieved(Event e) {
    if ('Flutter.Frame' == e.kind) {
      for (InspectorServiceClient client in clients) {
        try {
          client.onFlutterFrame();
        } catch (e) {
          log('Error handling frame event', error: e);
        }
      }
    }
  }

  /// If the widget tree is not ready, the application should wait for the next
  /// Flutter.Frame event before attempting to display the widget tree. If the
  /// application is ready, the next Flutter.Frame event may never come as no
  /// new frames will be triggered to draw unless something changes in the UI.
  Future<bool> isWidgetTreeReady() async {
    if (useDaemonApi) {
      return await invokeServiceMethodDaemonNoGroupArgs('isWidgetTreeReady') ==
          true;
    } else {
      return (await invokeServiceMethodObservatoryNoGroup('isWidgetTreeReady'))
              ?.valueAsString ==
          'true';
    }
  }

  Future<Object> invokeServiceMethodDaemonNoGroupArgs(String methodName,
      [List<String> args]) {
    final Map<String, Object> params = {};
    for (int i = 0; i < args.length; ++i) {
      params['arg$i'] = args[i];
    }
    return invokeServiceMethodDaemonNoGroup(methodName, params);
  }

  void setPubRootDirectories(List<String> rootDirectories) async {
    // No need to call this from a breakpoint.
    assert(useDaemonApi);
    await invokeServiceMethodDaemonNoGroupArgs(
        'setPubRootDirectories', rootDirectories);
  }

  Future<InstanceRef> invokeServiceMethodObservatoryNoGroup(String methodName) {
    return inspectorLibrary
        .eval('WidgetInspectorService.instance.$methodName()', isAlive: null);
  }

  Future<Object> invokeServiceMethodDaemonNoGroup(
      String methodName, Map<String, Object> args) async {
    final r = await vmService.callServiceExtension(
      'ext.flutter.inspector.$methodName',
      isolateId: inspectorLibrary.isolateId,
      args: args,
    );
    final json = r.json;
    if (json['errorMessage'] != null) {
      throw new Exception('$methodName -- ${json['errorMessage']}');
    }
    print('XXX FIGURE OUT WHAT THE schema IS: $json');
    return json['result'];
  }
}

/// Class managing a group of inspector objects that can be freed by
/// a single call to dispose().
/// After dispose is called, all pending requests made with the ObjectGroup
/// will be skipped. This means that clients should not have to write any
/// special logic to handle orphaned requests.
class ObjectGroup {
  ObjectGroup(
    String debugName,
    this.inspectorService,
  ) : groupName = '${debugName}_${InspectorService.nextGroupId}' {
    InspectorService.nextGroupId++;
  }

  /// Object group all objects in this arena are allocated with.
  final String groupName;
  final InspectorService inspectorService;
  bool disposed;

  EvalOnDartLibrary get inspectorLibrary => inspectorService.inspectorLibrary;
  bool get useDaemonApi => inspectorService.useDaemonApi;

  /// Once an ObjectGroup has been disposed, all methods returning
  /// DiagnosticsNode objects will return a placeholder dummy node and all methods
  /// returning lists or maps will return empty lists and all other methods will
  /// return null. Generally code should never call methods on a disposed object
  /// group but sometimes due to chained futures that can be difficult to avoid
  /// and it is simpler return an empty result that will be ignored anyway than to
  /// attempt carefully cancel futures.
  void dispose() {
    invokeVoidServiceMethod('disposeGroup', groupName);
    disposed = true;
  }

  Future<T> nullIfDisposed<T>(Future<T> supplier()) async {
    if (disposed) {
      return null;
    }
    return await supplier();
  }

  T nullValueIfDisposed<T>(T supplier()) {
    if (disposed) {
      return null;
    }

    return supplier();
  }

  void skipIfDisposed(void runnable()) {
    if (disposed) {
      return;
    }

    runnable();
  }

  Future<SourcePosition> getPropertyLocation(
      InstanceRef instanceRef, String name) async {
    final Instance instance = await getInstance(instanceRef);
    if (instance == null || disposed) {
      return null;
    }
    return getPropertyLocationHelper(instance.classRef, name);
  }

  Future<SourcePosition> getPropertyLocationHelper(
      ClassRef classRef, String name) async {
    final clazz = await inspectorLibrary.getClass(classRef, this);
    for (FuncRef f in clazz.functions) {
      // TODO(pq): check for properties that match name.
      if (f.name == name) {
        final func = await inspectorLibrary.getFunc(f, this);
        final SourceLocation location = func.location;
        throw UnimplementedError(
            'getSourcePosition not implemented. $location');
//        return inspectorLibrary.getSourcePosition(
//            debugProcess, location.script, location.tokenPos, this);
      }
    }
    final ClassRef superClass = clazz.superClass;
    return superClass == null
        ? null
        : getPropertyLocationHelper(superClass, name);
  }

  Future<DiagnosticsNode> getRoot(FlutterTreeType type) {
    // There is no excuse to call this method on a disposed group.
    assert(!disposed);
    switch (type) {
      case FlutterTreeType.widget:
        return getRootWidget();
      case FlutterTreeType.renderObject:
        return getRootRenderObject();
    }
    throw new Exception('Unexpected FlutterTreeType');
  }

  /// Invokes a static method on the WidgetInspectorService class passing in the specified
  /// arguments.
  ///
  /// Intent is we could refactor how the API is invoked by only changing this call.
  Future<InstanceRef> invokeServiceMethodObservatory(String methodName) {
    return invokeServiceMethodObservatory1(methodName, groupName);
  }

  Future<InstanceRef> invokeServiceMethodObservatory1(
      String methodName, String arg1) {
    return inspectorLibrary.eval(
      "WidgetInspectorService.instance.$methodName('$arg1')",
      isAlive: this,
    );
  }

  Future<Object> invokeServiceMethodDaemon(String methodName,
      [String objectGroup]) {
    return invokeServiceMethodDaemonParams(
      methodName,
      {'objectGroup': objectGroup ?? groupName},
    );
  }

  Future<Object> invokeServiceMethodDaemonArg(
      String methodName, String arg, String objectGroup) {
    return invokeServiceMethodDaemonParams(
      methodName,
      {'arg': arg, 'objectGroup': objectGroup},
    );
  }

  Future<Object> _callServiceExtension(
      String extension, Map<String, Object> args) {
    return inspectorLibrary.addRequest(this, () async {
      final r = await inspectorService.vmService.callServiceExtension(
        extension,
        isolateId: inspectorService.inspectorLibrary.isolateId,
        args: args,
      );
      if (disposed) return null;
      final json = r.json;
      if (json['errorMessage'] != null) {
        throw new Exception('$extension -- ${json['errorMessage']}');
      }
      print('XXX FIGURE OUT WHAT THE schema IS: $json');
      return json['result'];
    });
  }

  // All calls to invokeServiceMethodDaemon bottom out to this call.
  Future<Object> invokeServiceMethodDaemonParams(
    String methodName,
    Map<String, Object> params,
  ) async {
    final Map<String, Object> json =
        await inspectorService.inspectorLibrary.addRequest(this, () {
      return _callServiceExtension(
        'ext.flutter.inspector.$methodName',
        params,
      );
    });
    if (json == null) return null;
    if (json.containsKey('errorMessage')) {
      final message = json['errorMessage'];
      throw new Exception('$methodName -- $message');
    }
    return json['result'];
  }

  Future<Map<String, Object>> invokeServiceMethodDaemonInspectorRef(
      String methodName, InspectorInstanceRef arg) {
    return invokeServiceMethodDaemonArg(methodName, arg?.id, groupName);
  }

  Future<InstanceRef> invokeServiceMethodObservatoryInspectorRef(
      String methodName, InspectorInstanceRef arg) {
    return inspectorLibrary.eval(
        "WidgetInspectorService.instance.$methodName('${arg?.id}', '$groupName')",
        isAlive: this);
  }

  /// Call a service method passing in an observatory instance reference.
  ///
  /// This call is useful when receiving an 'inspect' event from the
  /// observatory and future use cases such as inspecting a Widget from a
  /// log window.
  ///
  /// This method will always need to use the observatory service as the input
  /// parameter is an Observatory InstanceRef..
  Future<InstanceRef> invokeServiceMethodOnRefObservatory(
      String methodName, InstanceRef arg) {
    if (arg == null) {
      return inspectorLibrary.eval(
        "WidgetInspectorService.instance.$methodName(null, '$groupName')",
        isAlive: this,
      );
    }
    return inspectorLibrary.eval(
      "WidgetInspectorService.instance.$methodName(arg1, '$groupName')",
      isAlive: this,
      scope: {'arg1': arg.id},
    );
  }

  Future<DiagnosticsNode> parseDiagnosticsNodeObservatory(
      FutureOr<InstanceRef> instanceRefFuture) async {
    return parseDiagnosticsNodeHelper(
        await instanceRefToJson(await instanceRefFuture));
  }

  /// Returns a Future with a Map of property names to Observatory
  /// InstanceRef objects. This method is shorthand for individually evaluating
  /// each of the getters specified by property names.
  ///
  /// It would be nice if the Observatory protocol provided a built in method
  /// to get InstanceRef objects for a list of properties but this is
  /// sufficient although slightly less efficient. The Observatory protocol
  /// does provide fast access to all fields as part of an Instance object
  /// but that is inadequate as for many Flutter data objects that we want
  /// to display visually we care about properties that are not necessarily
  /// fields.
  ///
  /// The future will immediately complete to null if the inspectorInstanceRef is null.
  Future<Map<String, InstanceRef>> getDartObjectProperties(
    InspectorInstanceRef inspectorInstanceRef,
    final List<String> propertyNames,
  ) async {
    final instanceRef = await toObservatoryInstanceRef(inspectorInstanceRef);
    if (disposed) return null;
    const objectName = 'that';
    final expression =
        '[${propertyNames.map((propertyName) => '$objectName.$propertyName').join(',')}]';
    final Map<String, String> scope = {objectName: instanceRef.id};
    final instance = await getInstance(
        inspectorLibrary.eval(expression, isAlive: this, scope: scope));
    if (disposed) return null;

    // We now have an instance object that is a Dart array of all the
    // property values. Convert it back to a map from property name to
    // property values.

    final Map<String, InstanceRef> properties = {};
    final List<InstanceRef> values = instance.elements.toList();
    assert(values.length == propertyNames.length);
    for (int i = 0; i < propertyNames.length; ++i) {
      properties[propertyNames[i]] = values[i];
    }
    return properties;
  }

  Future<InstanceRef> toObservatoryInstanceRef(
      InspectorInstanceRef inspectorInstanceRef) {
    return invokeServiceMethodObservatoryInspectorRef(
        'toObject', inspectorInstanceRef);
  }

  Future<Instance> getInstance(FutureOr<InstanceRef> instanceRef) async {
    if (disposed) {
      return null;
    }
    return inspectorLibrary.getInstance(await instanceRef, this);
  }

  Future<DiagnosticsNode> parseDiagnosticsNodeDaemon(
      Future<Object> json) async {
    if (disposed) return null;
    return parseDiagnosticsNodeHelper(await json);
  }

  DiagnosticsNode parseDiagnosticsNodeHelper(Map<String, Object> jsonElement) {
    if (disposed) return null;
    if (jsonElement == null) return null;
    return new DiagnosticsNode(jsonElement, this, false, null);
  }

  /// Requires that the InstanceRef is really referring to a String that is valid JSON.
  Future<Object> instanceRefToJson(InstanceRef instanceRef) async {
    if (disposed || instanceRef == null) return null;
    final instance = await inspectorLibrary.getInstance(instanceRef, this);

    if (disposed || instance == null) return null;

    final String json = instance.valueAsString;
    if (json == null) return null;
    return jsonDecode(json);
  }

  Future<List<DiagnosticsNode>> parseDiagnosticsNodesObservatory(
      FutureOr<InstanceRef> instanceRefFuture, DiagnosticsNode parent) async {
    if (disposed || instanceRefFuture == null) return [];
    final instanceRef = await instanceRefFuture;
    if (disposed || instanceRefFuture == null) return [];
    return parseDiagnosticsNodesHelper(
        await instanceRefToJson(instanceRef), parent);
  }

  List<DiagnosticsNode> parseDiagnosticsNodesHelper(
      List<Object> jsonObject, DiagnosticsNode parent) {
    if (disposed || jsonObject == null) return const [];
    final List<DiagnosticsNode> nodes = [];
    for (Map<String, Object> element in jsonObject) {
      nodes.add(new DiagnosticsNode(element, this, false, parent));
    }
    return nodes;
  }

  Future<List<DiagnosticsNode>> parseDiagnosticsNodesDaemon(
      FutureOr<Object> jsonFuture, DiagnosticsNode parent) async {
    if (disposed || jsonFuture == null) return const [];

    return parseDiagnosticsNodesHelper(await jsonFuture, parent);
  }

  Future<List<DiagnosticsNode>> getChildren(InspectorInstanceRef instanceRef,
      bool summaryTree, DiagnosticsNode parent) {
    if (inspectorService.isDetailsSummaryViewSupported) {
      return getListHelper(
          instanceRef,
          summaryTree ? 'getChildrenSummaryTree' : 'getChildrenDetailsSubtree',
          parent);
    } else {
      return getListHelper(instanceRef, 'getChildren', parent);
    }
  }

  Future<List<DiagnosticsNode>> getProperties(
      InspectorInstanceRef instanceRef) {
    return getListHelper(instanceRef, 'getProperties', null);
  }

  Future<List<DiagnosticsNode>> getListHelper(InspectorInstanceRef instanceRef,
      String methodName, DiagnosticsNode parent) async {
    if (disposed) return const [];
    if (useDaemonApi) {
      return parseDiagnosticsNodesDaemon(
          invokeServiceMethodDaemonInspectorRef(methodName, instanceRef),
          parent);
    } else {
      return parseDiagnosticsNodesObservatory(
          invokeServiceMethodObservatoryInspectorRef(methodName, instanceRef),
          parent);
    }
  }

  Future<DiagnosticsNode> invokeServiceMethodReturningNode(
      String methodName) async {
    if (disposed) return null;
    if (useDaemonApi) {
      return parseDiagnosticsNodeDaemon(invokeServiceMethodDaemon(methodName));
    } else {
      return parseDiagnosticsNodeObservatory(
          invokeServiceMethodObservatory(methodName));
    }
  }

  Future<DiagnosticsNode> invokeServiceMethodReturningNodeInspectorRef(
      String methodName, InspectorInstanceRef ref) {
    if (disposed) return null;
    if (useDaemonApi) {
      return parseDiagnosticsNodeDaemon(
          invokeServiceMethodDaemonInspectorRef(methodName, ref));
    } else {
      return parseDiagnosticsNodeObservatory(
          invokeServiceMethodObservatoryInspectorRef(methodName, ref));
    }
  }

  Future<void> invokeVoidServiceMethod(String methodName, String arg1) async {
    if (disposed) return;
    if (useDaemonApi) {
      await invokeServiceMethodDaemon(methodName, arg1);
    } else {
      await invokeServiceMethodObservatory1(methodName, arg1);
    }
  }

  Future<void> invokeVoidServiceMethodInspectorRef(
      String methodName, InspectorInstanceRef ref) async {
    if (disposed) return;
    if (useDaemonApi) {
      await invokeServiceMethodDaemonInspectorRef(methodName, ref);
    } else {
      await invokeServiceMethodObservatoryInspectorRef(methodName, ref);
    }
  }

  Future<DiagnosticsNode> getRootWidget() {
    return invokeServiceMethodReturningNode(
        inspectorService.isDetailsSummaryViewSupported
            ? 'getRootWidgetSummaryTree'
            : 'getRootWidget');
  }

  Future<DiagnosticsNode> getSummaryTreeWithoutIds() {
    return parseDiagnosticsNodeDaemon(
        invokeServiceMethodDaemon('getRootWidgetSummaryTree', null));
  }

  Future<DiagnosticsNode> getRootRenderObject() {
    assert(!disposed);
    return invokeServiceMethodReturningNode('getRootRenderObject');
  }

  /* TODO(jacobr): this probably isn't needed.
  Future<List<DiagnosticsPathNode>> getParentChain(DiagnosticsNode target) async {
    if (disposed) return null;
    if (useDaemonApi) {
      return parseDiagnosticsPathDaemon(invokeServiceMethodDaemon('getParentChain', target.getValueRef()));
    }
    else {
    return parseDiagnosticsPathObservatory(invokeServiceMethodObservatory('getParentChain', target.getValueRef()));
    }
    });
  }

  Future<List<DiagnosticsPathNode>> parseDiagnosticsPathObservatory(Future<InstanceRef> instanceRefFuture) {
    return nullIfDisposed(() -> instanceRefFuture.thenComposeAsync(this::parseDiagnosticsPathObservatory));
  }

  Future<List<DiagnosticsPathNode>> parseDiagnosticsPathObservatory(InstanceRef pathRef) {
    return nullIfDisposed(() -> instanceRefToJson(pathRef).thenApplyAsync(this::parseDiagnosticsPathHelper));
  }

  Future<List<DiagnosticsPathNode>> parseDiagnosticsPathDaemon(Future<JsonElement> jsonFuture) {
    return nullIfDisposed(() -> jsonFuture.thenApplyAsync(this::parseDiagnosticsPathHelper));
  }

  List<DiagnosticsPathNode> parseDiagnosticsPathHelper(JsonElement jsonElement) {
    return nullValueIfDisposed(() -> {
    final JsonArray jsonArray = jsonElement.getAsJsonArray();
    final List<DiagnosticsPathNode> pathNodes = new List<>();
    for (JsonElement element : jsonArray) {
    pathNodes.add(new DiagnosticsPathNode(element.getAsJsonObject(), this));
    }
    return pathNodes;
    });
  }
*/

  Future<DiagnosticsNode> getSelection(DiagnosticsNode previousSelection,
      FlutterTreeType treeType, bool localOnly) async {
    // There is no reason to allow calling this method on a disposed group.
    assert(!disposed);
    if (disposed) return null;
    DiagnosticsNode newSelection;
    final InspectorInstanceRef previousSelectionRef = previousSelection != null
        ? previousSelection.getDartDiagnosticRef()
        : null;

    switch (treeType) {
      case FlutterTreeType.widget:
        newSelection = await invokeServiceMethodReturningNodeInspectorRef(
            localOnly ? 'getSelectedSummaryWidget' : 'getSelectedWidget',
            previousSelectionRef);
        break;
      case FlutterTreeType.renderObject:
        newSelection = await invokeServiceMethodReturningNodeInspectorRef(
            'getSelectedRenderObject', previousSelectionRef);
        break;
    }
    if (disposed) return null;

    if (newSelection != null &&
        newSelection.getDartDiagnosticRef() == previousSelectionRef) {
      return previousSelection;
    } else {
      return newSelection;
    }
  }

  void setSelectionInspector(
      InspectorInstanceRef selection, bool uiAlreadyUpdated) {
    if (disposed) {
      return;
    }
    if (useDaemonApi) {
      handleSetSelectionDaemon(
          invokeServiceMethodDaemonInspectorRef('setSelectionById', selection),
          uiAlreadyUpdated);
    } else {
      handleSetSelectionObservatory(
          invokeServiceMethodObservatoryInspectorRef(
              'setSelectionById', selection),
          uiAlreadyUpdated);
    }
  }

  /// Helper when we need to set selection given an observatory InstanceRef
  /// instead of an InspectorInstanceRef.
  void setSelection(InstanceRef selection, bool uiAlreadyUpdated) {
    // There is no excuse for calling setSelection using a disposed ObjectGroup.
    assert(!disposed);
    // This call requires the observatory protocol as an observatory InstanceRef is specified.
    handleSetSelectionObservatory(
        invokeServiceMethodOnRefObservatory('setSelection', selection),
        uiAlreadyUpdated);
  }

  void handleSetSelectionObservatory(
      Future<InstanceRef> setSelectionResult, bool uiAlreadyUpdated) async {
    // TODO(jacobr): we need to cancel if another inspect request comes in while we are trying this one.
    if (disposed) return;
    final instanceRef = await setSelectionResult;
    if (disposed) return;
    handleSetSelectionHelper(
        'true' == instanceRef.valueAsString, uiAlreadyUpdated);
  }

  void handleSetSelectionHelper(bool selectionChanged, bool uiAlreadyUpdated) {
    if (selectionChanged && !uiAlreadyUpdated && !disposed) {
      inspectorService.notifySelectionChanged();
    }
  }

  void handleSetSelectionDaemon(
      Future<Object> setSelectionResult, bool uiAlreadyUpdated) async {
    if (disposed) return;
    // TODO(jacobr): we need to cancel if another inspect request comes in while we are trying this one.
    final json = await setSelectionResult;
    if (disposed) return;
    handleSetSelectionHelper(json, uiAlreadyUpdated);
  }

  Future<Map<String, InstanceRef>> getEnumPropertyValues(
      InspectorInstanceRef ref) async {
    if (disposed) return null;
    if (ref?.id == null) return null;

    final instance = await getInstance(await toObservatoryInstanceRef(ref));
    if (disposed || instance == null) return null;

    final clazz = await inspectorLibrary.getClass(instance.classRef, this);
    if (disposed || clazz == null) return null;

    final Map<String, InstanceRef> properties = {};
    for (FieldRef field in clazz.fields) {
      final String name = field.name;
      if (name.startsWith('_')) {
        // Needed to filter out _deleted_enum_sentinel synthetic property.
        // If showing enum values is useful we could special case
        // just the _deleted_enum_sentinel property name.
        continue;
      }
      if (name == 'values') {
        // Need to filter out the synthetic 'values' member.
        // TODO(jacobr): detect that this properties return type is
        // different and filter that way.
        continue;
      }
      if (field.isConst && field.isStatic) {
        properties[field.name] = field.declaredType;
      }
    }
    return properties;
  }

  Future<DiagnosticsNode> getDetailsSubtree(DiagnosticsNode node) async {
    if (node == null) return null;
    return invokeServiceMethodReturningNodeInspectorRef(
        'getDetailsSubtree', node.getDartDiagnosticRef());
  }
}

// TODO(jacobr): can we get the host OS from VMService.
// Ideally we don't need this.
String getFileUriPrefix() {
  // if (SystemInfo.isWindows) return 'file:///';
  return 'file://';
}

// TODO(jacobr): remove this method as soon as the
// track-widget-creation kernel transformer is fixed to return paths instead
// of URIs.
String toSourceLocationUri(String path) {
  return getFileUriPrefix() + path;
}

String fromSourceLocationUri(String path) {
  final String filePrefix = getFileUriPrefix();
  return (path.startsWith(filePrefix))
      ? path.substring(filePrefix.length)
      : path;
}

enum FlutterTreeType {
  widget, // ('Widget'),
  renderObject // ('Render');
// TODO(jacobr): add semantics, and layer trees.
}

abstract class InspectorServiceClient {
  void onInspectorSelectionChanged();

  void onFlutterFrame();

  Future<Object> onForceRefresh();
}

/// Reference to a Dart object.
///
/// This class is similar to the Observatory protocol InstanceRef with the
/// difference that InspectorInstanceRef objects do not expire and all
/// instances of the same Dart object are guaranteed to have the same
/// InspectorInstanceRef id. The tradeoff is the consumer of
/// InspectorInstanceRef objects is responsible for managing their lifecycles.
class InspectorInstanceRef {
  const InspectorInstanceRef(this.id);

  @override
  bool operator ==(Object other) {
    if (other is InspectorInstanceRef) {
      return id == other.id;
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'instance-$id';

  final String id;
}
