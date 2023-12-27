// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../shared/analytics/analytics.dart' as ga;
import '../shared/connected_app.dart';
import '../shared/console/console_service.dart';
import '../shared/diagnostics/inspector_service.dart';
import '../shared/error_badge_manager.dart';
import '../shared/feature_flags.dart';
import '../shared/globals.dart';
import '../shared/title.dart';
import '../shared/utils.dart';
import 'service_registrations.dart' as registrations;
import 'timeline_streams.dart';
import 'vm_flags.dart';
import 'vm_service_logger.dart';
import 'vm_service_wrapper.dart';

final _log = Logger('service_manager');

// Note: don't check this in enabled.
/// Used to debug service protocol traffic. All requests to to the VM service
/// connection are logged to the Logging page, as well as all responses and
/// events from the service protocol device.
const debugLogServiceProtocolEvents = false;

const defaultRefreshRate = 60.0;

/// The amount of time we will wait for the main isolate to become non-null when
/// calling [ServiceConnectionManager.rootLibraryForMainIsolate].
const _waitForRootLibraryTimeout = Duration(seconds: 3);

class ServiceConnectionManager {
  ServiceConnectionManager() {
    serviceManager = ServiceManager()
      ..registerLifecycleCallback(
        ServiceManagerLifecycle.beforeOpenVmService,
        _beforeOpenVmService,
      )
      ..registerLifecycleCallback(
        ServiceManagerLifecycle.afterOpenVmService,
        _afterOpenVmService,
      )
      ..registerLifecycleCallback(
        ServiceManagerLifecycle.beforeCloseVmService,
        _beforeCloseVmService,
      )
      ..registerLifecycleCallback(
        ServiceManagerLifecycle.afterCloseVmService,
        _afterCloseVmService,
      )
      ..registerOverride(
        ServiceManagerOverride.initIsolates,
        (service) async => await serviceManager.isolateManager.init(
          serviceManager.vm?.isolatesForDevToolsMode() ?? <IsolateRef>[],
        ),
      );
  }

  late final ServiceManager<VmServiceWrapper> serviceManager;

  final vmFlagManager = VmFlagManager();

  final timelineStreamManager = TimelineStreamManager();

  final consoleService = ConsoleService();

  InspectorServiceBase? get inspectorService => _inspectorService;
  InspectorServiceBase? _inspectorService;

  DTDConnection? get dtdConnection => _dtdConnection;
  DTDConnection? _dtdConnection;

  ErrorBadgeManager get errorBadgeManager => _errorBadgeManager;
  final _errorBadgeManager = ErrorBadgeManager();

  VmServiceTrafficLogger? serviceTrafficLogger;

  // TODO (polina-c and kenzieschmoll): make appState member of ConnectedApp.
  // https://github.com/flutter/devtools/pull/4993#discussion_r1061774726
  AppState get appState => _appState!;
  AppState? _appState;

  Future<void> _beforeOpenVmService(VmServiceWrapper? service) async {
    consoleService.vmServiceOpened(service!);
    await vmFlagManager.vmServiceOpened(service);
    timelineStreamManager.vmServiceOpened(
      service,
      serviceManager.connectedApp!,
    );
    // This needs to be called last in the above group of `vmServiceOpened`
    // calls.
    errorBadgeManager.vmServiceOpened(service);

    _inspectorService?.dispose();
    _inspectorService = null;
  }

  Future<void> _afterOpenVmService(VmServiceWrapper? service) async {
    // Re-initialize isolates when VM developer mode is enabled/disabled to
    // display/hide system isolates.
    preferences.vmDeveloperModeEnabled
        .addListener(_handleVmDeveloperModeChanged);

    // This needs to be called before calling
    // `ga.setupUserApplicationDimensions()` and before initializing
    // [_inspectorService], since both require access to an initialized
    // [serviceManager.connectedApp] object.
    await serviceManager.connectedApp!
        .initializeValues(onComplete: generateDevToolsTitle);

    // Set up analytics dimensions for the connected app.
    ga.setupUserApplicationDimensions();
    if (FeatureFlags.devToolsExtensions) {
      await extensionService.initialize();
    }

    _inspectorService = devToolsExtensionPoints.inspectorServiceProvider();

    _appState?.dispose();
    _appState = AppState(serviceManager.isolateManager.selectedIsolate);

    if (debugLogServiceProtocolEvents) {
      serviceTrafficLogger = VmServiceTrafficLogger(service!);
    }
  }

  void _beforeCloseVmService(VmServiceWrapper? service) {
    // Set [offlineController.previousConnectedApp] in case we need it for
    // viewing data after disconnect. This must be done before resetting the
    // rest of the service manager state.
    final previousConnectedApp = serviceManager.connectedApp != null
        ? OfflineConnectedApp.parse(serviceManager.connectedApp!.toJson())
        : null;
    offlineController.previousConnectedApp = previousConnectedApp;
  }

