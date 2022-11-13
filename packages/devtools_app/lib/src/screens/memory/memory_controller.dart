// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../config_specific/file/file.dart';
import '../../config_specific/logger/logger.dart';
import '../../primitives/auto_dispose.dart';
import '../../primitives/utils.dart';
import '../../service/service_extensions.dart';
import '../../service/service_manager.dart';
import '../../shared/globals.dart';
import '../../shared/utils.dart';
import 'memory_protocol.dart';
import 'panes/allocation_profile/allocation_profile_table_view_controller.dart';
import 'panes/diff/controller/diff_pane_controller.dart';
import 'primitives/memory_timeline.dart';
import 'shared/heap/model.dart';

enum ChartType {
  DartHeaps,
  AndroidHeaps,
}

// TODO(terry): Consider supporting more than one file since app was launched.
// Memory Log filename.
final String _memoryLogFilename =
    '${MemoryController.logFilenamePrefix}${DateFormat("yyyyMMdd_HH_mm").format(DateTime.now())}';

/// Automatic pruning of collected memory statistics (plotted) full data is
/// still retained. Default is the best view each tick is 10 pixels, the
/// width of an event symbol e.g., snapshot, monitor, etc.
enum ChartInterval {
  Default,
  OneMinute,
  FiveMinutes,
  TenMinutes,
  All,
}

/// Duration for each ChartInterval.
const displayDurations = <Duration?>[
  Duration.zero, // ChartInterval.Default
  Duration(minutes: 1), // ChartInterval.OneMinute
  Duration(minutes: 5), // ChartInterval.FiveMinutes
  Duration(minutes: 10), // ChartInterval.TenMinutes
  null, // ChartInterval.All
];

Duration? chartDuration(ChartInterval interval) =>
    displayDurations[interval.index];

const displayDefault = 'Default';
const displayAll = 'All';

final displayDurationsStrings = <String>[
  displayDefault,
  chartDuration(ChartInterval.OneMinute)!.inMinutes.toString(),
  chartDuration(ChartInterval.FiveMinutes)!.inMinutes.toString(),
  chartDuration(ChartInterval.TenMinutes)!.inMinutes.toString(),
  displayAll,
];

String displayDuration(ChartInterval interval) =>
    displayDurationsStrings[interval.index];

