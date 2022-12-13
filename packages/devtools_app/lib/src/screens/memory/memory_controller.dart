// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:leak_tracker/devtools_integration.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/service_manager.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/config_specific/file/file.dart';
import '../../shared/config_specific/logger/logger.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/utils.dart';
import 'memory_protocol.dart';
import 'panes/allocation_profile/allocation_profile_table_view_controller.dart';
import 'panes/chart/primitives.dart';
import 'panes/diff/controller/diff_pane_controller.dart';
import 'shared/heap/model.dart';
import 'shared/primitives/memory_timeline.dart';

// TODO(terry): Consider supporting more than one file since app was launched.
// Memory Log filename.
final String _memoryLogFilename =
    '${MemoryController.logFilenamePrefix}${DateFormat("yyyyMMdd_HH_mm").format(DateTime.now())}';

class OfflineFileException implements Exception {
  OfflineFileException(this.message) : super();

  final String message;

  @override
  String toString() => message;
}

/// This class contains the business logic for [memory.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM.
class MemoryController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryController({DiffPaneController? diffPaneController}) {
    memoryTimeline = MemoryTimeline(offline);
    memoryLog = _MemoryLog(this);
    this.diffPaneController =
        diffPaneController ?? DiffPaneController(SnapshotTaker());

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(memorySourceNotifier, () async {
      try {
        await updatedMemorySource();
      } catch (e) {
        final errorMessage = '$e';
        memorySource = MemoryController.liveFeed;
        notificationService.push(errorMessage);
      }

      refreshAllCharts();
    });
  }

  /// The controller is late to enable test injection.
  late final DiffPaneController diffPaneController;

  /// Controller for [AllocationProfileTableView].
  final allocationProfileController = AllocationProfileTableViewController();

  /// Index of the selected feature tab.
  ///
  /// This value is used to set the initial tab selection of the
  /// [MemoryTabView]. This widget will be disposed and re-initialized on
  /// DevTools screen changes, so we must store this value in the controller
  /// instead of the widget state.
  int selectedFeatureTabIndex = 0;

  static const logFilenamePrefix = 'memory_log_';

  final _shouldShowLeaksTab = ValueNotifier<bool>(false);
  ValueListenable<bool> get shouldShowLeaksTab => _shouldShowLeaksTab;

  late MemoryTimeline memoryTimeline;

  late _MemoryLog memoryLog;

  /// Source of memory heap samples. False live data, True loaded from a
  /// memory_log file.
  final offline = ValueNotifier<bool>(false);

  HeapSample? _selectedDartSample;

  HeapSample? _selectedAndroidSample;

  HeapSample? getSelectedSample(ChartType type) => type == ChartType.dartHeaps
      ? _selectedDartSample
      : _selectedAndroidSample;

  void setSelectedSample(ChartType type, HeapSample sample) {
    if (type == ChartType.dartHeaps) {
      _selectedDartSample = sample;
    } else {
      _selectedAndroidSample = sample;
    }
  }

  static const liveFeed = 'Live Feed';

  String? memorySourcePrefix;

  /// Notifies that the source of the memory feed has changed.
  ValueListenable get memorySourceNotifier => _memorySourceNotifier;

  final _memorySourceNotifier = ValueNotifier<String>(liveFeed);

  set memorySource(String source) {
    _memorySourceNotifier.value = source;
  }

  String get memorySource => _memorySourceNotifier.value;

  ValueListenable get refreshCharts => _refreshCharts;

  final _refreshCharts = ValueNotifier<int>(0);

  void refreshAllCharts() {
    _refreshCharts.value++;
    _updateAndroidChartVisibility();
  }

  /// Default is to display default tick width based on width of chart of the collected
  /// data in the chart.
  final _displayIntervalNotifier =
      ValueNotifier<ChartInterval>(ChartInterval.theDefault);

  ValueListenable<ChartInterval> get displayIntervalNotifier =>
      _displayIntervalNotifier;

  set displayInterval(ChartInterval interval) {
    _displayIntervalNotifier.value = interval;
  }

  ChartInterval get displayInterval => _displayIntervalNotifier.value;

  /// MemorySource has changed update the view.
  /// Return value of null implies offline file loaded.
  /// Return value of String is an error message.
  Future<void> updatedMemorySource() async {
    if (memorySource == MemoryController.liveFeed) {
      if (offline.value) {
        // User is switching back to 'Live Feed'.
        memoryTimeline.offlineData.clear();
        offline.value = false; // We're live again...
      } else {
        // Still a live feed - keep collecting.
        assert(!offline.value);
      }
    } else {
      // Switching to an offline memory log (JSON file in /tmp).
      await memoryLog.loadOffline(memorySource).catchError((e) {
        throw OfflineFileException(e.toString());
      });
    }

    _updateAndroidChartVisibility();
  }

  final _paused = ValueNotifier<bool>(false);

  ValueListenable<bool> get paused => _paused;

  void pauseLiveFeed() {
    _paused.value = true;
  }

  void resumeLiveFeed() {
    _paused.value = false;
  }

  bool get isPaused => _paused.value;

  final isAndroidChartVisibleNotifier = ValueNotifier<bool>(false);

  String? get _isolateId =>
      serviceManager.isolateManager.selectedIsolate.value?.id;

  final StreamController<MemoryTracker?> _memoryTrackerController =
      StreamController<MemoryTracker?>.broadcast();

  Stream<MemoryTracker?> get onMemory => _memoryTrackerController.stream;

  Stream<void> get onDisconnect => _disconnectController.stream;
  final _disconnectController = StreamController<void>.broadcast();

  MemoryTracker? _memoryTracker;

  MemoryTracker? get memoryTracker => _memoryTracker;

  bool get hasStarted => _memoryTracker != null;

  bool hasStopped = false;

  void _handleIsolateChanged() {
    // TODO(terry): Need an event on the controller for this too?
  }

  void _refreshShouldShowLeaksTab() {
    _shouldShowLeaksTab.value = serviceManager.serviceExtensionManager
        .hasServiceExtension(memoryLeakTrackingExtensionName)
        .value;
  }

  void _handleConnectionStart(ServiceConnectionManager serviceManager) async {
    _refreshShouldShowLeaksTab();
    if (_memoryTracker == null) {
      _memoryTracker = MemoryTracker(this);
      _memoryTracker!.start();
    }

    // Log Flutter extension events.
    // Note: We do not need to listen to event history here because we do not
    // have matching historical data about total memory usage.
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEvent.listen((Event event) {
        var extensionEventKind = event.extensionKind;
        String? customEventKind;
        if (MemoryTimeline.isCustomEvent(event.extensionKind!)) {
          extensionEventKind = MemoryTimeline.devToolsExtensionEvent;
          customEventKind =
              MemoryTimeline.customEventName(event.extensionKind!);
        }
        final jsonData = event.extensionData!.data.cast<String, Object>();
        // TODO(terry): Display events enabled in a settings page for now only these events.
        switch (extensionEventKind) {
          case 'Flutter.ImageSizesForFrame':
            memoryTimeline.addExtensionEvent(
              event.timestamp,
              event.extensionKind,
              jsonData,
            );
            break;
          case MemoryTimeline.devToolsExtensionEvent:
            memoryTimeline.addExtensionEvent(
              event.timestamp,
              MemoryTimeline.customDevToolsEvent,
              jsonData,
              customEventName: customEventKind,
            );
            break;
        }
      }),
    );

    autoDisposeStreamSubscription(
      _memoryTracker!.onChange.listen((_) {
        _memoryTrackerController.add(_memoryTracker);
      }),
    );
    autoDisposeStreamSubscription(
      _memoryTracker!.onChange.listen((_) {
        _memoryTrackerController.add(_memoryTracker);
      }),
    );

    // TODO(terry): Used to detect stream being closed from the
    // memoryController dispose method.  Needed when a HOT RELOAD
    // will call dispose however, spinup (initState) doesn't seem
    // to happen David is working on scaffolding.
    _memoryTrackerController.stream.listen(
      (_) {},
      onDone: () {
        // Stop polling and reset memoryTracker.
        _memoryTracker?.stop();
        _memoryTracker = null;
      },
    );

    _updateAndroidChartVisibility();
    addAutoDisposeListener(
      preferences.memory.androidCollectionEnabled,
      _updateAndroidChartVisibility,
    );
  }

  void _updateAndroidChartVisibility() {
    final bool isOfflineAndAndroidData =
        offline.value && memoryTimeline.data.first.adbMemoryInfo.realtime > 0;

    final bool isConnectedToAndroidAndAndroidEnabled =
        isConnectedDeviceAndroid &&
            preferences.memory.androidCollectionEnabled.value;

    isAndroidChartVisibleNotifier.value =
        isOfflineAndAndroidData || isConnectedToAndroidAndAndroidEnabled;
  }

  void _handleConnectionStop(dynamic event) {
    _memoryTracker?.stop();
    _memoryTrackerController.add(_memoryTracker);

    _disconnectController.add(null);
    hasStopped = true;
  }

  Future<void> startTimeline() async {
    addAutoDisposeListener(
      serviceManager.isolateManager.selectedIsolate,
      _handleIsolateChanged,
    );

    autoDisposeStreamSubscription(
      serviceManager.onConnectionAvailable
          .listen((_) => _handleConnectionStart(serviceManager)),
    );
    if (serviceManager.connectedAppInitialized) {
      _handleConnectionStart(serviceManager);
    }
    autoDisposeStreamSubscription(
      serviceManager.onConnectionClosed.listen(_handleConnectionStop),
    );
  }

  void stopTimeLine() {
    _memoryTracker?.stop();
  }

  bool get isConnectedDeviceAndroid {
    return serviceManager.vm?.operatingSystem == 'android';
  }

  bool get isGcing => _gcing;
  bool _gcing = false;

  Future<void> gc() async {
    _gcing = true;
    try {
      await serviceManager.service!.getAllocationProfile(
        _isolateId!,
        gc: true,
      );
      notificationService.push('Successfully garbage collected.');
    } finally {
      _gcing = false;
    }
  }

  /// Detect stale isolates (sentinaled), may happen after a hot restart.
  Future<bool> isIsolateLive(String isolateId) async {
    try {
      final service = serviceManager.service!;
      await service.getIsolate(isolateId);
    } catch (e) {
      if (e is SentinelException) {
        final SentinelException sentinelErr = e;
        final message = 'isIsolateLive: Isolate sentinel $isolateId '
            '${sentinelErr.sentinel.kind}';
        debugLogger(message);
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    _displayIntervalNotifier.dispose();
    _memorySourceNotifier.dispose();
    unawaited(_disconnectController.close());
    unawaited(_memoryTrackerController.close());
    _memoryTracker?.dispose();
  }
}

/// Supports saving and loading memory samples.
class _MemoryLog {
  _MemoryLog(this.controller);

  /// Use in memory or local file system based on Flutter Web/Desktop.
  static final _fs = FileIO();

  MemoryController controller;

  /// Persist the the live memory data to a JSON file in the /tmp directory.
  List<String> exportMemory() {
    ga.select(gac.memory, gac.export);

    final liveData = controller.memoryTimeline.liveData;

    bool pseudoData = false;
    if (liveData.isEmpty) {
      // Used to create empty memory log for test.
      pseudoData = true;
      liveData.add(
        HeapSample(
          DateTime.now().millisecondsSinceEpoch,
          0,
          0,
          0,
          0,
          false,
          AdbMemoryInfo.empty(),
          EventSample.empty(),
          RasterCache.empty(),
        ),
      );
    }

    final jsonPayload = SamplesMemoryJson.encodeList(liveData);
    if (kDebugMode) {
      // TODO(terry): Remove this check add a unit test instead.
      // Reload the file just created and validate that the saved data matches
      // the live data.
      final memoryJson = SamplesMemoryJson.decode(argJsonString: jsonPayload);
      assert(memoryJson.isMatchedVersion);
      assert(memoryJson.isMemoryPayload);
      assert(memoryJson.data.length == liveData.length);
    }

    _fs.writeStringToFile(_memoryLogFilename, jsonPayload, isMemory: true);

    if (pseudoData) liveData.clear();

    return [_fs.exportDirectoryName(isMemory: true), _memoryLogFilename];
  }

  /// Return a list of offline memory logs filenames in the /tmp directory
  /// that are available to open.
  List<String> offlineFiles() {
    final memoryLogs = _fs.list(
      prefix: MemoryController.logFilenamePrefix,
      isMemory: true,
    );

    // Sort by newest file top-most (DateTime is in the filename).

    memoryLogs.sort((a, b) => b.compareTo(a));

    return memoryLogs;
  }

  /// Load the memory profile data from a saved memory log file.
  @visibleForTesting
  Future<void> loadOffline(String filename) async {
    final jsonPayload = _fs.readStringFromFile(filename, isMemory: true)!;

    final memoryJson = SamplesMemoryJson.decode(argJsonString: jsonPayload);

    if (!memoryJson.isMatchedVersion) {
      final e =
          'Error loading file $filename version ${memoryJson.payloadVersion}';
      log(e, LogLevel.warning);
      throw OfflineFileException(e);
    }

    assert(memoryJson.isMemoryPayload);

    controller.offline.value = true;
    controller.memoryTimeline.offlineData.clear();
    controller.memoryTimeline.offlineData.addAll(memoryJson.data);
  }

  @visibleForTesting
  bool removeOfflineFile(String filename) =>
      _fs.deleteFile(filename, isMemory: true);
}
