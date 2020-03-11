// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:ui' as dart_ui;

import 'package:devtools_shared/devtools_shared.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:mp_chart/mp/core/entry/entry.dart';
import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import '../../auto_dispose.dart';
import '../../config_specific/file/file.dart';
import '../../config_specific/logger/logger.dart';
import '../../globals.dart';
import '../../ui/fake_flutter/fake_flutter.dart';
import '../../utils.dart';
import '../../vm_service_wrapper.dart';

import '../memory_service.dart';
import 'memory_protocol.dart';

enum ChartType {
  DartHeaps,
  AndroidHeaps,
}

typedef chartStateListener = void Function();

// TODO(terry): Consider supporting more than one file since app was launched.
// Memory Log filename.
final String _memoryLogFilename =
    '${MemoryController.logFilenamePrefix}${DateFormat("yyyyMMdd_hh_mm").format(DateTime.now())}';

// TODO(terry): Implement a dispose method and call in ProvidedControllers dispose.
/// This class contains the business logic for [memory.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Flutter Web.
class MemoryController extends DisposableController
    with AutoDisposeControllerMixin {
  MemoryController() {
    memoryTimeline = MemoryTimeline(this);
    memoryLog = MemoryLog(this);
  }

  static const String logFilenamePrefix = 'memory_log_';

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
    if (type == ChartType.DartHeaps)
      _selectedDartSample = sample;
    else
      _selectedAndroidSample = sample;
  }

  static const String liveFeed = 'Live Feed';

  String memorySourcePrefix;

  /// Notifies that the source of the memory feed has changed.
  ValueListenable get memorySourceNotifier => _memorySourceNotifier;

  final _memorySourceNotifier = ValueNotifier<String>(liveFeed);

  set memorySource(String source) {
    _memorySourceNotifier.value = source;
  }

  String get memorySource => _memorySourceNotifier.value;

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

  /// Automatic pruning of memory statistics (plotted) full data is still retained.
  static const String displayOneMinute = '1';
  static const String displayFiveMinutes = '5';
  static const String displayTenMinutes = '10';
  static const String displayAllMinutes = 'All';

  /// Default is to display last minute of collected data in the chart.
  final _displayIntervalNotifier = ValueNotifier<String>(displayOneMinute);

  ValueListenable<String> get displayIntervalNotifier =>
      _displayIntervalNotifier;

  set displayInterval(String interval) {
    _displayIntervalNotifier.value = interval;
  }

  String get displayInterval => _displayIntervalNotifier.value;

  /// 1 minute in milliseconds.
  static const int minuteInMs = 60 * 1000;

  /// Return the pruning interval in milliseconds.
  int get intervalDurationInMs => (displayInterval == displayAllMinutes)
      ? maxJsInt
      : int.parse(displayInterval) * minuteInMs;

  /// MemorySource has changed update the view.
  void updatedMemorySource() {
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
      memoryLog.loadOffline(memorySource);
    }

    // The memory source has changed, clear all plotted values.
    memoryTimeline.dartChartData.reset();
    memoryTimeline.androidChartData.reset();
  }

  void recomputeOfflineData() {
    final args = memoryTimeline.recomputeOfflineData(intervalDurationInMs);
    processDataset(args);
  }

  void recomputeData() {
    final args = memoryTimeline.recomputeLiveData(intervalDurationInMs);
    processDataset(args);
    // TODO(terry): need to recomputeOffline data?
  }

  void processDataset(args) {
    // Add entries of entries plotted in the chart.  Entries plotted
    // may not match data collected (based on display interval).
    for (var arg in args) {
      memoryTimeline.dartChartData.addTraceEntries(
        capacityValue: arg[MemoryTimeline.capcityValueKey],
        usedValue: arg[MemoryTimeline.usedValueKey],
        externalValue: arg[MemoryTimeline.externalValueKey],
        minutesToDisplay: intervalDurationInMs,
      );
      memoryTimeline.androidChartData.addTraceEntries(
        javaValue: arg[MemoryTimeline.javaHeapValueKey],
        nativeValue: arg[MemoryTimeline.nativeHeapValueKey],
        codeValue: arg[MemoryTimeline.codeValueKey],
        stackValue: arg[MemoryTimeline.stackValueKey],
        graphicsValue: arg[MemoryTimeline.graphicsValueKey],
        otherValue: arg[MemoryTimeline.otherValueKey],
        systemValue: arg[MemoryTimeline.systemValueKey],
        totalValue: arg[MemoryTimeline.totalValueKey],
        minutesToDisplay: intervalDurationInMs,
      );

      if (memoryTimeline.dartChartData.pruned) {
        memoryTimeline.startingIndex++;
      }
    }
  }

  void processData([bool reloadAllData = false]) {
    final args = offline
        ? memoryTimeline.fetchMemoryLogFileData()
        : memoryTimeline.fetchLiveData(reloadAllData);

    processDataset(args);
  }

  bool _paused = false;

  bool get paused => _paused;

  void pauseLiveFeed() {
    _paused = true;
  }

  void resumeLiveFeed() {
    _paused = false;
  }

  bool _androidChartVisible = false;

  bool get isAndroidChartVisible => _androidChartVisible;

  bool toggleAndroidChartVisibility() =>
      _androidChartVisible = !_androidChartVisible;

  final SettingsModel settings = SettingsModel();

  final FilteredLibraries libraryFilters = FilteredLibraries();

  LibraryCollection libraryCollection;

  String get _isolateId => serviceManager.isolateManager.selectedIsolate.id;

  final StreamController<MemoryTracker> _memoryTrackerController =
      StreamController<MemoryTracker>.broadcast();

  Stream<MemoryTracker> get onMemory => _memoryTrackerController.stream;

  Stream<void> get onDisconnect => _disconnectController.stream;
  final _disconnectController = StreamController<void>.broadcast();

  MemoryTracker _memoryTracker;

  MemoryTracker get memoryTracker => _memoryTracker;

  bool get hasStarted => _memoryTracker != null;

  bool hasStopped;

  VM _vm;

  void _handleIsolateChanged() {
    // TODO(terry): Need an event on the controller for this too?
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    _memoryTracker = MemoryTracker(service, this);
    _memoryTracker.start();

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
    autoDispose(
      serviceManager.isolateManager.onSelectedIsolateChanged.listen((_) {
        _handleIsolateChanged();
      }),
    );

    autoDispose(
      serviceManager.onConnectionAvailable.listen(_handleConnectionStart),
    );
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    autoDispose(
      serviceManager.onConnectionClosed.listen(_handleConnectionStop),
    );
  }

  Future<List<ClassHeapDetailStats>> resetAllocationProfile() =>
      getAllocationProfile(reset: true);

  // 'reset': true to reset the object allocation accumulators
  Future<List<ClassHeapDetailStats>> getAllocationProfile(
      {bool reset = false}) async {
    AllocationProfile allocationProfile;
    try {
      allocationProfile = await serviceManager.service.getAllocationProfile(
        _isolateId,
        reset: reset,
      );
    } on SentinelException catch (_) {
      return [];
    }
    return allocationProfile.members
        .map((ClassHeapStats stats) => ClassHeapDetailStats(stats.json))
        .where((ClassHeapDetailStats stats) {
      return stats.instancesCurrent > 0 || stats.instancesAccumulated > 0;
    }).toList();
  }

  void ensureVM() async {
    _vm ??= await serviceManager.service.getVM();
  }

  bool get isConnectedDeviceAndroid {
    ensureVM();
    return (_vm?.operatingSystem) == 'android';
  }

  Future<List<InstanceSummary>> getInstances(
      String classRef, String className, int maxInstances) async {
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

  void initializeLibraryFilters() {}

  Future computeLibraries() async {
    if (libraryCollection == null) {
      // TODO(terry): Review why unawaited is necessary.
      unawaited(serviceManager.service.getVM().then((vm) {
        Future.wait(vm.isolates.map((IsolateRef ref) {
          return serviceManager.service.getIsolate(ref.id);
        })).then((isolates) {
          libraryCollection = LibraryCollection(libraryFilters);
          for (LibraryRef libraryRef in isolates.first.libraries) {
            serviceManager.service
                .getObject(_isolateId, libraryRef.id)
                .then((theLibrary) {
              libraryCollection.addLibrary(theLibrary);
            });
          }

          libraryCollection.computeDisplayClasses();
        });
      }));
    }
  }

  // Keys in the libraries map is a normalized library name.
  List<String> sortLibrariesByNormalizedNames() =>
      libraryCollection.librarires.keys.toList()..sort();

  Future getObject(String objectRef) async =>
      await serviceManager.service.getObject(
        _isolateId,
        objectRef,
      );

  Future<void> gc() async {
    await serviceManager.service.getAllocationProfile(
      _isolateId,
      gc: true,
    );
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

const String _dartLibraryUriPrefix = 'dart:';
const String _flutterLibraryUriPrefix = 'package:flutter';

class FilteredLibraries {
  final List<String> _filteredLibraries = [
    normalizedDartLibraryUri,
    normalizedFlutterLibraryUri,
  ];

  static const String normalizedDartLibraryUri = 'Dart';
  static const String normalizedFlutterLibraryUri = 'Flutter';

  static String normalizeLibraryUri(Library library) {
    final uriParts = library.uri.split('/');
    final firstPart = uriParts.first;
    if (firstPart.startsWith(_dartLibraryUriPrefix)) {
      return FilteredLibraries.normalizedDartLibraryUri;
    } else if (firstPart.startsWith(_flutterLibraryUriPrefix)) {
      return FilteredLibraries.normalizedFlutterLibraryUri;
    } else {
      return firstPart;
    }
  }

  List<String> get librariesFiltered => _filteredLibraries.toList();

  bool get isDartLibraryFiltered =>
      _filteredLibraries.contains(normalizedDartLibraryUri);

  bool get isFlutterLibraryFiltered =>
      _filteredLibraries.contains(normalizedFlutterLibraryUri);

  void clearFilters() {
    _filteredLibraries.clear();
  }

  void addFilter(String libraryUri) {
    _filteredLibraries.add(libraryUri);
  }

  void removeFilter(String libraryUri) {
    _filteredLibraries.remove(libraryUri);
  }

  bool isDartLibrary(Library library) =>
      library.uri.startsWith(_dartLibraryUriPrefix);

  bool isFlutterLibrary(Library library) =>
      library.uri.startsWith(_flutterLibraryUriPrefix);

  bool isLibraryFiltered(String normalizedLibraryUri) =>
      _filteredLibraries.contains(normalizedLibraryUri);
}

class LibraryCollection {
  LibraryCollection(FilteredLibraries filters) : _libraryFilters = filters;

  final FilteredLibraries _libraryFilters;

  /// <key, value> normalizeLibraryUri, Library
  final Map<String, List<Library>> librarires = {};

  /// Classes displayed in snapshot - <key, value> classId and libraryId.
  final Map<String, String> displayClasses = {};

  bool isDisplayClass(String classId) => displayClasses.containsKey(classId);

  void addLibrary(Library library) {
    final normalizedUri = FilteredLibraries.normalizeLibraryUri(library);
    if (librarires[normalizedUri] == null) {
      // Add first library to this normalizedUri.
      librarires[normalizedUri] = [library];
    } else {
      // Add subsequent library to this normalizedUri.
      librarires[normalizedUri].add(library);
    }

    _filterOrShowClasses(library);
  }

  void _filterOrShowClasses(Library library) {
    final normalizedUri = FilteredLibraries.normalizeLibraryUri(library);
    if (_libraryFilters.isLibraryFiltered(normalizedUri)) {
      // We're filtering this library - nothing to show.
      return;
    }

    // This library isn't being filtered so show all its classes.
    for (ClassRef classRef in library.classes) {
      showClass(classRef.id, library);
    }
  }

  /// Called from filter dialog when "apply" is clicked.
  void computeDisplayClasses([FilteredLibraries filters]) {
    final librariesFiltered = filters == null ? _libraryFilters : filters;
    displayClasses.clear();

    librarires.forEach((String normalizedUri, List<Library> libraries) {
      if (librariesFiltered.librariesFiltered.contains(normalizedUri)) {
        for (var library in libraries) {
          for (var theClass in library.classes) {
            filterClass(theClass.id);
          }
        }
      } else {
        for (var library in libraries) {
          for (var theClass in library.classes) {
            showClass(theClass.id, library);
          }
        }
      }
    });
  }

  Library findDartLibrary(String libraryId) =>
      librarires[FilteredLibraries.normalizedDartLibraryUri].firstWhere(
          (Library library) => library.id == libraryId,
          orElse: () => null);

  Library findFlutterLibrary(String libraryId) =>
      librarires[FilteredLibraries.normalizedFlutterLibraryUri].firstWhere(
          (Library library) => library.id == libraryId,
          orElse: () => null);

  Library findOtherLibrary(String libraryId) {
    for (var libraries in librarires.values) {
      for (var library in libraries) {
        if (libraryId == library.id) return library;
      }
    }

    return null;
  }

  /// Class to actively display (otherwise class is filtered out of snapshot).
  void showClass(String classId, Library library) {
    displayClasses[classId] = library.id;
  }

  void filterClass(String classId) {
    displayClasses.remove(classId);
  }

  bool isDartLibrary(String classId) {
    final dartLibrary = findDartLibrary(displayClasses[classId]);
    if (dartLibrary != null) {
      assert(dartLibrary.uri.startsWith(_dartLibraryUriPrefix));
      return true;
    }

    return false;
  }

  bool isFlutterLibrary(String classId) {
    final flutterLibrary = findFlutterLibrary(displayClasses[classId]);
    if (flutterLibrary != null) {
      assert(flutterLibrary.uri.startsWith(_dartLibraryUriPrefix));
      return true;
    }

    return false;
  }

  bool isOtherLibrary(String classId) =>
      findOtherLibrary(displayClasses[classId]) != null;
}

/// Prepare data to plot in MPChart.
class MPChartData {
  bool _pruning = false;

  /// Signal that every addTrace will cause a prune.
  bool get pruned => _pruning;

  /// Datapoint entries for each used heap value.
  final List used = <Entry>[];

  /// Datapoint entries for each capacity heap value.
  final List capacity = <Entry>[];

  /// Datapoint entries for each external memory value.
  final List externalHeap = <Entry>[];

  /// Add each entry to its corresponding trace.
  void addTraceEntries({
    Entry capacityValue,
    Entry usedValue,
    Entry externalValue,
    int minutesToDisplay,
  }) {
    if (!_pruning &&
        externalHeap.isNotEmpty &&
        (externalValue.x - externalHeap.first.x) > minutesToDisplay) {
      _pruning = true;
      assert(externalValue.x - externalHeap.last.x <= minutesToDisplay);
    }

    // TODO(terry): Any way have a kind of trace order safe way to so we
    // can keep an list of the entries (remoteAt and add).
    if (_pruning) {
      externalHeap.removeAt(0);
      used.removeAt(0);
      capacity.removeAt(0);
    }

    externalHeap.add(externalValue);
    used.add(usedValue);
    capacity.add(capacityValue);
  }

  /// Remove all plotted entries in all traces.
  void reset() {
    // TODO(terry): Any way have a kind of trace order safe way to so we
    // can keep an list of the entries (clear).
    used.clear();
    capacity.clear();
    externalHeap.clear();
    _pruning = false;
  }
}

/// Prepare Engine (ADB memory info) data to plot in MPChart.
class MPEngineChartData {
  bool _pruning = false;

  /// Datapoint entries for each Java heap value.
  final List javaHeap = <Entry>[];

  /// Datapoint entries for each native heap value.
  final List nativeHeap = <Entry>[];

  /// Datapoint entries for code size value.
  final List code = <Entry>[];

  /// Datapoint entries for stack size value.
  final List stack = <Entry>[];

  /// Datapoint entries for graphics size value.
  final List graphics = <Entry>[];

  /// Datapoint entries for other size value.
  final List other = <Entry>[];

  /// Datapoint entries for system size value.
  final List system = <Entry>[];

  /// Datapoint entries for total size value.
  final List total = <Entry>[];

  /// Add each entry to its corresponding trace.
  void addTraceEntries({
    Entry javaValue,
    Entry nativeValue,
    Entry codeValue,
    Entry stackValue,
    Entry graphicsValue,
    Entry otherValue,
    Entry systemValue,
    Entry totalValue,
    int minutesToDisplay,
  }) {
    if (!_pruning &&
        javaHeap.isNotEmpty &&
        (javaValue.x - javaHeap.first.x) > minutesToDisplay) {
      _pruning = true;

      assert(javaValue.x - javaHeap.last.x <= minutesToDisplay);
    }

    // TODO(terry): Any way have a kind of trace order safe way to so we
    // can keep an list of the entries (remoteAt and add).
    if (_pruning) {
      javaHeap.removeAt(0);
      nativeHeap.removeAt(0);
      code.removeAt(0);
      stack.removeAt(0);
      graphics.removeAt(0);
      other.removeAt(0);
      system.removeAt(0);
      total.removeAt(0);
    }

    javaHeap.add(javaValue);
    nativeHeap.add(nativeValue);
    code.add(codeValue);
    stack.add(stackValue);
    graphics.add(graphicsValue);
    other.add(otherValue);
    system.add(systemValue);
    total.add(totalValue);
  }

  /// Remove all plotted entries in all traces.
  void reset() {
    // TODO(terry): Any way have a kind of trace order safe way to so we
    // can keep an list of the entries (clear).
    javaHeap.clear();
    nativeHeap.clear();
    code.clear();
    stack.clear();
    graphics.clear();
    other.clear();
    system.clear();
    total.clear();
    _pruning = false;
  }
}

/// All Raw data received from the VM and offline data loaded from a memory log file.
class MemoryTimeline {
  MemoryTimeline(this.controller);

  /// Version of timeline data (HeapSample) JSON payload.
  static const version = 1;

  /// Keys used in a map to store all the MPChart Entries we construct to be plotted.
  static const capcityValueKey = 'capacityValue';
  static const usedValueKey = 'usedValue';
  static const externalValueKey = 'externalValue';
  static const rssValueKey = 'rssValue';

  /// Keys used in a map to store all the MPEngineChart Entries we construct to be plotted,
  /// ADB memory info.
  static const javaHeapValueKey = 'javaHeapValue';
  static const nativeHeapValueKey = 'nativeHeapValue';
  static const codeValueKey = 'codeValue';
  static const stackValueKey = 'stackValue';
  static const graphicsValueKey = 'graphicsValue';
  static const otherValueKey = 'otherValue';
  static const systemValueKey = 'systemValue';
  static const totalValueKey = 'totalValue';

  final MemoryController controller;

  /// Flutter Framework information (Dart heaps).
  final dartChartData = MPChartData();

  /// Flutter Engine (ADB memory information).
  final androidChartData = MPEngineChartData();

  /// Return the data payload that is active.
  List<HeapSample> get data => controller.offline ? offlineData : liveData;

  int get startingIndex =>
      controller.offline ? offlineStartingIndex : liveStartingIndex;

  set startingIndex(int value) {
    controller.offline
        ? offlineStartingIndex = value
        : liveStartingIndex = value;
  }

  int get endingIndex => data.isNotEmpty ? data.length - 1 : -1;

  /// Raw Heap sampling data from the VM.
  final List<HeapSample> liveData = [];

  /// Start index of liveData plotted for MPChartData/MPEngineChartData sets.
  int liveStartingIndex = 0;

  /// Data of the last selected offline memory source (JSON file in /tmp).
  final List<HeapSample> offlineData = [];

  /// Start index of offlineData plotted for MPChartData/MPEngineChartData sets.
  int offlineStartingIndex = 0;

  /// Notifies that a new Heap sample has been added to the timeline.
  final _sampleAddedNotifier = ValueNotifier<HeapSample>(null);

  ValueListenable<HeapSample> get sampleAddedNotifier => _sampleAddedNotifier;

  /// Whether the timeline has been manually paused via the Pause button.
  bool manuallyPaused = false;

  /// Notifies that the timeline has been paused.
  final _pausedNotifier = ValueNotifier<bool>(false);

  ValueNotifier<bool> get pausedNotifier => _pausedNotifier;

  void pause({bool manual = false}) {
    manuallyPaused = manual;
    _pausedNotifier.value = true;
  }

  void resume() {
    manuallyPaused = false;
    _pausedNotifier.value = false;
  }

  /// Notifies any visible marker for a particular chart should be hidden.
  final _markerHiddenNotifier = ValueNotifier<bool>(false);

  ValueListenable<bool> get markerHiddenNotifier => _markerHiddenNotifier;

  void hideMarkers() {
    _markerHiddenNotifier.value = !_markerHiddenNotifier.value;
  }

  /// dart_ui.Image Image asset displayed for each entry plotted in a chart.
  // ignore: unused_field
  dart_ui.Image _img;

  // TODO(terry): Look at using _img for each data point (at least last N).
  dart_ui.Image get dataPointImage => null;

  set image(dart_ui.Image img) {
    _img = img;
  }

  void reset() {
    liveData.clear();
    startingIndex = 0;
    dartChartData.reset();
    androidChartData.reset();
  }

  /// Common utility function to handle loading of the data into the
  /// chart for either offline or live Feed.
  List<Map> _processData(int index) {
    final result = <Map<String, Entry>>[];

    for (var lastIndex = index; lastIndex < data.length; lastIndex++) {
      final sample = data[lastIndex];
      final timestamp = sample.timestamp.toDouble();

      // Flutter Framework memory (Dart VM Heaps)
      final capacity = sample.capacity.toDouble();
      final used = sample.used.toDouble();
      final external = sample.external.toDouble();

      // TOOD(terry): Need to plot.
      final rss = (sample.rss ?? 0).toDouble();

      final extEntry = Entry(x: timestamp, y: external, icon: dataPointImage);
      final usedEntry =
          Entry(x: timestamp, y: used + external, icon: dataPointImage);
      final capacityEntry =
          Entry(x: timestamp, y: capacity, icon: dataPointImage);
      final rssEntry = Entry(x: timestamp, y: rss, icon: dataPointImage);

      // Engine memory values (ADB Android):
      final javaHeap = sample.adbMemoryInfo.javaHeap.toDouble();
      final nativeHeap = sample.adbMemoryInfo.nativeHeap.toDouble();
      final code = sample.adbMemoryInfo.code.toDouble();
      final stack = sample.adbMemoryInfo.stack.toDouble();
      final graphics = sample.adbMemoryInfo.graphics.toDouble();
      final other = sample.adbMemoryInfo.other.toDouble();
      final system = sample.adbMemoryInfo.system.toDouble();
      final total = sample.adbMemoryInfo.total.toDouble();

      final graphicsEntry = Entry(
        x: timestamp,
        y: graphics,
        icon: dataPointImage,
      );
      final stackEntry = Entry(
        x: timestamp,
        y: stack + graphics,
        icon: dataPointImage,
      );
      final javaHeapEntry = Entry(
        x: timestamp,
        y: javaHeap + graphics + stack,
        icon: dataPointImage,
      );
      final nativeHeapEntry = Entry(
        x: timestamp,
        y: nativeHeap + javaHeap + graphics + stack,
        icon: dataPointImage,
      );
      final codeEntry = Entry(
        x: timestamp,
        y: code + nativeHeap + javaHeap + graphics + stack,
        icon: dataPointImage,
      );
      final otherEntry = Entry(
        x: timestamp,
        y: other + code + nativeHeap + javaHeap + graphics + stack,
        icon: dataPointImage,
      );
      final systemEntry = Entry(
        x: timestamp,
        y: system + other + code + nativeHeap + javaHeap + graphics + stack,
        icon: dataPointImage,
      );
      final totalEntry = Entry(
        x: timestamp,
        y: total,
        icon: dataPointImage,
      );

      result.add({
        capcityValueKey: capacityEntry,
        usedValueKey: usedEntry,
        externalValueKey: extEntry,
        rssValueKey: rssEntry,
        javaHeapValueKey: javaHeapEntry,
        nativeHeapValueKey: nativeHeapEntry,
        codeValueKey: codeEntry,
        stackValueKey: stackEntry,
        graphicsValueKey: graphicsEntry,
        otherValueKey: otherEntry,
        systemValueKey: systemEntry,
        totalValueKey: totalEntry,
      });
    }

    return result;
  }

  /// Fetch all the data in the loaded from a memory log (JSON file in /tmp).
  List<Map> fetchMemoryLogFileData() {
    assert(controller.offline);
    assert(offlineData.isNotEmpty);
    return _processData(startingIndex);
  }

  List<Map> fetchLiveData([bool reloadAllData = false]) {
    assert(!controller.offline);
    assert(liveData.isNotEmpty);

    if (endingIndex - startingIndex != liveData.length || reloadAllData) {
      // Process the data received (startingDataIndex is the last sample).
      final args = _processData(endingIndex < 0 ? 0 : endingIndex);

      // Debugging data - to enable remove logical not operator.
      if (!true) {
        final DateFormat mFormat = DateFormat('hh:mm:ss.mmm');
        final startDT = mFormat.format(DateTime.fromMillisecondsSinceEpoch(
            liveData[startingIndex].timestamp.toInt()));
        final endDT = mFormat.format(DateTime.fromMillisecondsSinceEpoch(
            liveData[endingIndex].timestamp.toInt()));
        print('Time range Live data start: $startDT, end: $endDT');
      }

      return args;
    }

    return [];
  }

  List<Map> recomputeOfflineData(int displayInterval) {
    assert(displayInterval > 0);

    _computeStartingIndex(displayInterval);

    // Start from the first sample to display in this time interval.
    return _processData(startingIndex);
  }

  List<Map> recomputeLiveData(int displayInterval) {
    assert(displayInterval > 0);

    _computeStartingIndex(displayInterval);

    // Start from the first sample to display in this time interval.
    return _processData(startingIndex);
  }

  void _computeStartingIndex(int displayInterval) {
    // Compute a new starting index from length - N minutes.
    final timeLastSample = data.last.timestamp;
    var dataIndex = data.length - 1;
    for (; dataIndex > 0; dataIndex--) {
      final sample = data[dataIndex];
      final timestamp = sample.timestamp;

      if ((timeLastSample - timestamp) > displayInterval) break;
    }

    startingIndex = dataIndex;

    // Debugging data - to enable remove logical not operator.
    if (!true) {
      final DateFormat mFormat = DateFormat('hh:mm:ss.mmm');
      final startDT = mFormat.format(DateTime.fromMillisecondsSinceEpoch(
          data[startingIndex].timestamp.toInt()));
      final endDT = mFormat.format(DateTime.fromMillisecondsSinceEpoch(
          data[endingIndex].timestamp.toInt()));
      print('Recompute Time range Offline data start: $startDT, end: $endDT');
    }
  }

  void addSample(HeapSample sample) {
    // Always record the heap sample in the raw set of data (liveFeed).
    liveData.add(sample);

    // Only notify that new sample has arrived if the
    // memory source is 'Live Feed'.
    if (!controller.offline) {
      _sampleAddedNotifier.value = sample;
    }
  }
}

/// Supports saving and loading memory samples.
class MemoryLog {
  MemoryLog(this.controller);

  /// Use in memory or local file system based on Flutter Web/Desktop.
  static final _fs = FileIO();

  MemoryController controller;

  /// Persist the the live memory data to a JSON file in the /tmp directory.
  void exportMemory() async {
    final liveData = controller.memoryTimeline.liveData;

    bool pseudoData = false;
    if (liveData.isEmpty) {
      // TODO(terry): Can eliminate once I add loading a canned data source
      //              see TODO in memory_screen_test.
      // Used to create empty memory log for test.
      pseudoData = true;
      liveData.add(HeapSample(
        DateTime.now().microsecondsSinceEpoch,
        0,
        0,
        0,
        0,
        false,
        AdbMemoryInfo.empty(),
      ));
    }

    final jsonPayload = MemoryJson.encodeHeapSamples(liveData);
    if (kDebugMode) {
      // TODO(terry): Remove this check add a unit test instead.
      // Reload the file just created and validate that the saved data matches
      // the live data.
      final memoryJson = MemoryJson.decode(jsonPayload);
      assert(memoryJson.isMatchedVersion);
      assert(memoryJson.isMemoryPayload);
      assert(memoryJson.data.length == liveData.length);
    }

    _fs.writeStringToFile(_memoryLogFilename, jsonPayload);

    // TODO(terry): Display filename created in a toast.

    if (pseudoData) liveData.clear();
  }

  /// Return a list of offline memory logs filenames in the /tmp directory
  /// that are available to open.
  List<String> offlineFiles() {
    final memoryLogs = _fs.list(prefix: MemoryController.logFilenamePrefix);

    // Sort by newest file top-most (DateTime is in the filename).
    memoryLogs.sort((a, b) => b.compareTo(a));

    return memoryLogs;
  }

  /// Load the memory profile data from a saved memory log file.
  void loadOffline(String filename) async {
    controller.offline = true;

    final jsonPayload = _fs.readStringFromFile(filename);
    final memoryJson = MemoryJson.decode(jsonPayload);

    // TODO(terry): Display notification JSON file isn't version isn't
    // supported or if the payload isn't an exported memory file.
    assert(memoryJson.isMatchedVersion);
    assert(memoryJson.isMemoryPayload);

    controller.memoryTimeline.offlineData.clear();
    controller.memoryTimeline.offlineData.addAll(memoryJson.data);
  }

  @visibleForTesting
  bool removeOfflineFile(String filename) => _fs.deleteFile(filename);
}
