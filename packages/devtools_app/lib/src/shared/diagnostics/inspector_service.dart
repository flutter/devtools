// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This code is directly based on src/io/flutter/InspectorService.java.
//
// If you add methods to this class you should also add them to
// InspectorService.java.

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/service_extensions.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../console/primitives/simple_items.dart';
import '../globals.dart';
import 'diagnostics_node.dart';
import 'generic_instance_reference.dart';
import 'object_group_api.dart';
import 'primitives/instance_ref.dart';
import 'primitives/source_location.dart';

const inspectorLibraryUri = 'package:flutter/src/widgets/widget_inspector.dart';

abstract class InspectorServiceBase extends DisposableController
    with AutoDisposeControllerMixin {
  InspectorServiceBase({
    required this.clientInspectorName,
    required this.serviceExtensionPrefix,
    required String inspectorLibraryUri,
    ValueListenable<IsolateRef?>? evalIsolate,
  })  : assert(serviceConnection.serviceManager.connectedAppInitialized),
        assert(serviceConnection.serviceManager.service != null),
        clients = {} {
    inspectorLibrary = EvalOnDartLibrary(
      inspectorLibraryUri,
      serviceConnection.serviceManager.service!,
      serviceManager: serviceConnection.serviceManager,
      isolate: evalIsolate,
    );
    _lastMainIsolate =
        serviceConnection.serviceManager.isolateManager.mainIsolate.value;
    addAutoDisposeListener(
      serviceConnection.serviceManager.isolateManager.mainIsolate,
      () {
        final mainIsolate =
            serviceConnection.serviceManager.isolateManager.mainIsolate.value;
        if (mainIsolate != _lastMainIsolate) {
          onIsolateStopped();
        }
        _lastMainIsolate = mainIsolate;
      },
    );
  }

  static int nextGroupId = 0;

  // The class name of the inspector that [InspectorServiceBase] is connecting
  // to, for use when running evals. For example, this should be set to
  // "WidgetInspectorService" when connecting to the Flutter inspector.
  final String clientInspectorName;

  // The prefix added when invoking all registered inspector service extensions.
  // For example, this should be set to "ext.flutter.inspector" when invoking
  // service extensions registered by the Flutter inspector.
  final String serviceExtensionPrefix;

  final Set<InspectorServiceClient> clients;
  late final EvalOnDartLibrary inspectorLibrary;
  IsolateRef? _lastMainIsolate;

  /// Reference to the isolate running the inspector that [InspectorServiceBase]
  /// is connecting to. This isolate should always be the main isolate.
  IsolateRef? get isolateRef => inspectorLibrary.isolateRef;

  /// Called when the main isolate is stopped. Should be overridden in order to
  /// clear data that is obsolete on an isolate restart.
  void onIsolateStopped();

  /// Returns true if the given node's class is declared beneath one of the root
  /// directories of the app's package.
  bool isLocalClass(RemoteDiagnosticsNode node);

  /// Returns a new [InspectorObjectGroupBase] with the given group name.
  InspectorObjectGroupBase createObjectGroup(String debugName);

  bool get isDisposed => _isDisposed;
  bool _isDisposed = false;

  void addClient(InspectorServiceClient client) {
    clients.add(client);
  }

  void removeClient(InspectorServiceClient client) {
    clients.remove(client);
  }

  /// Returns whether to use the Daemon API or the VM Service protocol directly.
  ///
  /// The VM Service protocol must be used when paused at a breakpoint as the
  /// Daemon API calls won't execute until after the current frame is done
  /// rendering.
  bool get useDaemonApi =>
      !serviceConnection.serviceManager.isMainIsolatePaused;

  @override
  void dispose() {
    _isDisposed = true;
    inspectorLibrary.dispose();
    super.dispose();
  }

  bool get hoverEvalModeEnabledByDefault;

  Future<Object> forceRefresh() {
    final futures = <Future<void>>[];
    for (InspectorServiceClient client in clients) {
      try {
        futures.add(client.onForceRefresh());
      } catch (e) {
        log(e.toString());
      }
    }
    return Future.wait(futures);
  }

  Future<bool> invokeBoolServiceMethodNoArgs(String methodName) async {
    return useDaemonApi
        ? await invokeServiceMethodDaemonNoGroupArgs(methodName) == true
        : (await invokeServiceMethodObservatoryNoGroup(methodName))
                ?.valueAsString ==
            'true';
  }

  Future<Object?> invokeServiceMethodDaemonNoGroupArgs(
    String methodName, [
    List<String>? args,
  ]) {
    final Map<String, Object?> params = {};
    if (args != null) {
      for (int i = 0; i < args.length; ++i) {
        params['arg$i'] = args[i];
      }
    }
    return invokeServiceMethodDaemonNoGroup(methodName, args: params);
  }

  Future<InstanceRef?> invokeServiceMethodObservatoryNoGroup(
    String methodName,
  ) {
    return inspectorLibrary.eval(
      '$clientInspectorName.instance.$methodName()',
      isAlive: null,
    );
  }

  Future<Object?> invokeServiceMethodDaemonNoGroup(
    String methodName, {
    Map<String, Object?>? args,
  }) async {
    final callMethodName = '$serviceExtensionPrefix.$methodName';
    if (!serviceConnection.serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(callMethodName)) {
      final available = await serviceConnection
          .serviceManager.serviceExtensionManager
          .waitForServiceExtensionAvailable(callMethodName);
      if (!available) return {'result': null};
    }

    final r =
        await serviceConnection.serviceManager.service!.callServiceExtension(
      callMethodName,
      isolateId: isolateRef!.id,
      args: args,
    );
    final json = r.json!;
    if (json['errorMessage'] != null) {
      throw Exception('$methodName -- ${json['errorMessage']}');
    }
    return json['result'];
  }
}

