// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose.dart';
import '../config_specific/file/file.dart';
import '../config_specific/logger/logger.dart';
import '../globals.dart';
import '../service_manager.dart';
import '../table.dart';
import '../table_data.dart';
import '../ui/search.dart';
import '../utils.dart';
import '../version.dart';
import 'memory_filter.dart';
import 'memory_graph_model.dart';
import 'memory_protocol.dart';
import 'memory_screen.dart';
import 'memory_service.dart';
import 'memory_snapshot_models.dart';
import 'memory_timeline.dart';

enum ChartType {
  DartHeaps,
  AndroidHeaps,
}

// TODO(terry): Consider supporting more than one file since app was launched.
// Memory Log filename.
final String _memoryLogFilename =
    '${MemoryController.logFilenamePrefix}${DateFormat("yyyyMMdd_hh_mm").format(DateTime.now())}';

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
const displayDurations = <Duration>[
  Duration.zero, // ChartInterval.Default
  Duration(minutes: 1), // ChartInterval.OneMinute
  Duration(minutes: 5), // ChartInterval.FiveMinutes
  Duration(minutes: 10), // ChartInterval.TenMinutes
  null, // ChartInterval.All
];

Duration chartDuration(ChartInterval interval) =>
    displayDurations[interval.index];

const displayDefault = 'Default';
const displayAll = 'All';

final displayDurationsStrings = <String>[
  displayDefault,
  chartDuration(ChartInterval.OneMinute).inMinutes.toString(),
  chartDuration(ChartInterval.FiveMinutes).inMinutes.toString(),
  chartDuration(ChartInterval.TenMinutes).inMinutes.toString(),
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
      assert(false);
      return null;
  }
}

class OfflineFileException implements Exception {
  OfflineFileException(this.message) : super();

  final String message;

  @override
  String toString() => message;
}

class AllocationStackTrace {
  AllocationStackTrace(CpuSample sample, {List<ProfileFunction> functions}) {
    computeStacktrace(sample, functions: functions);
  }

  int timestamp;

  var showFullStacktrace = false;

  final stacktrace = <String>[];

  final sources = <String>[];

  int get stackDepth => stacktrace.length;

  static const NoClasses = 0;
  static const DartClasses = 1;
  static const FlutterClasses = 2;

  static const DartFlutterClasses = DartClasses | FlutterClasses;

  bool hideDartClasses(int hideClasses) =>
      hideClasses & DartClasses == DartClasses;
  bool hideFlutterClasses(int hideClasses) =>
      hideClasses & FlutterClasses == FlutterClasses;

  /// Display stacktrace format is:
  ///    [className.functionName]
  /// [maxLines] default is 4, if -1 then display all lines
  String stacktraceDisplay({
    int maxLines = 4,
    int hideClasses = DartFlutterClasses,
  }) {
    final buffer = StringBuffer();
    var lines = 0;
    for (var stackEntry in stacktrace) {
      if (maxLines == -1 || lines++ < maxLines) {
        buffer.writeln('- $stackEntry');
      }
    }

    return buffer.toString();
  }

  String get sourcesDisplay => sources.join('\r');

  void computeStacktrace(CpuSample cpuSample,
      {List<ProfileFunction> functions}) {
    if (cpuSample.stack.isNotEmpty) {
      final stackLength = cpuSample.stack.length;
      for (var stackIndex = 0; stackIndex < stackLength; stackIndex++) {
        final functionId = cpuSample.stack[stackIndex];
        final ProfileFunction profileFunc = functions[functionId];
        String ownerName;
        String functionName;
        if (profileFunc.function is FuncRef) {
          final FuncRef funcRef = profileFunc.function;
          if (funcRef.owner is ClassRef) {
            final ClassRef classRef = funcRef.owner;
            ownerName = classRef.name;
          } else if (funcRef.owner is LibraryRef) {
            final LibraryRef libraryRef = funcRef.owner;
            ownerName = libraryRef.name;
          } else {
            assert(funcRef.owner is FuncRef);
            final FuncRef fRef = funcRef.owner;
            ownerName = '${fRef.name}.';
          }
          functionName = funcRef.name;
        } else {
          final NativeFunction nativeFunction = profileFunc.function;
          ownerName = '';
          functionName = nativeFunction.name;
        }

        // Skip any internal binding names e.g.,
        // _WidgetsFlutterBinding&BindingBase&GestureBinding&SchedulerBinding...
        if (!ownerName.contains('&')) {
          timestamp = cpuSample.timestamp;
          if (ownerName == '<anonymous closure>.' &&
              functionName == '<anonymous closure>') {
            stacktrace.add(functionName);
          } else {
            stacktrace.add('$ownerName.$functionName');
          }
          sources.add(profileFunc.resolvedUrl);
        }
      }
    }
  }
}

class AllocationSamples {
  AllocationSamples(this.classRef, CpuSamples cpuSamples) {
    _computeCpuSamples(cpuSamples);
  }

  final ClassRef classRef;

  final stacktraces = <AllocationStackTrace>[];

  int get totalStacktraces => stacktraces?.length;

