// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart';
import 'memory_controller.dart';

// TODO(terry): Ask Ben, what is a class name of ::?
/// Internal class names :: automatically filter out.
const internalClassName = '::';

/// Contains normalized library name and class name. Where
/// normalized library is dart:xxx, package:xxxx, etc. This is
/// how libraries and class names are displayed to the user
/// to help to reduce the 100s of URIs that would otherwise be
/// encountered.
class LibraryClass {
  LibraryClass(this.libraryName, this.className);

  final String libraryName;
  final String className;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != LibraryClass) return false;
    return libraryName == other.libraryName && className == other.className;
  }

  @override
  int get hashCode => libraryName.hashCode ^ className.hashCode;
}

const core = 'dart:core';
const collection = 'dart:collection';

// TODO(terry): Bake in types instead of comparing qualified class name.
LibraryClass predefinedNull = LibraryClass(core, 'Null');
LibraryClass predefinedString = LibraryClass(core, '_OneByteString');
LibraryClass predefinedList = LibraryClass(core, '_List');
LibraryClass predefinedMap = LibraryClass(
  collection,
  '_InternalLinkedHashMap',
);

LibraryClass predefinedHashMap = LibraryClass(
  collection,
  '_HashMap',
);

class Predefined {
  const Predefined(this.prettyName, this.isScalar);

  final String prettyName;
  final bool isScalar;
}

/// Structure key is fully qualified class name and the value is
/// a List first entry is pretty name known to users second entry
/// is if the type is a scalar.
Map<LibraryClass, Predefined> predefinedClasses = {
  LibraryClass(core, 'bool'): const Predefined('bool', true),
  // TODO(terry): Handle Smi too (Integer)?
  // Integers not Smi but fit into 64bits.
  LibraryClass(core, '_Mint'): const Predefined('int', true),
  LibraryClass(core, '_Double'): const Predefined('Double', true),
  predefinedString: const Predefined('String', true),
  predefinedList: const Predefined('List', false),
  predefinedMap: const Predefined('Map', false),
  predefinedHashMap: const Predefined('HashMap', false),
};

// TODO(terry): Investigate if class implements the Map interface?
bool isBuiltInMap(HeapGraphClassLive live) =>
    live.fullQualifiedName == predefinedMap ||
    live.fullQualifiedName == predefinedHashMap;

/// Is it a built-in HashMap class (predefined).
bool isBuiltInHashMap(HeapGraphClassLive live) =>
    live.fullQualifiedName == predefinedHashMap;

/// Is it a built-in List class (predefined).
bool isBuiltInList(HeapGraphClassLive live) =>
    live.fullQualifiedName == predefinedList;

/// List of classes to monitor, helps to debug particular class structure.
final Map<int, String> _monitorClasses = {};

/// Ensure the classId is zero based ()
bool monitorClass({int classId, String className, String message = ''}) {
  if (classId != null) {
    if (_monitorClasses.containsKey(classId)) {
      final className = _monitorClasses[classId];
      print('STOP: class $className [classId=$classId]  $message');
      return true;
    }
  } else if (className != null) {
    if (_monitorClasses.containsValue(className)) {
      print('STOP: class $className  $message');
      return true;
    }
  } else {
    print('WARNING: Missing classId or className to monitor.');
  }
  return false;
}