/// Manages communication between inspector code running in the Flutter app and
/// the inspector.
class InspectorService extends InspectorServiceBase {
  InspectorService({ValueListenable<IsolateRef?>? evalIsolate})
      : super(
          clientInspectorName: 'WidgetInspectorService',
          serviceExtensionPrefix: inspectorExtensionPrefix,
          inspectorLibraryUri: inspectorLibraryUri,
          evalIsolate: evalIsolate,
        ) {
    // Note: We do not need to listen to event history here because the
    // inspector uses a separate API to get the current inspector selection.
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onExtensionEvent
          .listen(onExtensionVmServiceReceived),
    );
    autoDisposeStreamSubscription(
      serviceConnection.serviceManager.service!.onDebugEvent
          .listen(onDebugVmServiceReceived),
    );
  }

  ValueListenable<List<String>> get rootDirectories => _rootDirectories;
  final ValueNotifier<List<String>> _rootDirectories = ValueNotifier([]);

  @visibleForTesting
  Set<String> get rootPackages => _rootPackages;
  late Set<String> _rootPackages;

  @visibleForTesting
  List<String> get rootPackagePrefixes => _rootPackagePrefixes;
  late List<String> _rootPackagePrefixes;

  @visibleForTesting
  final localClasses = <String, ClassRef>{};

  @override
  void onIsolateStopped() {
    _currentSelection = null;
    _cachedSelectionGroups?.clear(true);
    _expectedSelectionChanges.clear();
  }

  @override
  ObjectGroup createObjectGroup(String debugName) {
    return ObjectGroup(debugName, this);
  }

  @override
  bool isLocalClass(RemoteDiagnosticsNode node) {
    // TODO(https://github.com/flutter/devtools/issues/4393): localClasses is
    // not currently being filled.
    if (node.widgetRuntimeType == null) return false;
    // widgetRuntimeType may contain some generic type arguments which we need
    // to strip out. If widgetRuntimeType is "FooWidget<Bar>" then we are only
    // interested in the raw type "FooWidget".
    final rawType = node.widgetRuntimeType!.split('<').first;
    return localClasses.containsKey(rawType);
  }

  @override
  void dispose() {
    _cachedSelectionGroups?.clear(false);
    _cachedSelectionGroups = null;
    super.dispose();
  }

  // When DevTools is embedded, default hover eval mode to off.
  @override
  bool get hoverEvalModeEnabledByDefault => !ideTheme.embed;

  void onExtensionVmServiceReceived(Event e) {
    if ('Flutter.Frame' == e.extensionKind) {
      for (InspectorServiceClient client in clients) {
        try {
          client.onFlutterFrame();
        } catch (e) {
          log('Error handling frame event', error: e);
        }
      }
    }
  }

  void onDebugVmServiceReceived(Event event) {
    if (event.kind == EventKind.kInspect) {
      // Update the UI in IntelliJ.
      notifySelectionChanged();
    }
  }

  /// Map from InspectorInstanceRef to list of timestamps when a selection
  /// change to that ref was triggered by this application.
  ///
  /// This is needed to handle the case where we may send multiple selection
  /// change notifications to the device before we get a notification back that
  /// the selection has actually changed. Without this fix it was rare but
  /// possible to trigger an infinite loop ping-ponging back and forth between
  /// selecting two different nodes in the inspector tree if the selection was
  /// changed more rapidly than the running flutter app could update.
  final Map<InspectorInstanceRef, List<int>> _expectedSelectionChanges = {};

  /// Maximum time in milliseconds that we ever expect it will take for a
  /// selection change to apply.
  ///
  /// In general this heuristic based time should not matter but we keep it
  /// anyway so that in the unlikely event that package:flutter changes and we
  /// do not received all of the selection notification events we expect, we
  /// will not be impacted if there is at least the following delay between
  /// when selection was set to exactly the same location by both the on device
  /// inspector and DevTools.
  static const _maxTimeDelaySelectionNotification = 5000;

  void _trackClientSelfTriggeredSelection(InspectorInstanceRef ref) {
    _expectedSelectionChanges
        .putIfAbsent(ref, () => [])
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns whether the selection change was originally triggered by this
  /// application.
  ///
  /// This method is needed to avoid a race condition when there is a queue of
  /// inspector selection changes due to extremely rapidly navigating through
  /// the inspector tree such as when using the keyboard to navigate.
  bool _isClientTriggeredSelectionChange(InspectorInstanceRef? ref) {
    // TODO(jacobr): once https://github.com/flutter/flutter/issues/39366 is
    // fixed in all versions of flutter we support, remove this logic and
    // determine the source of the inspector selection change directly from the
    // inspector selection changed event.
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (ref != null) {
      if (_expectedSelectionChanges.containsKey(ref)) {
        final times = _expectedSelectionChanges.remove(ref)!;
        while (times.isNotEmpty) {
          final time = times.removeAt(0);
          if (time + _maxTimeDelaySelectionNotification >= currentTime) {
            // We triggered this selection change ourselves. This logic would
            // work fine without the timestamps for the typical case but we use
            // the timestamps to be safe in case there is a bug and selection
            // change events were somehow lost.
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<void> _onRootDirectoriesChanged(List<String> directories) async {
    _rootDirectories.value = directories;
    _rootPackages = {};
    _rootPackagePrefixes = [];
    for (var directory in directories) {
      // TODO(jacobr): add an API to DDS to provide the actual mapping to and
      // from absolute file paths to packages instead of having to guess it
      // here.
      assert(!directory.startsWith('package:'));

      final parts =
          directory.split('/').where((element) => element.isNotEmpty).toList();
      final libIndex = parts.lastIndexOf('lib');
      final path = libIndex > 0 ? parts.sublist(0, libIndex) : parts;
      // Special case handling of bazel packages.
      final google3Index = path.lastIndexOf('google3');
      if (google3Index != -1 && google3Index + 1 < path.length) {
        var packageParts = path.sublist(google3Index + 1);
        // A well formed third_party dart package should be in a directory of
        // the form
        // third_party/dart/packageName                    (package:packageName)
        // or
        // third_party/dart_src/long/package/name    (package:long.package.name)
        // so its path should be at minimum depth 3.
        const minThirdPartyPathDepth = 3;
        if (packageParts.first == 'third_party' &&
            packageParts.length >= minThirdPartyPathDepth) {
          assert(packageParts[1] == 'dart' || packageParts[1] == 'dart_src');
          packageParts = packageParts.sublist(2);
        }
        final google3PackageName = packageParts.join('.');
        _rootPackages.add(google3PackageName);
        _rootPackagePrefixes.add('$google3PackageName.');
      } else {
        _rootPackages.add(path.last);
      }
    }

    await _updateLocalClasses();
  }

  Future<void> _updateLocalClasses() {
    return Future.value();
    // TODO(https://github.com/flutter/devtools/issues/4393)
    // localClasses.clear();
    // if (_rootDirectories.value.isNotEmpty) {
    //   final isolate = inspectorLibrary.isolate!;
    //   for (var libraryRef in isolate.libraries!) {
    //     if (isLocalUri(libraryRef.uri!)) {
    //       try {
    //         final Library library = await inspectorLibrary.service
    //             .getObject(isolate.id!, libraryRef.id!) as Library;
    //         for (var classRef in library.classes!) {
    //           localClasses[classRef.name!] = classRef;
    //         }
    //       } catch (e) {
    //         // Workaround until https://github.com/flutter/devtools/issues/3110
    //         // is fixed.
    //         assert(serviceManager.manager.connectedApp!.isDartWebAppNow!);
    //       }
    //     }
    //   }
    // }
  }

  @visibleForTesting
  bool isLocalUri(String rawUri) {
    final uri = Uri.parse(rawUri);
    if (uri.scheme != 'file' && uri.scheme != 'dart') {
      // package scheme or some other dart specific scheme.
      final packageName = uri.pathSegments.first;
      if (_rootPackages.contains(packageName)) return true;

      // This attempts to gracefully handle the bazel package case.
      return _rootPackagePrefixes
          .any((prefix) => packageName.startsWith(prefix));
    }
    for (var root in _rootDirectories.value) {
      if (root.endsWith(rawUri)) {
        return true;
      }
    }
    return false;
  }

  Future<void> addPubRootDirectories(List<String> rootDirectories) async {
    await _addPubRootDirectories(rootDirectories);
    await _onRootDirectoriesChanged(rootDirectories);
  }

  Future<void> removePubRootDirectories(List<String> rootDirectories) async {
    await _removePubRootDirectories(rootDirectories);
    await _onRootDirectoriesChanged(rootDirectories);
  }

  Future<void> _addPubRootDirectories(List<String> pubDirectories) {
    assert(useDaemonApi);
    return invokeServiceMethodDaemonNoGroupArgs(
      WidgetInspectorServiceExtensions.addPubRootDirectories.name,
      pubDirectories,
    );
  }

  Future<void> _removePubRootDirectories(List<String> pubDirectories) {
    assert(useDaemonApi);
    return invokeServiceMethodDaemonNoGroupArgs(
      WidgetInspectorServiceExtensions.removePubRootDirectories.name,
      pubDirectories,
    );
  }

  Future<List<String>?> getPubRootDirectories() async {
    assert(useDaemonApi);
    final response = await invokeServiceMethodDaemonNoGroupArgs(
      WidgetInspectorServiceExtensions.getPubRootDirectories.name,
    );

    if (response is! List<Object?>) {
      return [];
    }

    return response.map<String>((e) => e.toString()).toList();
  }

  /// Requests the full mapping of widget ids to source locations.
  ///
  /// See [LocationMap] which provides support to parse this JSON.
  Future<Map<String, dynamic>> widgetLocationIdMap() async {
    assert(useDaemonApi);
    final response = await invokeServiceMethodDaemonNoGroupArgs(
      'widgetLocationIdMap',
    );

    if (response is! Map) {
      return {};
    }

    return response as Map<String, dynamic>;
  }

  /// As we aren't running from an IDE, we don't know exactly what the pub root
  /// directories are for the current project so we make a best guess if needed
  /// based on the root directory of the first non artificial widget in the
  /// tree.
  Future<List<String>> inferPubRootDirectoryIfNeeded() async {
    final group = createObjectGroup('temp');
    List<String> directories = await group.getPubRootDirectories();
    if (directories.isEmpty) {
      final directory = await inferPubRootDirectoryIfNeededHelper();
      if (directory != null) {
        directories = [directory];
      }
    }

    await _onRootDirectoriesChanged(directories);
    return directories;
  }

  Future<String?> inferPubRootDirectoryIfNeededHelper() async {
    final group = createObjectGroup('temp');
    final root = await group.getRoot(FlutterTreeType.widget);

    if (root == null) {
      // No need to do anything as there isn't a valid tree (yet?).
      await group.dispose();
      return null;
    }
    List<RemoteDiagnosticsNode?> children = await root.children ?? [];

    if (children.isEmpty) {
      children = await group.getChildren(root.valueRef, false, null);
    }

    if (children.isEmpty) {
      await group.dispose();
      return null;
    }
    final path = children.first!.creationLocation?.path;
    if (path == null) {
      await group.dispose();
      return null;
    }
    // TODO(jacobr): it would be nice to use Isolate.rootLib similar to how
    // debugger.dart does but we are currently blocked by the
    // --track-widget-creation transformer generating absolute paths instead of
    // package:paths.
    // Once https://github.com/flutter/flutter/issues/26615 is fixed we will be
    // able to use package: paths. Temporarily all tools tracking widget
    // locations will need to support both path formats.
    // TODO(jacobr): use the list of loaded scripts to determine the appropriate
    // package root directory given that the root script of this project is in
    // this directory rather than guessing based on url structure.
    final parts = path.split('/');
    String? pubRootDirectory;
    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      if (part == 'lib' || part == 'web') {
        pubRootDirectory = parts.sublist(0, i).join('/');
        break;
      }

      if (part == 'packages') {
        pubRootDirectory = parts.sublist(0, i + 1).join('/');
        break;
      }
    }
    pubRootDirectory ??= (parts..removeLast()).join('/');

    await _addPubRootDirectories([pubRootDirectory]);
    await group.dispose();
    return pubRootDirectory;
  }

  RemoteDiagnosticsNode? _currentSelection;

  InspectorObjectGroupManager get _selectionGroups {
    return _cachedSelectionGroups ??=
        InspectorObjectGroupManager(this, 'selection');
  }

  InspectorObjectGroupManager? _cachedSelectionGroups;

  void notifySelectionChanged() async {
    // The previous selection changed event is obsolete.
    _selectionGroups.cancelNext();
    final group = _selectionGroups.next;
    final pendingSelection = await group.getSelection(
      _currentSelection,
      FlutterTreeType.widget,
      isSummaryTree: false,
    );
    if (!group.disposed &&
        group == _selectionGroups.next &&
        !_isClientTriggeredSelectionChange(pendingSelection?.valueRef)) {
      _currentSelection = pendingSelection;
      assert(group == _selectionGroups.next);
      _selectionGroups.promoteNext();
      for (InspectorServiceClient client in clients) {
        client.onInspectorSelectionChanged();
      }
    }
  }

  /// If the widget tree is not ready, the application should wait for the next
  /// Flutter.Frame event before attempting to display the widget tree. If the
  /// application is ready, the next Flutter.Frame event may never come as no
  /// new frames will be triggered to draw unless something changes in the UI.
  Future<bool> isWidgetTreeReady() {
    return invokeBoolServiceMethodNoArgs(
      WidgetInspectorServiceExtensions.isWidgetTreeReady.name,
    );
  }

  Future<bool> isWidgetCreationTracked() {
    return invokeBoolServiceMethodNoArgs(
      WidgetInspectorServiceExtensions.isWidgetCreationTracked.name,
    );
  }
}

/// This class has additional descenders in Google3.
abstract class InspectorObjectGroupBase
    extends InspectorObjectGroupApi<RemoteDiagnosticsNode> {
  InspectorObjectGroupBase(
    String debugName,
  ) : groupName = '${debugName}_${InspectorServiceBase.nextGroupId}' {
    InspectorServiceBase.nextGroupId++;
  }

  /// Object group all objects in this arena are allocated with.
  final String groupName;

  InspectorServiceBase get inspectorService;

  @override
  bool disposed = false;

  EvalOnDartLibrary get inspectorLibrary => inspectorService.inspectorLibrary;

  bool get useDaemonApi => inspectorService.useDaemonApi;

  /// Once an ObjectGroup has been disposed, all methods returning
  /// DiagnosticsNode objects will return a placeholder dummy node and all methods
  /// returning lists or maps will return empty lists and all other methods will
  /// return null. Generally code should never call methods on a disposed object
  /// group but sometimes due to chained futures that can be difficult to avoid
  /// and it is simpler return an empty result that will be ignored anyway than to
  /// attempt carefully cancel futures.
  @override
  Future<void> dispose() {
    // No need to dispose the group if the isolate is already gone.
    final disposeComplete = inspectorService.isolateRef != null
        ? invokeVoidServiceMethod(
            WidgetInspectorServiceExtensions.disposeGroup.name,
            groupName,
          )
        : Future.value();
    disposed = true;
    return disposeComplete;
  }

  Future<T?> nullIfDisposed<T>(Future<T> Function() supplier) async {
    if (disposed) {
      return null;
    }
    return await supplier();
  }

  T? nullValueIfDisposed<T>(T Function() supplier) {
    if (disposed) {
      return null;
    }

    return supplier();
  }

  void skipIfDisposed(void Function() runnable) {
    if (disposed) {
      return;
    }

    runnable();
  }

  Future<RemoteDiagnosticsNode?> invokeServiceMethodReturningNode(
    String methodName,
  ) async {
    if (disposed) return null;
    return useDaemonApi
        ? parseDiagnosticsNodeDaemon(invokeServiceMethodDaemon(methodName))
        : parseDiagnosticsNodeObservatory(
            invokeServiceMethodObservatory(methodName),
          );
  }

  Future<RemoteDiagnosticsNode?> invokeServiceMethodReturningNodeInspectorRef(
    String methodName,
    InspectorInstanceRef? ref,
  ) async {
    if (disposed) return null;
    return useDaemonApi
        ? parseDiagnosticsNodeDaemon(
            invokeServiceMethodDaemonInspectorRef(methodName, ref),
          )
        : parseDiagnosticsNodeObservatory(
            invokeServiceMethodObservatoryInspectorRef(methodName, ref),
          );
  }

  Future<RemoteDiagnosticsNode?> invokeServiceMethodWithArgReturningNode(
    String methodName,
    String arg,
  ) async {
    if (disposed) return null;
    return useDaemonApi
        ? parseDiagnosticsNodeDaemon(
            invokeServiceMethodDaemonArg(methodName, arg, groupName),
          )
        : parseDiagnosticsNodeObservatory(
            invokeServiceMethodObservatoryWithGroupName1(methodName, arg),
          );
  }

  Future<void> invokeVoidServiceMethodInspectorRef(
    String methodName,
    InspectorInstanceRef ref,
  ) async {
    if (disposed) return;
    if (useDaemonApi) {
      await invokeServiceMethodDaemonInspectorRef(methodName, ref);
    } else {
      await invokeServiceMethodObservatoryInspectorRef(methodName, ref);
    }
  }

  Future<Object?> invokeServiceMethodDaemonArg(
    String methodName,
    String? arg,
    String objectGroup,
  ) {
    final args = {'objectGroup': objectGroup};
    if (arg != null) {
      args['arg'] = arg;
    }
    return invokeServiceMethodDaemonParams(methodName, args);
  }

  Future<Object?> invokeServiceMethodDaemonInspectorRef(
    String methodName,
    InspectorInstanceRef? arg,
  ) {
    return invokeServiceMethodDaemonArg(methodName, arg?.id, groupName);
  }

  Future<InstanceRef?> invokeServiceMethodObservatoryInspectorRef(
    String methodName,
    InspectorInstanceRef? arg,
  ) {
    return inspectorLibrary.eval(
      "${inspectorService.clientInspectorName}.instance.$methodName('${arg?.id}', '$groupName')",
      isAlive: this,
    );
  }

  /// Call a service method passing in an observatory instance reference.
  ///
  /// This call is useful when receiving an 'inspect' event from the
  /// observatory and future use cases such as inspecting a Widget from a
  /// log window.
  ///
  /// This method will always need to use the observatory service as the input
  /// parameter is an Observatory InstanceRef..
  Future<InstanceRef?> invokeServiceMethodOnRefObservatory(
    String methodName,
    InstanceRef arg,
  ) {
    return inspectorLibrary.eval(
      "${inspectorService.clientInspectorName}.instance.$methodName(arg1, '$groupName')",
      isAlive: this,
      scope: {'arg1': arg.id!},
    );
  }

  Future<void> invokeVoidServiceMethod(String methodName, String arg1) async {
    if (disposed) return;
    if (useDaemonApi) {
      await invokeServiceMethodDaemon(methodName, arg1);
    } else {
      await invokeServiceMethodObservatory1(methodName, arg1);
    }
  }

  Future<Object?> invokeServiceMethodDaemon(
    String methodName, [
    String? objectGroup,
  ]) {
    return invokeServiceMethodDaemonParams(
      methodName,
      {'objectGroup': objectGroup ?? groupName},
    );
  }

  /// Invokes a static method on the inspector service passing in the specified
  /// arguments.
  ///
  /// Intent is we could refactor how the API is invoked by only changing this call.
  Future<InstanceRef?> invokeServiceMethodObservatory(String methodName) {
    return invokeServiceMethodObservatory1(methodName, groupName);
  }

  Future<InstanceRef?> invokeServiceMethodObservatory1(
    String methodName,
    String arg1,
  ) {
    return inspectorLibrary.eval(
      "${inspectorService.clientInspectorName}.instance.$methodName('$arg1')",
      isAlive: this,
    );
  }

  Future<InstanceRef?> invokeServiceMethodObservatoryWithGroupName1(
    String methodName,
    String arg1,
  ) {
    return inspectorLibrary.eval(
      "${inspectorService.clientInspectorName}.instance.$methodName('$arg1', '$groupName')",
      isAlive: this,
    );
  }

  // All calls to invokeServiceMethodDaemon bottom out to this call.
  Future<Object?> invokeServiceMethodDaemonParams(
    String methodName,
    Map<String, Object?> params,
  ) async {
    final callMethodName =
        '${inspectorService.serviceExtensionPrefix}.$methodName';
    if (!serviceConnection.serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(callMethodName)) {
      final available = await serviceConnection
          .serviceManager.serviceExtensionManager
          .waitForServiceExtensionAvailable(callMethodName);
      if (!available) return null;
    }

    return await _callServiceExtension(callMethodName, params);
  }

  Future<Object?> _callServiceExtension(
    String extension,
    Map<String, Object?> args,
  ) {
    if (disposed) {
      return Future.value();
    }

    return inspectorLibrary.addRequest(this, () async {
      final r =
          await serviceConnection.serviceManager.service!.callServiceExtension(
        extension,
        isolateId: inspectorService.isolateRef!.id,
        args: args,
      );
      if (disposed) return null;
      final json = r.json!;
      if (json['errorMessage'] != null) {
        throw Exception('$extension -- ${json['errorMessage']}');
      }
      return json['result'];
    });
  }

  Future<RemoteDiagnosticsNode?> parseDiagnosticsNodeDaemon(
    Future<Object?> json,
  ) async {
    if (disposed) return null;
    return parseDiagnosticsNodeHelper(await json as Map<String, Object?>?);
  }

  Future<RemoteDiagnosticsNode?> parseDiagnosticsNodeObservatory(
    FutureOr<InstanceRef?> instanceRefFuture,
  ) async {
    return parseDiagnosticsNodeHelper(
      await instanceRefToJson(await instanceRefFuture) as Map<String, Object?>?,
    );
  }

  RemoteDiagnosticsNode? parseDiagnosticsNodeHelper(
    Map<String, Object?>? jsonElement,
  ) {
    if (disposed) return null;
    if (jsonElement == null) return null;
    return RemoteDiagnosticsNode(jsonElement, this, false, null);
  }

  Future<List<RemoteDiagnosticsNode>> parseDiagnosticsNodesObservatory(
    FutureOr<InstanceRef?> instanceRefFuture,
    RemoteDiagnosticsNode? parent,
    bool isProperty,
  ) async {
    if (disposed || instanceRefFuture == null) return [];
    final instanceRef = await instanceRefFuture;
    if (disposed || instanceRefFuture == null) return [];
    return parseDiagnosticsNodesHelper(
      await instanceRefToJson(instanceRef) as List<Object?>?,
      parent,
      isProperty,
    );
  }

  List<RemoteDiagnosticsNode> parseDiagnosticsNodesHelper(
    List<Object?>? jsonObject,
    RemoteDiagnosticsNode? parent,
    bool isProperty,
  ) {
    if (disposed || jsonObject == null) return const [];
    final nodes = <RemoteDiagnosticsNode>[];
    for (var element in jsonObject.cast<Map<String, Object?>>()) {
      nodes.add(RemoteDiagnosticsNode(element, this, isProperty, parent));
    }
    return nodes;
  }

  Future<List<RemoteDiagnosticsNode>> parseDiagnosticsNodesDaemon(
    FutureOr<Object?> jsonFuture,
    RemoteDiagnosticsNode? parent,
    bool isProperty,
  ) async {
    if (disposed || jsonFuture == null) return const [];

    return parseDiagnosticsNodesHelper(
      await jsonFuture as List<Object?>?,
      parent,
      isProperty,
    );
  }

  /// Requires that the InstanceRef is really referring to a String that is valid JSON.
  Future<Object?> instanceRefToJson(InstanceRef? instanceRef) async {
    if (disposed || instanceRef == null) return null;
    final instance = await inspectorLibrary.getInstance(instanceRef, this);

    if (disposed || instance == null) return null;

    final String? json = instance.valueAsString;
    if (json == null) return null;
    return jsonDecode(json);
  }

  @override
  Future<InstanceRef?> toObservatoryInstanceRef(
    InspectorInstanceRef inspectorInstanceRef,
  ) async {
    if (inspectorInstanceRef.id == null) {
      return null;
    }
    return await invokeServiceMethodObservatoryInspectorRef(
      'toObject',
      inspectorInstanceRef,
    );
  }

  Future<InspectorInstanceRef?> fromInstanceRef(InstanceRef instanceRef) async {
    final inspectorIdRef = await inspectorLibrary.eval(
      "${inspectorService.clientInspectorName}.instance.toId(obj, '$groupName')",
      scope: {'obj': instanceRef.id!},
      isAlive: this,
    );
    if (inspectorIdRef is! InstanceRef) return null;
    return InspectorInstanceRef(inspectorIdRef.valueAsString);
  }

  Future<Instance?> getInstance(FutureOr<InstanceRef?> instanceRef) async {
    if (disposed) {
      return null;
    }
    return inspectorLibrary.getInstance(await instanceRef as InstanceRef, this);
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
  @override
  Future<Map<String, InstanceRef>?> getDartObjectProperties(
    InspectorInstanceRef inspectorInstanceRef,
    final List<String> propertyNames,
  ) async {
    final instanceRef = await toObservatoryInstanceRef(inspectorInstanceRef);
    if (disposed) return null;
    const objectName = 'that';
    final expression =
        '[${propertyNames.map((propertyName) => '$objectName.$propertyName').join(',')}]';
    final Map<String, String> scope = {objectName: instanceRef!.id!};
    final instance = await getInstance(
      inspectorLibrary.eval(expression, isAlive: this, scope: scope),
    );
    if (disposed) return null;

    // We now have an instance object that is a Dart array of all the
    // property values. Convert it back to a map from property name to
    // property values.

    final properties = <String, InstanceRef>{};
    final List<InstanceRef> values =
        instance!.elements!.toList().cast<InstanceRef>();
    assert(values.length == propertyNames.length);
    for (int i = 0; i < propertyNames.length; ++i) {
      properties[propertyNames[i]] = values[i];
    }
    return properties;
  }

  @override
  Future<Map<String, InstanceRef>?> getEnumPropertyValues(
    InspectorInstanceRef ref,
  ) async {
    if (disposed) return null;
    if (ref.id == null) return null;

    final instance = await getInstance(await toObservatoryInstanceRef(ref));
    if (disposed || instance == null) return null;

    final clazz = await inspectorLibrary.getClass(instance.classRef!, this);
    if (disposed || clazz == null) return null;

    final properties = <String, InstanceRef>{};
    for (FieldRef field in clazz.fields!) {
      final String name = field.name!;
      if (isPrivateMember(name)) {
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
      if (field.isConst! && field.isStatic!) {
        properties[field.name!] = field.declaredType!;
      }
    }
    return properties;
  }

  Future<SourcePosition?> getPropertyLocation(
    InstanceRef instanceRef,
    String name,
  ) async {
    final Instance? instance = await getInstance(instanceRef);
    if (instance == null || disposed) {
      return null;
    }
    return getPropertyLocationHelper(instance.classRef!, name);
  }

  Future<SourcePosition?> getPropertyLocationHelper(
    ClassRef classRef,
    String name,
  ) async {
    final clazz = await inspectorLibrary.getClass(classRef, this) as Class;
    for (FuncRef f in clazz.functions!) {
      // TODO(pq): check for properties that match name.
      if (f.name == name) {
        final func = await inspectorLibrary.getFunc(f, this) as Func;
        final SourceLocation? location = func.location;
        throw UnimplementedError(
          'getSourcePosition not implemented. $location',
        );
      }
    }
    final ClassRef? superClass = clazz.superClass;
    return superClass == null
        ? null
        : getPropertyLocationHelper(superClass, name);
  }

  Future<List<RemoteDiagnosticsNode>> getListHelper(
    InspectorInstanceRef? instanceRef,
    String methodName,
    RemoteDiagnosticsNode? parent,
    bool isProperty,
  ) async {
    if (disposed) return const [];
    return useDaemonApi
        ? parseDiagnosticsNodesDaemon(
            invokeServiceMethodDaemonInspectorRef(methodName, instanceRef),
            parent,
            isProperty,
          )
        : parseDiagnosticsNodesObservatory(
            invokeServiceMethodObservatoryInspectorRef(methodName, instanceRef),
            parent,
            isProperty,
          );
  }

  /// Evaluate an expression where `object` references the [inspectorRef] or
  /// [instanceRef] passed in.
  ///
  /// If both [inspectorRef] and [instanceRef] are passed in they are assumed to
  /// reference the same object and the [inspectorRef] is used as it is longer
  /// lived than an InstanceRef.
  Future<InstanceRef?> evalOnRef(
    String expression,
    GenericInstanceRef? ref,
  ) async {
    final inspectorRef = ref?.diagnostic?.valueRef;
    if (inspectorRef != null && inspectorRef.id != null) {
      return await inspectorLibrary.eval(
        "((object) => $expression)(${inspectorService.clientInspectorName}.instance.toObject('${inspectorRef.id}'))",
        isAlive: this,
      );
    }
    final instanceRef = ref!.instanceRef!;
    return await inspectorLibrary.eval(
      expression,
      isAlive: this,
      scope: <String, String>{'object': instanceRef.id!},
    );
  }

  Future<bool> isInspectable(GenericInstanceRef ref) async {
    if (disposed) {
      return false;
    }
    try {
      final result = await evalOnRef(
        'object is Element || object is RenderObject',
        ref,
      );
      if (disposed) return false;
      return 'true' == result?.valueAsString;
    } catch (e) {
      // If the ref is invalid it is not inspectable.
      return false;
    }
  }

  @override
  Future<List<RemoteDiagnosticsNode>> getProperties(
    InspectorInstanceRef instanceRef,
  ) {
    return getListHelper(
      instanceRef,
      WidgetInspectorServiceExtensions.getProperties.name,
      null,
      true,
    );
  }

  @override
  Future<List<RemoteDiagnosticsNode>> getChildren(
    InspectorInstanceRef instanceRef,
    bool summaryTree,
    RemoteDiagnosticsNode? parent,
  ) {
    return getListHelper(
      instanceRef,
      summaryTree
          ? WidgetInspectorServiceExtensions.getChildrenSummaryTree.name
          : WidgetInspectorServiceExtensions.getChildrenDetailsSubtree.name,
      parent,
      false,
    );
  }

  @override
  bool isLocalClass(RemoteDiagnosticsNode node) =>
      inspectorService.isLocalClass(node);
}

/// Class managing a group of inspector objects that can be freed by
/// a single call to dispose().
///
/// After dispose is called, all pending requests made with the ObjectGroup
/// will be skipped. This means that clients should not have to write any
/// special logic to handle orphaned requests.
class ObjectGroup extends InspectorObjectGroupBase {
  ObjectGroup(
    String debugName,
    this.inspectorService,
  ) : super(debugName);

  @override
  final InspectorService inspectorService;

  @override
  bool canSetSelectionInspector = true;

  Future<RemoteDiagnosticsNode?> getRoot(FlutterTreeType type) {
    // There is no excuse to call this method on a disposed group.
    assert(!disposed);
    switch (type) {
      case FlutterTreeType.widget:
        return getRootWidget();
    }
  }

  Future<RemoteDiagnosticsNode?> getRootWidget() {
    return parseDiagnosticsNodeDaemon(
      invokeServiceMethodDaemonParams(
        WidgetInspectorServiceExtensions
            .getRootWidgetSummaryTreeWithPreviews.name,
        {'groupName': groupName},
      ),
    );
  }

  Future<RemoteDiagnosticsNode?> getRootWidgetFullTree() {
    return invokeServiceMethodReturningNode(
      WidgetInspectorServiceExtensions.getRootWidget.name,
    );
  }

  Future<RemoteDiagnosticsNode?> getSummaryTreeWithoutIds() {
    return parseDiagnosticsNodeDaemon(
      invokeServiceMethodDaemon(
        WidgetInspectorServiceExtensions.getRootWidgetSummaryTree.name,
      ),
    );
  }

// TODO these ones could be not needed.
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

  Future<RemoteDiagnosticsNode?> getSelection(
    RemoteDiagnosticsNode? previousSelection,
    FlutterTreeType treeType, {
    required bool isSummaryTree,
  }) async {
    // There is no reason to allow calling this method on a disposed group.
    assert(!disposed);
    if (disposed) return null;
    RemoteDiagnosticsNode? newSelection;
    final InspectorInstanceRef? previousSelectionRef =
        previousSelection?.valueRef;

    switch (treeType) {
      case FlutterTreeType.widget:
        newSelection = await invokeServiceMethodReturningNodeInspectorRef(
          isSummaryTree
              ? WidgetInspectorServiceExtensions.getSelectedSummaryWidget.name
              : WidgetInspectorServiceExtensions.getSelectedWidget.name,
          null,
        );
        break;
    }
    if (disposed) return null;

    return newSelection != null && newSelection.valueRef == previousSelectionRef
        ? previousSelection
        : newSelection;
  }

  @override
  Future<bool> setSelectionInspector(
    InspectorInstanceRef selection,
    bool uiAlreadyUpdated,
  ) {
    if (disposed) {
      return Future.value(false);
    }
    if (uiAlreadyUpdated) {
      inspectorService._trackClientSelfTriggeredSelection(selection);
    }
    return useDaemonApi
        ? handleSetSelectionDaemon(
            invokeServiceMethodDaemonInspectorRef(
              WidgetInspectorServiceExtensions.setSelectionById.name,
              selection,
            ),
            uiAlreadyUpdated,
          )
        : handleSetSelectionObservatory(
            invokeServiceMethodObservatoryInspectorRef(
              WidgetInspectorServiceExtensions.setSelectionById.name,
              selection,
            ),
            uiAlreadyUpdated,
          );
  }

  Future<bool> setSelection(GenericInstanceRef selection) async {
    if (disposed) {
      return true;
    }
    return handleSetSelectionObservatory(
      evalOnRef(
        "${inspectorService.clientInspectorName}.instance.setSelection(object, '$groupName')",
        selection,
      ),
      false,
    );
  }

  Future<bool> handleSetSelectionObservatory(
    Future<InstanceRef?> setSelectionResult,
    bool uiAlreadyUpdated,
  ) async {
    // TODO(jacobr): we need to cancel if another inspect request comes in while we are trying this one.
    if (disposed) return true;
    final instanceRef = await setSelectionResult;
    if (disposed) return true;
    return handleSetSelectionHelper(
      'true' == instanceRef?.valueAsString,
      uiAlreadyUpdated,
    );
  }

  bool handleSetSelectionHelper(bool selectionChanged, bool uiAlreadyUpdated) {
    if (selectionChanged && !uiAlreadyUpdated && !disposed) {
      inspectorService.notifySelectionChanged();
    }
    return selectionChanged && !disposed;
  }

  Future<bool> handleSetSelectionDaemon(
    Future<Object?> setSelectionResult,
    bool uiAlreadyUpdated,
  ) async {
    if (disposed) return false;
    // TODO(jacobr): we need to cancel if another inspect request comes in while we are trying this one.
    final isSelectionChanged = await setSelectionResult;
    if (disposed) return false;
    return handleSetSelectionHelper(
      isSelectionChanged as bool,
      uiAlreadyUpdated,
    );
  }

  Future<RemoteDiagnosticsNode?> getDetailsSubtree(
    RemoteDiagnosticsNode? node, {
    int subtreeDepth = 2,
  }) async {
    if (node == null) return null;
    final args = {
      'objectGroup': groupName,
      'arg': node.valueRef.id,
      'subtreeDepth': subtreeDepth.toString(),
    };
    final json = await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.getDetailsSubtree.name,
      args,
    );
    return parseDiagnosticsNodeHelper(json as Map<String, Object?>?);
  }

  Future<void> invokeSetFlexProperties(
    InspectorInstanceRef ref,
    MainAxisAlignment? mainAxisAlignment,
    CrossAxisAlignment? crossAxisAlignment,
  ) async {
    await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.setFlexProperties.name,
      {
        'id': ref.id,
        'mainAxisAlignment': '$mainAxisAlignment',
        'crossAxisAlignment': '$crossAxisAlignment',
      },
    );
  }

  Future<void> invokeSetFlexFactor(
    InspectorInstanceRef ref,
    int? flexFactor,
  ) async {
    await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.setFlexFactor.name,
      {'id': ref.id, 'flexFactor': '$flexFactor'},
    );
  }

  Future<void> invokeSetFlexFit(
    InspectorInstanceRef ref,
    FlexFit flexFit,
  ) async {
    await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.setFlexFit.name,
      {'id': ref.id, 'flexFit': '$flexFit'},
    );
  }

  Future<RemoteDiagnosticsNode?> getLayoutExplorerNode(
    RemoteDiagnosticsNode? node, {
    int subtreeDepth = 1,
  }) async {
    if (node == null) return null;
    return parseDiagnosticsNodeDaemon(
      invokeServiceMethodDaemonParams(
        WidgetInspectorServiceExtensions.getLayoutExplorerNode.name,
        {
          'groupName': groupName,
          'id': node.valueRef.id,
          'subtreeDepth': '$subtreeDepth',
        },
      ),
    );
  }

  Future<List<String>> getPubRootDirectories() async {
    final invocationResult = await invokeServiceMethodDaemonParams(
      WidgetInspectorServiceExtensions.getPubRootDirectories.name,
      {},
    );
    final directories = (invocationResult as List?)?.cast<Object>();
    return List.from(directories ?? []);
  }
}

abstract class InspectorServiceClient {
  void onInspectorSelectionChanged();

  void onFlutterFrame();

  Future<void> onForceRefresh();
}

/// Manager that simplifies preventing memory leaks when using the
/// InspectorService.
///
/// This class is designed for the use case where you want to manage
/// object references associated with the current displayed UI and object
/// references associated with the candidate next frame of UI to display. Once
/// the next frame is ready, you determine whether you want to display it and
/// discard the current frame and promote the next frame to the current
/// frame if you want to display the next frame otherwise you discard the next
/// frame.
///
/// To use this class load all data you want for the next frame by using
/// the object group specified by [next] and then if you decide to switch
/// to display that frame, call promoteNext() otherwise call clearNext().
class InspectorObjectGroupManager {
  InspectorObjectGroupManager(this.inspectorService, this.debugName);

  final InspectorService inspectorService;
  final String debugName;
  ObjectGroup? _current;
  ObjectGroup? _next;

  Completer<void>? _pendingNext;

  Future<void> get pendingUpdateDone {
    if (_pendingNext != null) {
      return _pendingNext!.future;
    }
    if (_next == null) {
      // There is no pending update.
      return Future.value();
    }

    _pendingNext = Completer();
    return _pendingNext!.future;
  }

  ObjectGroup? get current {
    _current ??= inspectorService.createObjectGroup(debugName);
    return _current;
  }

  ObjectGroup get next {
    _next ??= inspectorService.createObjectGroup(debugName);
    return _next!;
  }

  void clear(bool isolateStopped) {
    if (isolateStopped) {
      // The Dart VM will handle GCing the underlying memory.
      _current = null;
      _setNextNull();
    } else {
      clearCurrent();
      cancelNext();
    }
  }

  void promoteNext() {
    clearCurrent();
    _current = _next;
    _setNextNull();
  }

  void clearCurrent() {
    if (_current != null) {
      unawaited(_current!.dispose());
      _current = null;
    }
  }

  void cancelNext() {
    if (_next != null) {
      unawaited(_next!.dispose());
      _setNextNull();
    }
  }

  void _setNextNull() {
    _next = null;
    if (_pendingNext != null) {
      _pendingNext!.complete(null);
      _pendingNext = null;
    }
  }
}