  void _computeCpuSamples(CpuSamples cpuSamples) {
    final samplesLength = cpuSamples.samples.length;
    for (var index = 0; index < samplesLength; index++) {
      final cpuSample = cpuSamples.samples[index];
      if (cpuSample.stack.isNotEmpty) {
        stacktraces.add(
          AllocationStackTrace(
            cpuSample,
            functions: cpuSamples.functions,
          ),
        );
      }
    }
  }
}

/// This class contains the business logic for [memory.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM.
class MemoryController extends DisposableController
    with
        AutoDisposeControllerMixin,
        SearchControllerMixin,
        AutoCompleteSearchControllerMixin {
  MemoryController() {
    memoryTimeline = MemoryTimeline(this);
    memoryLog = MemoryLog(this);

    /// package:vm_service version 6.1.0+1 updated the VM Service protocol version
    /// to 3.43.0. This changed snapshot indexes for classes, instances and
    /// sentinels.  Primarily classes are indexed by a 0 based index not (1-based).
    newSnapshotSemantics = serviceManager.service.isProtocolVersionSupportedNow(
        supportedVersion: SemanticVersion(major: 3, minor: 43));
  }

  bool newSnapshotSemantics;

  static const logFilenamePrefix = 'memory_log_';

  // Default state of Android ADB collection.
  static const androidADBDefault = true;

  ValueListenable<bool> get androidCollectionEnabled =>
      _androidCollectionEnabled;

  final _androidCollectionEnabled = ValueNotifier<bool>(androidADBDefault);

  // Default state of advanced settings enabled.
  static const advancedSettingsEnabledDefault = false;

  ValueListenable<bool> get advancedSettingsEnabled => _advancedSettingsEnabled;

  final _advancedSettingsEnabled =
      ValueNotifier<bool>(advancedSettingsEnabledDefault);

  // Memory statistics displayed as raw numbers or units (KB, MB, GB).
  static const unitDisplayedDefault = true;

  ValueListenable<bool> get unitDisplayed => _unitDisplayed;

  final _unitDisplayed = ValueNotifier<bool>(unitDisplayedDefault);

  final List<Snapshot> snapshots = [];

  Snapshot get lastSnapshot => snapshots.safeLast;

  /// Root nodes names that contains nodes of either libraries or classes depending on
  /// group by library or group by class.
  static const libraryRootNode = '___LIBRARY___';
  static const classRootNode = '___CLASSES___';

  /// Notifies that the source of the memory feed has changed.
  ValueListenable<DateTime> get selectedSnapshotNotifier =>
      _selectedSnapshotNotifier;

  static String formattedTimestamp(DateTime timestamp) =>
      timestamp != null ? DateFormat('MMM dd hh:mm:ss').format(timestamp) : '';

  /// Stored value is pretty timestamp when the snapshot was done.
  final _selectedSnapshotNotifier = ValueNotifier<DateTime>(null);

  set selectedSnapshotTimestamp(DateTime snapshotTimestamp) {
    _selectedSnapshotNotifier.value = snapshotTimestamp;
  }

  DateTime get selectedSnapshotTimestamp => _selectedSnapshotNotifier.value;

  HeapGraph heapGraph;

  /// Leaf node of tabletree snapshot selected?  If selected then the instance
  /// view is displayed to view the fields of an instance.
  final _leafSelectedNotifier = ValueNotifier<HeapGraphElementLive>(null);

  ValueListenable<HeapGraphElementLive> get leafSelectedNotifier =>
      _leafSelectedNotifier;

  HeapGraphElementLive get selectedLeaf => _leafSelectedNotifier.value;

  set selectedLeaf(HeapGraphElementLive selected) {
    _leafSelectedNotifier.value = selected;
  }

  bool get isLeafSelected => selectedLeaf != null;

  void computeRoot() {
    if (selectedLeaf != null) {
      final root = instanceToFieldNodes(this, selectedLeaf);
      _instanceRoot = root.isNotEmpty ? root : [FieldReference.empty];
    } else {
      _instanceRoot = [FieldReference.empty];
    }
  }

  List<FieldReference> _instanceRoot;

  List<FieldReference> get instanceRoot => _instanceRoot;

  /// Leaf node of analysis selected?  If selected then the field
  /// view is displayed to view an abbreviated fields of an instance.
  final _leafAnalysisSelectedNotifier = ValueNotifier<AnalysisInstance>(null);

  ValueListenable<AnalysisInstance> get leafAnalysisSelectedNotifier =>
      _leafAnalysisSelectedNotifier;

  AnalysisInstance get selectedAnalysisLeaf =>
      _leafAnalysisSelectedNotifier.value;

  set selectedAnalysisLeaf(AnalysisInstance selected) {
    _leafAnalysisSelectedNotifier.value = selected;
  }

  bool get isAnalysisLeafSelected => selectedAnalysisLeaf != null;

  void computeAnalysisInstanceRoot() {
    if (selectedAnalysisLeaf != null) {
      final analysisFields = selectedAnalysisLeaf.fieldsRoot.children;
      _analysisInstanceRoot =
          analysisFields.isNotEmpty ? analysisFields : [AnalysisField.empty];
    } else {
      _analysisInstanceRoot = [AnalysisField.empty];
    }
  }

  List<AnalysisField> _analysisInstanceRoot;

  List<AnalysisField> get analysisInstanceRoot => _analysisInstanceRoot;

  // List of completed Analysis of Snapshots.
  final List<AnalysisSnapshotReference> completedAnalyses = [];

  /// Determine the snapshot to analyze - current active snapshot (selected or node
  /// under snapshot selected), last snapshot or null (unknown).
  Snapshot get computeSnapshotToAnalyze {
    // Any snapshots to analyze?
    if (snapshots.isEmpty) return null;

    // Is a selected table row under a snapshot.
    final nodeSelected = selectionSnapshotNotifier.value.node;
    final snapshot = getSnapshot(nodeSelected);
    if (snapshot != null) {
      // Has the snapshot (with a selected row) been analyzed?
      return _findSnapshotAnalyzed(snapshot);
    }

    final snapshotsCount = snapshots.length;
    final analysesCount = completedAnalyses.length;

    // Exactly one analysis is left? Ff the 'Analysis' button is pressed the
    // snapshot that is left will be processed (usually the last one). More
    // than one snapshots to analyze, the user must select the snapshot to
    // analyze.
    if (snapshotsCount > analysesCount &&
        snapshotsCount == (analysesCount + 1)) {
      // Has the last snapshot been analyzed?
      return _findSnapshotAnalyzed(lastSnapshot);
    }

    return null;
  }

  /// Has the snapshot been analyzed, if not return the snapshot otherwise null.
  Snapshot _findSnapshotAnalyzed(Snapshot snapshot) {
    final snapshotDateTime = snapshot.collectedTimestamp;
    final foundMatch = completedAnalyses
        .where((analysis) => analysis.dateTime == snapshotDateTime);
    if (foundMatch.isEmpty) return snapshot;

    return null;
  }

  ValueListenable get treeMapVisible => _treeMapVisible;

  final _treeMapVisible = ValueNotifier<bool>(false);

  void toggleTreeMapVisible(bool value) {
    _treeMapVisible.value = value;
  }

  bool isAnalyzeButtonEnabled() => computeSnapshotToAnalyze != null;

  ValueListenable get legendVisibleNotifier => _legendVisibleNotifier;

  final _legendVisibleNotifier = ValueNotifier<bool>(false);

  bool get isLegendVisible => _legendVisibleNotifier.value;

  bool toggleLegendVisibility() =>
      _legendVisibleNotifier.value = !_legendVisibleNotifier.value;

  MemoryTimeline memoryTimeline;

  MemoryLog memoryLog;

  /// Source of memory heap samples. False live data, True loaded from a
  /// memory_log file.
  bool offline = false;

  HeapSample _selectedDartSample;

  HeapSample _selectedAndroidSample;

  HeapSample getSelectedSample(ChartType type) => type == ChartType.DartHeaps
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

  String memorySourcePrefix;

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
        : chartDuration(interval).inMilliseconds;
  }

  /// Return the pruning interval in milliseconds.
  int get intervalDurationInMs =>
      displayIntervalToIntervalDurationInMs(displayInterval);

  /// MemorySource has changed update the view.
  /// Return value of null implies offline file loaded.
  /// Return value of String is an error message.
  Future<void> updatedMemorySource() async {
    if (memorySource == MemoryController.liveFeed) {
      if (offline) {
        // User is switching back to 'Live Feed'.
        memoryTimeline.offlineData.clear();
        offline = false; // We're live again...
      } else {
        // Still a live feed - keep collecting.
        assert(!offline);
      }
    } else {
      // Switching to an offline memory log (JSON file in /tmp).
      await memoryLog.loadOffline(memorySource).catchError((e) {
        throw OfflineFileException(e.toString());
      });
    }
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

  final _androidChartVisibleNotifier = ValueNotifier<bool>(false);

  ValueListenable get androidChartVisibleNotifier =>
      _androidChartVisibleNotifier;

  bool get isAndroidChartVisible => _androidChartVisibleNotifier.value;

  bool toggleAndroidChartVisibility() =>
      _androidChartVisibleNotifier.value = !_androidChartVisibleNotifier.value;

  bool get isAdvancedSettingsVisible => _advancedSettingsEnabled.value;

  bool toggleAdvancedSettingsVisibility() =>
      _advancedSettingsEnabled.value = !_advancedSettingsEnabled.value;

  final SettingsModel settings = SettingsModel();

  final selectionSnapshotNotifier =
      ValueNotifier<Selection<Reference>>(Selection<Reference>());

  /// Tree to view Libary/Class/Instance (grouped by)
  TreeTable<Reference> groupByTreeTable;

  /// Tree to view fields of an instance.
  TreeTable<FieldReference> instanceFieldsTreeTable;

  /// Tree to view fields of an analysis.
  TreeTable<AnalysisField> analysisFieldsTreeTable;

  final _updateClassStackTraces = ValueNotifier(0);

  ValueListenable<int> get updateClassStackTraces => _updateClassStackTraces;

  void changeStackTraces() {
    _updateClassStackTraces.value += 1;
  }

  /// Tracking memory allocation of classes.
  /// Format key is Class name and value is ClassRef.
  final trackAllocations = <String, ClassRef>{};

  /// Set up the class to be tracked.
  void setTracking(ClassRef classRef, bool enable) {
    final foundClass = monitorAllocations.firstWhere(
      (element) => element.classRef == classRef,
      orElse: () => null,
    );

    if (foundClass != null) {
      foundClass.isStacktraced = enable;

      final classRef = foundClass.classRef;
      _setTracking(classRef, enable).catchError((e) {
        debugLogger('ERROR: ${e.message}');
      }).whenComplete(
        () {
          changeStackTraces();
          treeChanged();
          // TODO(terry): Add a toast popup.
        },
      );
    }
  }

  /// Track where/when a class is allocated (constructor new'd).
  Future<void> _setTracking(ClassRef ref, bool enable) async {
    if (!await isIsolateLive(_isolateId)) return;

    final Success returnObject =
        await serviceManager.service.setTraceClassAllocation(
      _isolateId,
      ref.id,
      enable,
    );

    if (returnObject.type != 'Success') {
      debugLogger('Failed setTraceClassAllocation ${ref.name}');
      return;
    }

    if (enable) {
      if (trackAllocations.containsKey(ref.name)) {
        // Somehow, already enabled don't enable again.
        assert(trackAllocations[ref.name] == ref);
        return;
      }
      // Add to tracking list.
      trackAllocations[ref.name] = ref;
    } else {
      // Remove from tracking list.
      assert(trackAllocations.containsKey(ref.name));
      trackAllocations.remove(ref.name);
    }
  }

  /// Track where/when a particular class is allocated (constructor new'd).
  Future<CpuSamples> getAllocationTraces(ClassRef ref) async {
    if (!await isIsolateLive(_isolateId)) return null;
    final returnObject = await serviceManager.service.getAllocationTraces(
      _isolateId,
      classId: ref.id,
    );

    return returnObject;
  }

  final _allAllocationSamples = <ClassRef, CpuSamples>{};

  List<AllocationSamples> allocationSamples = [];

  /// Any new allocations being tracked.
  Future<Map<ClassRef, CpuSamples>> computeAllAllocationSamples() async {
    _allAllocationSamples.clear();

    final keys = trackAllocations.keys;
    for (var key in keys) {
      // TODO(terry): Need to process output.
      final samples = await getAllocationTraces(trackAllocations[key]);
      if (samples != null) {
        _allAllocationSamples[trackAllocations[key]] = samples;
      }
    }

    return _allAllocationSamples;
  }

  /// Table to view fields of an Allocation Profile.
  FlatTable<ClassHeapDetailStats> allocationsFieldsTable;

  /// State of filters used by filter dialog (create/modify) and used
  /// by filtering in grouping.
  final FilteredLibraries libraryFilters = FilteredLibraries();

  /// All known libraries of the selected snapshot.
  LibraryReference get libraryRoot {
    if (selectionSnapshotNotifier.value == null) {
      // No selectied snapshot use last snapshot.
      return snapshots.safeLast.libraryRoot;
    }

    // Find the selected snapshot's libraryRoot.
    final snapshot = getSnapshot(selectionSnapshotNotifier.value.node);
    if (snapshot != null) return snapshot.libraryRoot;

    return null;
  }

  /// Re-compute the libraries (possible filter change).
  set libraryRoot(LibraryReference newRoot) {
    Snapshot snapshot;

    // Use last snapshot.
    if (snapshots.isNotEmpty) {
      snapshot = snapshots.safeLast;
    }

    // Find the selected snapshot's libraryRoot.
    snapshot ??= getSnapshot(selectionSnapshotNotifier.value.node);
    snapshot?.libraryRoot = newRoot;
  }

  /// Using the tree table find the active snapshot (selected or last snapshot).
  SnapshotReference get activeSnapshot {
    for (final topLevel in groupByTreeTable.dataRoots) {
      if (topLevel is SnapshotReference) {
        final nodeSelected = selectionSnapshotNotifier.value.node;
        final snapshot = getSnapshot(nodeSelected);
        final SnapshotReference snapshotRef = topLevel;
        if (snapshot != null &&
            snapshotRef.snapshot.collectedTimestamp ==
                snapshot.collectedTimestamp) {
          return topLevel;
        }
      }
    }

    // No selected snapshot so return the last snapshot.
    final lastSnapshot = groupByTreeTable.dataRoots.safeLast;
    assert(lastSnapshot is SnapshotReference);

    return lastSnapshot;
  }

  /// Given a node return its snapshot.
  Snapshot getSnapshot(Reference reference) {
    while (reference != null) {
      if (reference is SnapshotReference) {
        final SnapshotReference snapshotRef = reference;
        return snapshotRef.snapshot;
      }
      reference = reference.parent;
    }

    return null;
  }

  /// Root node of all known analysis and snapshots.
  LibraryReference topNode;

  /// Root of known classes (used for group by class).
  LibraryReference classRoot;

  /// Used by the filter dialog, grouped name displayed in filter dialog
  /// e.g., dart:*, package:flutter/*
  ///
  /// The key is the group name (displayed in dialog), value is list of
  /// libraries associated to the group. Structure is used to:
  ///    - allow user to hide/show a library when filtering a snapshot.
  ///    - create the hide list of libraries to drive the UX on when showing
  ///      list of libraries/classes/objects in a snapshot table.
  final filteredLibrariesByGroupName = <String, List<LibraryFilter>>{};

  /// Notify that the filtering has changed.
  ValueListenable<int> get filterNotifier => _filterNotifier;

  final _filterNotifier = ValueNotifier<int>(0);

  void updateFilter() {
    _filterNotifier.value++;
  }

  /// Hide any class that hasn't been constructed (zero instances).
  final filterZeroInstances = ValueNotifier(true);

  ValueListenable<bool> get filterZeroInstancesListenable =>
      filterZeroInstances;

  /// Hide any private class, prefixed with an underscore.
  final filterPrivateClasses = ValueNotifier(true);

  ValueListenable<bool> get filterPrivateClassesListenable =>
      filterPrivateClasses;

  /// Hide any library with no constructed class instances.
  final filterLibraryNoInstances = ValueNotifier(true);

  ValueListenable<bool> get filterLibraryNoInstancesListenable =>
      filterLibraryNoInstances;

  /// Table ordered by library, class or instance
  static const groupByLibrary = 'Library';
  static const groupByClass = 'Class';
  static const groupByInstance = 'Instance';

  final groupingBy = ValueNotifier<String>(groupByLibrary);

  ValueListenable<String> get groupingByNotifier => groupingBy;

  String get _isolateId =>
      serviceManager.isolateManager.selectedIsolate.value.id;

  final StreamController<MemoryTracker> _memoryTrackerController =
      StreamController<MemoryTracker>.broadcast();

  Stream<MemoryTracker> get onMemory => _memoryTrackerController.stream;

  Stream<void> get onDisconnect => _disconnectController.stream;
  final _disconnectController = StreamController<void>.broadcast();

  MemoryTracker _memoryTracker;

  MemoryTracker get memoryTracker => _memoryTracker;

  bool get hasStarted => _memoryTracker != null;

  bool hasStopped;

  void _handleIsolateChanged() {
    // TODO(terry): Need an event on the controller for this too?
  }

  void _handleConnectionStart(ServiceConnectionManager serviceManager) {
    _memoryTracker = MemoryTracker(serviceManager, this);
    _memoryTracker.start();

    // Log Flutter extension events.
    // Note: We do not need to listen to event history here because we do not
    // have matching historical data about total memory usage.
    autoDispose(serviceManager.service.onExtensionEvent.listen((Event event) {
      var extensionEventKind = event.extensionKind;
      String customEventKind;
      if (MemoryTimeline.isCustomEvent(event.extensionKind)) {
        extensionEventKind = MemoryTimeline.devToolsExtensionEvent;
        customEventKind = MemoryTimeline.customEventName(event.extensionKind);
      }
      final jsonData = event.extensionData.data;
      // TODO(terry): Display events enabled in a settings page for now only these events.
      switch (extensionEventKind) {
        case 'Flutter.ImageSizesForFrame':
          memoryTimeline.addExtensionEvent(
              event.timestamp, event.extensionKind, jsonData);
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
    }));

    autoDispose(
      _memoryTracker.onChange.listen((_) {
        _memoryTrackerController.add(_memoryTracker);
      }),
    );
    autoDispose(
      _memoryTracker.onChange.listen((_) {
        _memoryTrackerController.add(_memoryTracker);
      }),
    );

    // TODO(terry): Used to detect stream being closed from the
    // memoryController dispose method.  Needed when a HOT RELOAD
    // will call dispose however, spinup (initState) doesn't seem
    // to happen David is working on scaffolding.
    _memoryTrackerController.stream.listen((_) {}, onDone: () {
      // Stop polling and reset memoryTracker.
      _memoryTracker.stop();
      _memoryTracker = null;
    });
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

    autoDispose(
      serviceManager.onConnectionAvailable
          .listen((_) => _handleConnectionStart(serviceManager)),
    );
    if (serviceManager.connectedAppInitialized) {
      _handleConnectionStart(serviceManager);
    }
    autoDispose(
      serviceManager.onConnectionClosed.listen(_handleConnectionStop),
    );
  }

  Future<HeapSnapshotGraph> snapshotMemory() async {
    return await serviceManager?.service?.getHeapSnapshotGraph(
        serviceManager?.isolateManager?.selectedIsolate?.value);
  }

  final _monitorAllocationsNotifier = ValueNotifier<int>(0);

  /// Last column sorted and sort direction in allocation monitoring. As table
  /// is reconstructed e.g., reset, etc. remembers user's sorting preference.
  ColumnData<ClassHeapDetailStats> sortedMonitorColumn;
  SortDirection sortedMonitorDirection;

  ValueListenable<int> get monitorAllocationsNotifier =>
      _monitorAllocationsNotifier;

  DateTime monitorTimestamp;

  ValueListenable<DateTime> get lastMonitorTimestampNotifier =>
      lastMonitorTimestamp;

  final lastMonitorTimestamp = ValueNotifier<DateTime>(null);

  /// Used for Allocations table search auto-complete.

  /// This finds and selects an exact match in the tree.
  /// Returns `true` if [searchingValue] is found in the tree.
  bool selectItemInAllocationTable(String searchingValue) {
    // Search the allocation table.
    for (final reference in monitorAllocations) {
      final foundIt = _selectItemInTable(reference, searchingValue);
      if (foundIt) {
        return true;
      }
    }
    return false;
  }

  bool _selectAllocationInTable(ClassHeapDetailStats reference, search) {
    if (reference.classRef.name == search) {
      searchMatchMonitorAllocationsNotifier.value = reference;
      clearSearchAutoComplete();
      return true;
    }
    return false;
  }

  bool _selectItemInTable(ClassHeapDetailStats reference, String search) =>
      _selectAllocationInTable(reference, search);

  /// Used for searching in monitor allocation table.
  final searchMatchMonitorAllocationsNotifier =
      ValueNotifier<ClassHeapDetailStats>(null);

  var _monitorAllocations = <ClassHeapDetailStats>[];

  List<ClassHeapDetailStats> get monitorAllocations => _monitorAllocations;

  set monitorAllocations(List<ClassHeapDetailStats> allocations) {
    _monitorAllocations = allocations;
    // Clearing allocations reset ValueNotifier to zero.
    if (allocations.isEmpty) {
      _monitorAllocationsNotifier.value = 0;
    } else {
      _monitorAllocationsNotifier.value++;
    }

    // Update the tracking (stacktrace) state of the newly fetched monitored allocations.
    for (var monitorAllocation in _monitorAllocations) {
      final trackedClass = trackAllocations.entries.firstWhere(
        (trackRef) => monitorAllocation.classRef.id == trackRef.value.id,
        orElse: () => null,
      );

      if (trackedClass != null) {
        monitorAllocation.isStacktraced = true;
        setTracking(trackedClass.value, true);
      }
    }
  }

  void toggleAllocationTracking(ClassHeapDetailStats item, bool isStacktraced) {
    item.isStacktraced = isStacktraced;
    setTracking(item.classRef, isStacktraced);
    changeStackTraces();
  }

  Future<List<ClassHeapDetailStats>> resetAllocationProfile() =>
      getAllocationProfile(reset: true);

  /// 'reset': true to reset the monitor allocation accumulators
  Future<List<ClassHeapDetailStats>> getAllocationProfile({
    bool reset = false,
  }) async {
    if (!await isIsolateLive(_isolateId)) return [];

    AllocationProfile allocationProfile;
    allocationProfile = await serviceManager.service.getAllocationProfile(
      _isolateId,
      reset: reset,
    );

    final lastReset = allocationProfile.dateLastAccumulatorReset;
    if (lastReset != null) {
      final resetTimestamp = DateTime.fromMillisecondsSinceEpoch(lastReset);
      debugLogger('Last Allocation Reset @ '
          '${MemoryController.formattedTimestamp(resetTimestamp)}');
    }

    final allocations = allocationProfile.members
        .map((ClassHeapStats stats) => parseJsonClassHeapStats(stats.json))
        .where((ClassHeapDetailStats stats) {
      return stats.instancesCurrent > 0 || stats.instancesDelta > 0;
    }).toList();

    if (!reset) {
      // AllocationStart again, any classes being tracked?
      final allSamples = await computeAllAllocationSamples();
      final allClassRefTracked = allSamples.keys;
      allocationSamples.clear();
      for (var classRef in allClassRefTracked) {
        final cpuSamples = allSamples[classRef];
        allocationSamples.add(AllocationSamples(classRef, cpuSamples));
      }
    }

    return allocations;
  }

  /// If viewing offline data (Android collected) the connection may not be
  /// Android.
  ///
  /// If offline and if any Android collected data then we can view the Android
  /// data.
  bool get isOfflineAndAndroidData {
    return offline && memoryTimeline.data.first.adbMemoryInfo.realtime > 0;
  }

  bool get isConnectedDeviceAndroid {
    return serviceManager?.vm?.operatingSystem == 'android';
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

  Future<List<InstanceSummary>> getInstances(
    String classRef,
    String className,
    int maxInstances,
  ) async {
    // TODO(terry): Expose as a stream to reduce stall when querying for 1000s
    // TODO(terry): of instances.
    InstanceSet instanceSet;
    try {
      instanceSet = await serviceManager.service.getInstances(
        _isolateId,
        classRef,
        maxInstances,
        classId: classRef,
      );
    } on SentinelException catch (_) {
      return [];
    }
    return instanceSet.instances
        .map((ObjRef ref) => InstanceSummary(classRef, className, ref.id))
        .toList();
  }

  /// When new snapshot occurs entire libraries should be rebuilt then rebuild should be true.
  LibraryReference computeAllLibraries({
    bool filtered = true,
    bool rebuild = false,
    HeapSnapshotGraph graph,
  }) {
    final HeapSnapshotGraph snapshotGraph =
        graph != null ? graph : snapshots.safeLast?.snapshotGraph;

    if (snapshotGraph == null) return null;

    if (filtered && libraryRoot != null && !rebuild) return libraryRoot;

    // Group by library
    final newLibraryRoot = LibraryReference(this, libraryRootNode, null);

    // Group by class (under root library __CLASSES__).
    classRoot = LibraryReference(this, classRootNode, null);

    final externalReferences =
        ExternalReferences(this, snapshotGraph.externalSize);
    for (final liveExternal in heapGraph.externals) {
      final HeapGraphClassLive classLive = liveExternal.live.theClass;

      ExternalReference externalReference;

      if (externalReferences.children.isNotEmpty) {
        externalReference = externalReferences.children.singleWhere(
          (knownClass) => knownClass.name == classLive.name,
          orElse: () => null,
        );
      }

      if (externalReference == null) {
        externalReference =
            ExternalReference(this, classLive.name, liveExternal);
        externalReferences.addChild(externalReference);
      }

      final classInstance = ExternalObjectReference(
        this,
        externalReference.children.length,
        liveExternal.live,
        liveExternal.externalProperty.externalSize,
      );

      // Sum up the externalSize of the children, under the externalReference group.
      externalReference.sumExternalSizes +=
          liveExternal.externalProperty.externalSize;

      externalReference.addChild(classInstance);
    }

    newLibraryRoot.addChild(externalReferences);

    // Add our filtered items under the 'Filtered' node.
    if (filtered) {
      final filteredReference = FilteredReference(this);
      final filtered = heapGraph.filteredLibraries;
      addAllToNode(filteredReference, filtered);

      newLibraryRoot.addChild(filteredReference);
    }

    // Compute all libraries.
    final groupBy =
        filtered ? heapGraph.groupByLibrary : heapGraph.rawGroupByLibrary;

    groupBy.forEach((libraryName, classes) {
      LibraryReference libReference =
          newLibraryRoot.children.singleWhere((library) {
        return libraryName == library.name;
      }, orElse: () => null);

      // Library not found add to list of children.
      if (libReference == null) {
        libReference = LibraryReference(this, libraryName, classes);
        newLibraryRoot.addChild(libReference);
      }

      for (var actualClass in libReference.actualClasses) {
        monitorClass(
          className: actualClass.name,
          message: 'computeAllLibraries',
        );
        final classRef = ClassReference(this, actualClass);
        classRef.addChild(Reference.empty);

        libReference.addChild(classRef);

        // TODO(terry): Consider adding the ability to clear the table tree cache
        // (root) to reset the level/depth values.
        final classRefClassGroupBy = ClassReference(this, actualClass);
        classRefClassGroupBy.addChild(Reference.empty);
        classRoot.addChild(classRefClassGroupBy);
      }
    });

    // TODO(terry): Eliminate chicken and egg issue.
    // This may not be set if snapshot is being computed, first-time.  Returning
    // newLibraryRoot allows new snapshot to store the libraryRoot.
    libraryRoot = newLibraryRoot;

    return newLibraryRoot;
  }

  // TODO(terry): Change to Set of known libraries so it's O(n) instead of O(n^2).
  void addAllToNode(
      Reference root, Map<String, Set<HeapGraphClassLive>> allItems) {
    allItems.forEach((libraryName, classes) {
      LibraryReference libReference = root.children.singleWhere((library) {
        return libraryName == library.name;
      }, orElse: () => null);

      // Library not found add to list of children.
      libReference ??= LibraryReference(this, libraryName, classes);
      root.addChild(libReference);

      for (var actualClass in libReference.actualClasses) {
        monitorClass(
          className: actualClass.name,
          message: 'computeAllLibraries',
        );
        final classRef = ClassReference(this, actualClass);
        classRef.addChild(Reference.empty);

        libReference.addChild(classRef);

        // TODO(terry): Consider adding the ability to clear the table tree cache
        // (root) to reset the level/depth values.
        final classRefClassGroupBy = ClassReference(this, actualClass);
        classRefClassGroupBy.addChild(Reference.empty);
        classRoot.addChild(classRefClassGroupBy);
      }
    });
  }

  AnalysesReference findAnalysesNode() {
    if (topNode == null) return null;

    for (final child in topNode.children) {
      if (child is AnalysesReference) {
        return child;
      }
    }
    return null;
  }

  void createSnapshotEntries(Reference parent) {
    for (final snapshot in snapshots) {
      final snaphotMatch = parent.children.firstWhere(
        (element) {
          var result = false;
          if (element is SnapshotReference) {
            final SnapshotReference node = element;
            result = node.snapshot == snapshot;
          }

          return result;
        },
        orElse: () => null,
      );
      if (snaphotMatch == null) {
        // New snapshot add it.
        final snapshotNode = SnapshotReference(snapshot);
        parent.addChild(snapshotNode);

        final allLibraries = computeAllLibraries(graph: snapshot.snapshotGraph);
        snapshotNode.addAllChildren(allLibraries.children);

        return;
      }

      assert(snaphotMatch != null, 'Unexpected Snapshot.');
    }
  }

  final _treeChangedNotifier = ValueNotifier<bool>(false);

  ValueListenable<bool> get treeChangedNotifier => _treeChangedNotifier;

  bool get isTreeChanged => _treeChangedNotifier.value;

  void treeChanged({bool state = true}) {
    if (_treeChangedNotifier.value) {
      _treeChangedNotifier.value = false;
    }
    _treeChangedNotifier.value = state;
  }

  Reference buildTreeFromAllData() {
    final oldChildren = topNode?.children;
    if (isTreeChanged) topNode = null;
    topNode ??= LibraryReference(this, libraryRootNode, null);

    if (isTreeChanged && oldChildren != null) {
      topNode.addAllChildren(oldChildren);
    }

    final anyAnalyses = topNode.children.firstWhere(
          (reference) => reference is AnalysesReference,
          orElse: () => null,
        ) !=
        null;

    if (snapshots.isNotEmpty && !anyAnalyses) {
      // Create Analysis entry.
      final analysesRoot = AnalysesReference();
      analysesRoot.addChild(AnalysisReference(''));
      topNode.addChild(analysesRoot);
    }

    createSnapshotEntries(topNode);

    return topNode;
  }

  Future getObject(String objectRef) async =>
      await serviceManager.service.getObject(
        _isolateId,
        objectRef,
      );

  bool _gcing = false;

  bool get isGcing => _gcing;

  Future<void> gc() async {
    _gcing = true;

    try {
      await serviceManager.service.getAllocationProfile(
        _isolateId,
        gc: true,
      );
    } finally {
      _gcing = false;
    }
  }

  // Temporary hack to allow accessing private fields(e.g., _extra) using eval
  // of '_extra.hashCode' to fetch the hashCode of the object of that field.
  // Used to find the object which allocated/references the object being viewed.
  Future<bool> matchObject(
      String objectRef, String fieldName, int instanceHashCode) async {
    final dynamic object = await getObject(objectRef);
    if (object is Instance) {
      final Instance instance = object;
      final List<BoundField> fields = instance.fields;
      for (var field in fields) {
        if (field.decl.name == fieldName) {
          final InstanceRef ref = field.value;

          if (ref == null) continue;

          final evalResult = await evaluate(ref.id, 'hashCode');
          final int objHashCode = int.parse(evalResult?.valueAsString);
          if (objHashCode == instanceHashCode) {
            return true;
          }
        }
      }
    }

    if (object is Sentinel) {
      // TODO(terry): Need more graceful handling of sentinels.
      log(
        'Trying to matchObject with a Sentinel $objectRef',
        LogLevel.error,
      );
    }

    return false;
  }

  List<Reference> snapshotByLibraryData;

  void createSnapshotByLibrary() {
    snapshotByLibraryData ??= lastSnapshot?.librariesToList();
  }

  Snapshot storeSnapshot(
    DateTime timestamp,
    HeapSnapshotGraph graph,
    LibraryReference libraryRoot, {
    bool autoSnapshot = false,
  }) {
    final snapshot = Snapshot(
      timestamp,
      this,
      graph,
      libraryRoot,
      autoSnapshot,
    );
    snapshots.add(snapshot);

    return snapshot;
  }

  void clearAllSnapshots() {
    snapshots.clear();
    snapshotByLibraryData = null;
  }

  /// Detect stale isolates (sentinaled), may happen after a hot restart.
  Future<bool> isIsolateLive(String isolateId) async {
    try {
      final service = serviceManager?.service;
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
    _disconnectController.close();
    _memoryTrackerController.close();
  }
}

/// Settings dialog model.
class SettingsModel {
  /// Pattern is of the form:
  ///    - empty string implies no matching.
  ///    - NNN* implies match anything starting with NNN.
  ///    - *NNN implies match anything ending with NNN.
  String pattern = '';

  /// If true hide Class names that begin with an underscore.
  bool hidePrivateClasses = true;

  /// If true enable the memory experiment that following a object instance via
  /// inbound references instances.  Compares hashCodes (using eval causing
  /// memory shaking).  Only works in debug mode.
  bool experiment = false;
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
    MemoryScreen.gaActionForExport();

    final liveData = controller.memoryTimeline.liveData;

    bool pseudoData = false;
    if (liveData.isEmpty) {
      // Used to create empty memory log for test.
      pseudoData = true;
      liveData.add(HeapSample(
        DateTime.now().millisecondsSinceEpoch,
        0,
        0,
        0,
        0,
        false,
        AdbMemoryInfo.empty(),
        EventSample.empty(),
        RasterCache.empty(),
      ));
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
    final jsonPayload = _fs.readStringFromFile(filename, isMemory: true);

    final memoryJson = SamplesMemoryJson.decode(argJsonString: jsonPayload);

    if (!memoryJson.isMatchedVersion) {
      final e =
          'Error loading file $filename version ${memoryJson.payloadVersion}';
      log(e, LogLevel.warning);
      throw OfflineFileException(e);
    }

    assert(memoryJson.isMemoryPayload);

    controller.offline = true;
    controller.memoryTimeline.offlineData.clear();
    controller.memoryTimeline.offlineData.addAll(memoryJson.data);
  }

  @visibleForTesting
  bool removeOfflineFile(String filename) =>
      _fs.deleteFile(filename, isMemory: true);
}
