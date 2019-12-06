// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';
import 'dart:convert';

import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger.dart';
import '../globals.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../vm_service_wrapper.dart';

import 'memory_protocol.dart';
import 'memory_service.dart';

typedef chartStateListener = void Function();

// TODO(terry): Implement a dispose method and call in ProvidedControllers dispose.
/// This class contains the business logic for [memory.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Flutter Web.
class MemoryController {
  final MemoryTimeline memoryTimeline = MemoryTimeline();

  int selectedSample = -1;

  bool _paused = false;

  bool get paused => _paused;

  void pauseLiveFeed() {
    _paused = true;
  }

  void resumeLiveFeed() {
    _paused = false;
  }

  /// Listeners to hookup modifying the MemoryChartState.
  final List<chartStateListener> _resetFeedListeners = [];

  void addResetFeedListener(chartStateListener listener) {
    _resetFeedListeners.add(listener);
  }

  void removeResetFeedListener(chartStateListener listener) {
    _resetFeedListeners.remove(listener);
  }

  // Call any ChartState listeners.
  void notifyResetFeedListeners() {
    for (var notifyListener in _resetFeedListeners) {
      notifyListener();
    }
  }

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

  void _handleIsolateChanged() {
    // TODO(terry): Need an event on the controller for this too?
  }

  void _handleConnectionStart(VmServiceWrapper service) {
    _memoryTracker = MemoryTracker(service, this);
    _memoryTracker.start();

    _memoryTracker.onChange.listen((_) {
      _memoryTrackerController.add(_memoryTracker);
    });
  }

  void _handleConnectionStop(dynamic event) {
    _memoryTracker?.stop();
    _memoryTrackerController.add(_memoryTracker);

    _disconnectController.add(null);
    hasStopped = true;
  }

  Future<void> startTimeline() async {
    serviceManager.isolateManager.onSelectedIsolateChanged.listen((_) {
      _handleIsolateChanged();
    });

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);
  }

  Future<List<ClassHeapDetailStats>> resetAllocationProfile() =>
      getAllocationProfile(reset: true);

  // 'reset': true to reset the object allocation accumulators
  Future<List<ClassHeapDetailStats>> getAllocationProfile(
      {bool reset = false}) async {
    final AllocationProfile allocationProfile =
        await serviceManager.service.getAllocationProfile(
      _isolateId,
      reset: reset,
    );
    return allocationProfile.members
        .map((ClassHeapStats stats) => ClassHeapDetailStats(stats.json))
        .where((ClassHeapDetailStats stats) {
      return stats.instancesCurrent > 0 || stats.instancesAccumulated > 0;
    }).toList();
  }

  Future<List<InstanceSummary>> getInstances(
      String classRef, String className, int maxInstances) async {
    // TODO(terry): Expose as a stream to reduce stall when querying for 1000s
    // TODO(terry): of instances.
    final InstanceSet instanceSet = await serviceManager.service.getInstances(
      _isolateId,
      classRef,
      maxInstances,
      classId: classRef,
    );

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

class MemoryTimeline {
  /// Raw Heap sampling data from the VM.
  final List<HeapSample> data = [];

  /// Notifies that a new Heap sample has been added to the timeline.
  final _sampleAddedNotifier = ValueNotifier<HeapSample>(null);

  ValueListenable<HeapSample> get sampleAddedNotifier => _sampleAddedNotifier;

  /// Whether the timeline has been manually paused via the Pause button.
  bool manuallyPaused = false;

  /// Notifies that the timeline has been paused.
  final _pausedNotifier = ValueNotifier<bool>(false);

  ValueNotifier<bool> get pausedNotifier => _pausedNotifier;

  /// Given a list of HeapSample, encode as a Json string.
  static String encodeHeapSamples(List<HeapSample> data) {
    final List encodeHeapSamples = data.map((f) => jsonEncode(f)).toList();
    return jsonEncode({'samples': encodeHeapSamples});
  }

  // Given a JSON string representing an array of HeapSample, decode to a List of HeapSample.
  static List<HeapSample> decodeHeapSamples(String jsonString) {
    final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
    final List dynamicList = decodedMap['samples'];
    final List<HeapSample> samples = [];
    for (var index = 0; index < dynamicList.length; index++) {
      final Map<String, dynamic> entry = jsonDecode(dynamicList[index]);
      final sample = HeapSample.fromJson(entry);
      samples.add(sample);
    }

    return samples;
  }

  void pause({bool manual = false}) {
    manuallyPaused = manual;
    _pausedNotifier.value = true;
  }

  void resume() {
    manuallyPaused = false;
    _pausedNotifier.value = false;
  }

  void addSample(HeapSample sample) {
    data.add(sample);
    _sampleAddedNotifier.value = sample;
  }
}