  void _afterCloseVmService(VmServiceWrapper? service) {
    generateDevToolsTitle();
    vmFlagManager.vmServiceClosed();
    timelineStreamManager.vmServiceClosed();
    consoleService.handleVmServiceClosed();
    _inspectorService?.onIsolateStopped();
    _inspectorService?.dispose();
    _inspectorService = null;
    serviceTrafficLogger?.dispose();
    preferences.vmDeveloperModeEnabled
        .removeListener(_handleVmDeveloperModeChanged);
  }

  Future<void> _handleVmDeveloperModeChanged() async {
    final vm = await serviceConnection.serviceManager.service!.getVM();
    final isolates = vm.isolatesForDevToolsMode();
    final vmDeveloperModeEnabled = preferences.vmDeveloperModeEnabled.value;
    if (serviceManager.isolateManager.selectedIsolate.value!.isSystemIsolate! &&
        !vmDeveloperModeEnabled) {
      serviceManager.isolateManager
          .selectIsolate(serviceManager.isolateManager.isolates.value.first);
    }
    await serviceManager.isolateManager.init(isolates);
  }

  Future<String?> rootLibraryForMainIsolate() async {
    final mainIsolateRef = await whenValueNonNull(
      serviceManager.isolateManager.mainIsolate,
      timeout: _waitForRootLibraryTimeout,
    );
    if (mainIsolateRef == null) return null;

    final isolateState =
        serviceManager.isolateManager.isolateState(mainIsolateRef);
    await isolateState.waitForIsolateLoad();
    final rootLib = isolateState.rootInfo?.library;
    if (rootLib == null) return null;

    final selectedIsolateRefId = mainIsolateRef.id!;
    await serviceManager.resolvedUriManager
        .fetchFileUris(selectedIsolateRefId, [rootLib]);
    return serviceManager.resolvedUriManager.lookupFileUri(
      selectedIsolateRefId,
      rootLib,
    );
  }

  Future<Response> get adbMemoryInfo async {
    return await serviceManager.callServiceOnMainIsolate(
      registrations.flutterMemoryInfo.service,
    );
  }

  /// Returns the view id for the selected isolate's 'FlutterView'.
  ///
  /// Throws an Exception if no 'FlutterView' is present in this isolate.
  Future<String> get flutterViewId async {
    final flutterViewListResponse =
        await serviceManager.callServiceExtensionOnMainIsolate(
      registrations.flutterListViews,
    );
    final List<Map<String, Object?>> views =
        flutterViewListResponse.json!['views'].cast<Map<String, Object?>>();

    // Each isolate should only have one FlutterView.
    final flutterView = views.firstWhereOrNull(
      (view) => view['type'] == 'FlutterView',
    );

    if (flutterView == null) {
      final message =
          'No Flutter Views to query: ${flutterViewListResponse.json}';
      _log.shout(message);
      throw Exception(message);
    }

    return flutterView['id'] as String;
  }

  /// Flutter engine returns estimate how much memory is used by layer/picture raster
  /// cache entries in bytes.
  ///
  /// Call to returns JSON payload 'EstimateRasterCacheMemory' with two entries:
  ///   layerBytes - layer raster cache entries in bytes
  ///   pictureBytes - picture raster cache entries in bytes
  Future<Response?> get rasterCacheMetrics async {
    if (serviceManager.connectedApp == null ||
        !await serviceManager.connectedApp!.isFlutterApp) {
      return null;
    }

    final viewId = await flutterViewId;

    return await serviceManager.callServiceExtensionOnMainIsolate(
      registrations.flutterEngineEstimateRasterCache,
      args: {
        'viewId': viewId,
      },
    );
  }

  Future<Response?> get renderFrameWithRasterStats async {
    if (serviceManager.connectedApp == null ||
        !await serviceManager.connectedApp!.isFlutterApp) {
      return null;
    }

    final viewId = await flutterViewId;

    return await serviceManager.callServiceExtensionOnMainIsolate(
      registrations.renderFrameWithRasterStats,
      args: {
        'viewId': viewId,
      },
    );
  }

  Future<double?> get queryDisplayRefreshRate async {
    if (serviceManager.connectedApp == null ||
        !await serviceManager.connectedApp!.isFlutterApp) {
      return null;
    }

    const unknownRefreshRate = 0.0;

    final viewId = await flutterViewId;
    final displayRefreshRateResponse =
        await serviceManager.callServiceExtensionOnMainIsolate(
      registrations.displayRefreshRate,
      args: {'viewId': viewId},
    );
    final double fps = displayRefreshRateResponse.json!['fps'];

    // The Flutter engine returns 0.0 if the refresh rate is unknown. Return
    // [defaultRefreshRate] instead.
    if (fps == unknownRefreshRate) {
      return defaultRefreshRate;
    }

    return fps.roundToDouble();
  }

  Future<void> sendDwdsEvent({
    required String screen,
    required String action,
  }) async {
    final serviceRegistered = serviceManager.registeredMethodsForService
        .containsKey(registrations.dwdsSendEvent);
    if (!serviceRegistered) return;
    await serviceManager.callServiceExtensionOnMainIsolate(
      registrations.dwdsSendEvent,
      args: {
        'type': 'DevtoolsEvent',
        'payload': {
          'screen': screen,
          'action': action,
        },
      },
    );
  }
}