ChartInterval chartInterval(String displayName) {
  final index = displayDurationsStrings.indexOf(displayName);
  switch (index) {
    case 0:
      assert(index == ChartInterval.Default.index);
      return ChartInterval.Default;
    case 1:
      assert(index == ChartInterval.OneMinute.index);
      return ChartInterval.OneMinute;
    case 2:
      assert(index == ChartInterval.FiveMinutes.index);
      return ChartInterval.FiveMinutes;
    case 3:
      assert(index == ChartInterval.TenMinutes.index);
      return ChartInterval.TenMinutes;
    case 4:
      assert(index == ChartInterval.All.index);
      return ChartInterval.All;
    default:
      return ChartInterval.All;
  }
}

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
    memoryLog = MemoryLog(this);
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

  static const logFilenamePrefix = 'memory_log_';

  /// Root nodes names that contains nodes of either libraries or classes depending on
  /// group by library or group by class.
  static const libraryRootNode = '___LIBRARY___';
  static const classRootNode = '___CLASSES___';

  final _shouldShowLeaksTab = ValueNotifier<bool>(false);
  ValueListenable<bool> get shouldShowLeaksTab => _shouldShowLeaksTab;

  ValueListenable get legendVisibleNotifier => _legendVisibleNotifier;

  final _legendVisibleNotifier = ValueNotifier<bool>(false);

  bool get isLegendVisible => _legendVisibleNotifier.value;

  bool toggleLegendVisibility() =>
      _legendVisibleNotifier.value = !_legendVisibleNotifier.value;

  late MemoryTimeline memoryTimeline;

  late MemoryLog memoryLog;

  /// Source of memory heap samples. False live data, True loaded from a
  /// memory_log file.
  final offline = ValueNotifier<bool>(false);

  HeapSample? _selectedDartSample;

  HeapSample? _selectedAndroidSample;

  HeapSample? getSelectedSample(ChartType type) => type == ChartType.DartHeaps
      ? _selectedDartSample
      : _selectedAndroidSample;

  void setSelectedSample(ChartType type, HeapSample sample) {
    if (type == ChartType.DartHeaps) {
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

  /// Starting chunk for slider based on the intervalDurationInMs.
  double sliderValue = 1.0;

  /// Number of interval stops for the timeline slider e.g., for 15 minutes of
  /// collected data, displayed at a 5 minute interval there will be 3 stops,
  /// each stop would be 5 minutes prior to the previous stop.
  int numberOfStops = 0;

  /// Compute total timeline stops used by Timeline slider.
  int computeStops() {
    int stops = 0;
    if (memoryTimeline.data.isNotEmpty) {
      final lastSampleTimestamp = memoryTimeline.data.last.timestamp.toDouble();
      final firstSampleTimestamp =
          memoryTimeline.data.first.timestamp.toDouble();
      stops =
          ((lastSampleTimestamp - firstSampleTimestamp) / intervalDurationInMs)
              .round();
    }
    return stops == 0 ? 1 : stops;
  }

  /// Default is to display default tick width based on width of chart of the collected
  /// data in the chart.
  final _displayIntervalNotifier =
      ValueNotifier<ChartInterval>(ChartInterval.Default);

  ValueListenable<ChartInterval> get displayIntervalNotifier =>
      _displayIntervalNotifier;

  set displayInterval(ChartInterval interval) {
    _displayIntervalNotifier.value = interval;
  }

  ChartInterval get displayInterval => _displayIntervalNotifier.value;

  /// 1 minute in milliseconds.
  static const int minuteInMs = 60 * 1000;

  static int displayIntervalToIntervalDurationInMs(ChartInterval interval) {
    return interval == ChartInterval.All
        ? maxJsInt
        : chartDuration(interval)!.inMilliseconds;
  }

  /// Return the pruning interval in milliseconds.
  int get intervalDurationInMs =>
      displayIntervalToIntervalDurationInMs(displayInterval);

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

  final _updateClassStackTraces = ValueNotifier(0);

  ValueListenable<int> get updateClassStackTraces => _updateClassStackTraces;

  void changeStackTraces() {
    _updateClassStackTraces.value += 1;
  }

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
        .hasServiceExtension(memoryLeakTracking)
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

  /// Source file name as returned from allocation's stacktrace.
  /// Map source URI
  ///    packages/flutter/lib/src/widgets/image.dart
  /// would map to
  ///    package:flutter/src/widgets/image.dart
  // TODO(terry): Review with Ben pathing doesn't quite work the source
  //              file has the lib/ maybe a LibraryRef could be returned
  //              if it's a package today all packages are file:///? Also,
  //              would be nice to have a line # too for the source.
  //
  //              When line # and package mapping exist ability to navigate
  //              to line number of the source file when clicked is needed.
  static const packageName = '/packages/';

  Future getObject(String objectRef) async =>
      await serviceManager.service!.getObject(
        _isolateId!,
        objectRef,
      );

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

/// Index in datasets to each dataset's list of Entry's.
enum ChartDataSets {
  // Datapoint entries for each used heap value.
  usedSet,
  // Datapoint entries for each capacity heap value.
  capacitySet,
  // Datapoint entries for each external memory value.
  externalHeapSet,
  // Datapoint entries for each RSS value.
  rssSet,
  rasterLayerSet,
  rasterPictureSet,
}

/// Index in datasets to each dataset's list of Entry's.
enum EventDataSets {
  // Datapoint entries for ghost trace to stop auto-scaling of Y-axis.
  ghostsSet,
  // Datapoint entries for each user initiated GC.
  gcUserSet,
  // Datapoint entries for a VM's GC.
  gcVmSet,
  // Datapoint entries for each user initiated snapshot event.
  snapshotSet,
  // Datapoint entries for an automatically initiated snapshot event.
  snapshotAutoSet,
  // Allocation Accumulator monitoring.
  monitorStartSet,
  // TODO(terry): Allocation Accumulator continues UX connector.
  monitorContinuesSet,
  // Reset all Allocation Accumulators.
  monitorResetSet,
}

/// Supports saving and loading memory samples.
class MemoryLog {
  MemoryLog(this.controller);

  /// Use in memory or local file system based on Flutter Web/Desktop.
  static final _fs = FileIO();

  MemoryController controller;

  /// Persist the the live memory data to a JSON file in the /tmp directory.
  List<String> exportMemory() {
    ga.select(analytics_constants.memory, analytics_constants.export);

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
