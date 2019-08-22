// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../globals.dart';
import '../vm_service_wrapper.dart';
import 'memory_protocol.dart';
import 'memory_service.dart';

/// This class contains the business logic for [memory.dart].
///
/// This class must not have direct dependencies on dart:html. This allows tests
/// of the complicated logic in this class to run on the VM and will help
/// simplify porting this code to work with Hummingbird.
class MemoryController {
  MemoryController();

  final Settings settings = Settings();

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
    _memoryTracker = MemoryTracker(service);
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
      final VM vm = await serviceManager.service.getVM();
      // TODO(terry): Need to handle a possible Sentinel being returned.
      final List<Isolate> isolates =
          await Future.wait(vm.isolates.map((IsolateRef ref) async {
        return await serviceManager.service.getIsolate(ref.id);
      }));

      libraryCollection = LibraryCollection(libraryFilters);
      for (LibraryRef libraryRef in isolates[0].libraries) {
        final Library theLibrary =
            await serviceManager.service.getObject(_isolateId, libraryRef.id);
        libraryCollection.addLibrary(theLibrary);
      }

      libraryCollection.computeDisplayClasses();
    }
  }

  List<String> sortLibrariesByNormalizedNames() {
    final List<String> normalizedNames =
        libraryCollection.librarires.keys.toList();
    normalizedNames.sort((a, b) => a.compareTo(b));
    return normalizedNames;
  }

  Future<dynamic> getObject(String objectRef) async =>
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
      print('Trying to matchObject with a Sentinel $objectRef');
    }

    return false;
  }
}

class Settings {
  String pattern = '*';
  bool showPrivateFields = true;
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
    final firstPart = uriParts[0];
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