HeapGraph convertHeapGraph(
  MemoryController controller,
  HeapSnapshotGraph graph, [
  List<String> classNamesToMonitor,
]) {
  final Map<LibraryClass, int> builtInClasses = {};

  if (classNamesToMonitor != null && classNamesToMonitor.isNotEmpty) {
    print('WARNING: Remove classNamesToMonitor before PR submission. '
        '$classNamesToMonitor');
  }

  // Construct all the classes in the snapshot.
  final List<HeapGraphClassLive> classes =
      List<HeapGraphClassLive>.filled(graph.classes.length, null);
  for (int i = 0; i < graph.classes.length; i++) {
    final HeapSnapshotClass c = graph.classes[i];

    final className = c.name;
    // Remember builtin classes classId e.g., bool, String (_OneByteString), etc.
    // The classId is the index into the graph.classes list.
    final libraryClass = LibraryClass('${c.libraryUri}', c.name);
    // It's a exact match libraryName,className once we match the classId drives
    // the class matching.
    if (predefinedClasses.containsKey(libraryClass)) {
      builtInClasses.putIfAbsent(libraryClass, () => i);
    }

    // Debugging code to monitor a particular class.  ClassesToMonitor should be
    // empty before commiting PRs.
    if (classNamesToMonitor != null &&
        classNamesToMonitor.isNotEmpty &&
        classNamesToMonitor.contains(className)) {
      print('WARNING: class $className is monitored.');
      _monitorClasses.putIfAbsent(i, () => className);
    }

    classes[i] = HeapGraphClassLive(c);
  }

  // Pre-allocate the number of objects in the snapshot.
  final List<HeapGraphElementLive> elements =
      List<HeapGraphElementLive>.filled(graph.objects.length, null);

  // Construct all objects.
  for (int i = 0; i < graph.objects.length; i++) {
    final HeapSnapshotObject o = graph.objects[i];
    elements[i] = HeapGraphElementLive(o);
  }

  // Associate each object with a Class.
  for (int i = 0; i < graph.objects.length; i++) {
    final HeapSnapshotObject o = graph.objects[i];
    final HeapGraphElementLive converted = elements[i];
    if (o.classId == 0) {
      // classId of zero is a sentinel.
      converted.theClass = HeapGraph.classSentinel;
    } else {
      // Allows finding and debugging a class in the snapshot.
      // classIds in the object are 1 based need to make zero based.
      monitorClass(classId: o.classId - 1);

      converted.theClass = classes[o.classId - 1];
    }

    // Lazily compute the references.
    converted.referencesFiller = () {
      for (int refId in o.references) {
        HeapGraphElement ref;
        if (refId == 0) {
          ref = HeapGraph.elementSentinel;
        } else {
          ref = elements[refId - 1];
        }
        converted.references.add(ref);
      }
    };
  }

  final snapshotExternals = graph.externalProperties;

  // Pre-allocate the number of external objects in the snapshot.
  final externals =
      List<HeapGraphExternalLive>.filled(snapshotExternals.length, null);

  // Construct all external objects and link to its live element.
  for (int index = 0; index < snapshotExternals.length; index++) {
    final snapshotObject = snapshotExternals[index];
    final liveElement = elements[snapshotObject.object];
    externals[index] = HeapGraphExternalLive(snapshotObject, liveElement);
  }

  return HeapGraph(
    controller,
    builtInClasses,
    classes,
    elements,
    externals,
  );
}

class HeapGraph {
  HeapGraph(
    this.controller,
    this.builtInClasses,
    this.classes,
    this.elements,
    this.externals,
  );

  final MemoryController controller;

  bool _instancesComputed = false;

  bool get instancesComputed => _instancesComputed;

  /// Known built-in classes.
  final Map<LibraryClass, int> builtInClasses;

  /// Sentinel Class, all class sentinels point to this object.
  static HeapGraphClassSentinel classSentinel = HeapGraphClassSentinel();

  /// Indexed by classId.
  final List<HeapGraphClassLive> classes;

  /// Sentinel Object, all object sentinels point to this object.
  static HeapGraphElementSentinel elementSentinel = HeapGraphElementSentinel();

  /// Index by objectId.
  final List<HeapGraphElementLive> elements;

  /// Index by objectId of all external properties
  List<HeapGraphExternalLive> externals;

  /// Group all classes by libraries (key is library, value are classes).
  /// This is the entire set of objects (no filter applied).
  final Map<String, Set<HeapGraphClassLive>> rawGroupByLibrary = {};

  /// Group all classes by libraries (key is library, value is classes).
  /// Filtering out objects that match a given filter. This is always a
  /// subset of rawGroupByLibrary.
  final Map<String, Set<HeapGraphClassLive>> groupByLibrary = {};

  /// Group all instances by class (key is class name, value are class
  /// instances).  This is the entire set of objects (no filter applied).
  final Map<String, Set<HeapGraphElementLive>> rawGroupByClass = {};

  /// Group all instances by class (key is class name, value are class
  /// instances).  Filtering out objects that match a given filter. This
  /// is always a subset of rawGroupByClass.
  final Map<String, Set<HeapGraphElementLive>> groupByClass = {};

  /// Group of instances by filtered out classes (key is class name, value
  /// are instances). These are the instances not in groupByClass, together
  /// filteredElements and groupByClass are equivalent to rawGroupByClass.
  final Map<String, Set<HeapGraphElementLive>> filteredElements = {};

  /// Group of libraries by filtered out classes (key is library name, value
  /// are classes). These are the libraries not in groupByLibrary, together
  /// filteredLibraries and groupByLibrary are equivalent to rawGroupByLibrary.
  final Map<String, Set<HeapGraphClassLive>> filteredLibraries = {};

  /// Normalize the library name. Library is a Uri that contains
  /// the schema e.g., 'dart' or 'package' and pathSegments. The
  /// segments are paths to a dart file.  Without simple normalization
  /// 100s maybe 1000s of libraries would be displayed to the
  /// developer.  Normalizing takes the schema and the first part
  /// of the path e.g., dart:core, package:flutter, etc. Hopefully,
  /// this is not too chunky but better than no normalization.  Also,
  /// the empty library is returned as src e.g., lib/src
  String normalizeLibraryName(HeapSnapshotClass theClass) {
    final uri = theClass.libraryUri;
    final scheme = uri.scheme;

    if (scheme == 'package' || scheme == 'dart') {
      return '$scheme:${uri.pathSegments[0]}';
    }

    assert(theClass.libraryName.isEmpty);
    return 'src';
  }

  void computeRawGroups() {
    // Only compute once.
    if (rawGroupByLibrary.isNotEmpty || rawGroupByClass.isNotEmpty) return;

    for (final c in classes) {
      final sb = StringBuffer();

      final libraryKey = normalizeLibraryName(c.origin);

      // Collect classes for each library (group by library).
      sb.write(libraryKey);
      final librarySbToString = sb.toString();
      rawGroupByLibrary[librarySbToString] ??= <HeapGraphClassLive>{};
      rawGroupByLibrary[librarySbToString].add(c);
      sb.clear();

      // Collect instances for each class (group by class)
      for (final instance in c.getInstances(this)) {
        sb.write(c.name);
        c.instancesTotalShallowSizes += instance.origin.shallowSize;
        final classSbToString = sb.toString();
        rawGroupByClass[classSbToString] ??= <HeapGraphElementLive>{};
        rawGroupByClass[classSbToString].add(instance);
        sb.clear();
      }
    }
  }

  void computeFilteredGroups() {
    // Clone groupByClass from raw group.
    groupByClass.clear();
    rawGroupByClass.forEach((key, value) {
      groupByClass[key] = value.cast<HeapGraphElementLive>().toSet();
    });

    // Prune classes that are private or have zero instances.
    filteredElements.clear();
    groupByClass.removeWhere((className, instances) {
      final remove =
          (controller.filterZeroInstances.value && instances.isEmpty) ||
              (controller.filterPrivateClasses.value &&
                  className.startsWith('_')) ||
              className == internalClassName;
      if (remove) {
        filteredElements.putIfAbsent(className, () => instances);
      }

      return remove;
    });

    // Clone groupByLibrary from raw group.
    groupByLibrary.clear();
    rawGroupByLibrary.forEach((key, value) {
      groupByLibrary[key] = value.cast<HeapGraphClassLive>().toSet();
    });

    // Prune libraries if all their classes are private or have zero instances.
    filteredLibraries.clear();

    groupByLibrary.removeWhere((libraryName, classes) {
      classes.removeWhere((actual) {
        final result = (controller.filterZeroInstances.value &&
                actual.getInstances(this).isEmpty) ||
            (controller.filterPrivateClasses.value &&
                actual.name.startsWith('_')) ||
            actual.name == internalClassName;
        return result;
      });

      final result =
          (controller.libraryFilters.isLibraryFiltered(libraryName)) ||
              controller.filterLibraryNoInstances.value && classes.isEmpty;
      if (result) {
        filteredLibraries.putIfAbsent(libraryName, () => classes);
      }

      return result;
    });
  }

  // TODO(terry): Need dominator graph for flow.
  /// Compute all instances, needed for retained space.
  void computeInstancesForClasses() {
    if (!instancesComputed) {
      for (final instance in elements) {
        instance.theClass.addInstance(instance);
      }

      _instancesComputed = true;
    }
  }
}

abstract class HeapGraphElement {
  /// Outbound references, i.e. this element points to elements in this list.
  List<HeapGraphElement> _references;

  void Function() referencesFiller;

  List<HeapGraphElement> get references {
    if (_references == null && referencesFiller != null) {
      _references = [];
      referencesFiller();
    }
    return _references;
  }

  bool get isSentinel;
}

/// Object marked for removal on next GC.
class HeapGraphElementSentinel extends HeapGraphElement {
  @override
  bool get isSentinel => true;

  @override
  String toString() => 'HeapGraphElementSentinel';
}

/// Live element.
class HeapGraphElementLive extends HeapGraphElement {
  HeapGraphElementLive(this.origin);

  final HeapSnapshotObject origin;
  HeapGraphClass theClass;

  @override
  bool get isSentinel => false;

  HeapGraphElement getField(String name) {
    if (theClass is HeapGraphClassLive) {
      final HeapGraphClassLive c = theClass;
      for (HeapSnapshotField field in c.origin.fields) {
        if (field.name == name) {
          return references[field.index];
        }
      }
    }
    return null;
  }

  List<MapEntry<String, HeapGraphElement>> getFields() {
    final List<MapEntry<String, HeapGraphElement>> result = [];
    if (theClass is HeapGraphClassLive) {
      final HeapGraphClassLive c = theClass;
      for (final field in c.origin.fields) {
        // TODO(terry): Is index out of range, replace with assert?
        if (field.index < references.length) {
          result.add(MapEntry(field.name, references[field.index]));
        } else {
          log(
            'ERROR Field Range: name=${field.name},index=${field.index}',
            LogLevel.error,
          );
        }
      }
    }
    return result;
  }

  @override
  String toString() {
    if (origin.data is HeapSnapshotObjectNoData) {
      return 'Instance of $theClass';
    }
    if (origin.data is HeapSnapshotObjectLengthData) {
      final HeapSnapshotObjectLengthData data = origin.data;
      return 'Instance of $theClass length = ${data.length}';
    }
    return 'Instance of $theClass; data: \'${origin.data}\'';
  }
}

/// Live ExternalProperty.
class HeapGraphExternalLive extends HeapGraphElement {
  HeapGraphExternalLive(this.externalProperty, this.live);

  final HeapSnapshotExternalProperty externalProperty;
  final HeapGraphElementLive live;

  @override
  bool get isSentinel => false;

  @override
  String toString() {
    if (live.origin.data is HeapSnapshotObjectNoData) {
      return 'Instance of ${live.theClass}';
    }
    if (live.origin.data is HeapSnapshotObjectLengthData) {
      final HeapSnapshotObjectLengthData data = live.origin.data;
      return 'Instance of ${live.theClass} length = ${data.length}';
    }
    return 'Instance of ${live.theClass}; data: \'${live.origin.data}\'';
  }
}

abstract class HeapGraphClass {
  final List<HeapGraphElementLive> _instances = [];

  int instancesTotalShallowSizes = 0;

  void addInstance(HeapGraphElementLive instance) {
    _instances.add(instance);
  }

  List<HeapGraphElementLive> getInstances(HeapGraph graph) {
    if (_instances == null) {
      for (var i = 0; i < graph.elements.length; i++) {
        final HeapGraphElementLive converted = graph.elements[i];
        if (converted.theClass == this) {
          _instances.add(converted);
        }
      }
    }
    return _instances;
  }

  /// Quick short-circuit to return real size of null implies '--' yet to be
  /// computed or N/A.
  int get instancesCount => _instances == null ? null : _instances.length;
}

class HeapGraphClassSentinel extends HeapGraphClass {
  @override
  String toString() => 'HeapGraphClassSentinel';
}

class HeapGraphClassLive extends HeapGraphClass {
  HeapGraphClassLive(this.origin) {
    _check();
  }

  void _check() {
    assert(origin != null);
  }

  final HeapSnapshotClass origin;

  String get name => origin.name;

  Uri get libraryUri => origin.libraryUri;

  LibraryClass get fullQualifiedName =>
      LibraryClass(libraryUri.toString(), name);

  @override
  String toString() => name;
}
