// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../flutter/memory_controller.dart';

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
};

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
  // Sentinals are objects that are marked to be GC'd.
  final HeapGraphClassSentinel classSentinel = HeapGraphClassSentinel();
  final HeapGraphElementSentinel elementSentinel = HeapGraphElementSentinel();

  final Map<LibraryClass, int> builtInClasses = {};

  if (classNamesToMonitor != null && classNamesToMonitor.isNotEmpty) {
    print('WARNING: Remove classNamesToMonitor before PR submission. '
        '$classNamesToMonitor');
  }

  // Construct all the classes in the snapshot.
  final List<HeapGraphClassLive> classes =
      List<HeapGraphClassLive>(graph.classes.length);
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
      List<HeapGraphElementLive>(graph.objects.length);

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
      converted.theClass = classSentinel;
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
          ref = elementSentinel;
        } else {
          ref = elements[refId - 1];
        }
        converted.references.add(ref);
      }
    };
  }

  return HeapGraph(
    controller,
    builtInClasses,
    classSentinel,
    classes,
    elementSentinel,
    elements,
  );
}

class HeapGraph {
  HeapGraph(
    this.controller,
    this.builtInClasses,
    this.classSentinel,
    this.classes,
    this.elementSentinel,
    this.elements,
  );

  final MemoryController controller;

  bool _instancesComputed = false;

  bool get instancesComputed => _instancesComputed;

  /// Known built-in classes.
  final Map<LibraryClass, int> builtInClasses;

  /// Sentinel Class, all class sentinels point to this object.
  final HeapGraphClassSentinel classSentinel;

  /// Indexed by classId.
  final List<HeapGraphClassLive> classes;

  /// Sentinel Object, all object sentinels point to this object.
  final HeapGraphElementSentinel elementSentinel;

  /// Index by objectId.
  final List<HeapGraphElementLive> elements;

  /// Group all classes by all libraries.
  final Map<String, List<HeapGraphClassLive>> rawGroupByLibrary = {};

  /// Group all classes by libraries - with applied filters.
  final Map<String, List<HeapGraphClassLive>> groupByLibrary = {};

  /// Group all instances by all classes.
  final Map<String, List<HeapGraphElementLive>> rawGroupByClass = {};

  /// Group all instances by all classes - with applied filters.
  final Map<String, List<HeapGraphElementLive>> groupByClass = {};

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
      rawGroupByLibrary[librarySbToString] ??= [];
      rawGroupByLibrary[librarySbToString].add(c);
      sb.clear();

      // Collect instances for each class (group by class)
      for (final instance in c.getInstances(this)) {
        sb.write(c.name);
        c.instancesTotalShallowSizes += instance.origin.shallowSize;
        final classSbToString = sb.toString();
        rawGroupByClass[classSbToString] ??= [];
        rawGroupByClass[classSbToString].add(instance);
        sb.clear();
      }
    }
  }

  bool computeFilteredGroups() {
    // Clone groupByClass from raw group.
    groupByClass.clear();
    rawGroupByClass.forEach((key, value) {
      groupByClass[key] = value.toList();
    });

    // Prune classes that are private or have zero instances.
    groupByClass.removeWhere((className, instances) =>
        (controller.filterZeroInstances.value && instances.isEmpty) ||
        (controller.filterPrivateClasses.value && className.startsWith('_')) ||
        className == internalClassName);

    // Clone groupByLibrary from raw group.
    groupByLibrary.clear();
    rawGroupByLibrary.forEach((key, value) {
      groupByLibrary[key] = value.toList();
    });

    // Prune libraries if all their classes are private or have zero instances.
    groupByLibrary.removeWhere((libraryName, classes) {
      classes.removeWhere((actual) =>
          (controller.filterZeroInstances.value &&
              actual.getInstances(this).isEmpty) ||
          (controller.filterPrivateClasses.value &&
              actual.name.startsWith('_')) ||
          actual.name == internalClassName);

      // Hide this library?
      if (controller.libraryFilters.isLibraryFiltered(libraryName)) return true;

      return controller.filterLibraryNoInstances.value && classes.isEmpty;
    });

    return true;
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
}

/// Object marked for removal on next GC.
class HeapGraphElementSentinel extends HeapGraphElement {
  @override
  String toString() => 'HeapGraphElementSentinel';
}

/// Live element.
class HeapGraphElementLive extends HeapGraphElement {
  HeapGraphElementLive(this.origin);

  final HeapSnapshotObject origin;
  HeapGraphClass theClass;

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
        // TODO(terry): Some index are out of range, this check should be removed.
        if (field.index < references.length) {
          result.add(MapEntry(field.name, references[field.index]));
        } else {
          print('ERROR Field Range: name=${field.name},index=${field.index}');
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

abstract class HeapGraphClass {
  final List<HeapGraphElementLive> _instances = [];

  int instancesTotalShallowSizes = 0;

  void addInstance(HeapGraphElementLive instance) {
    _instances.add(instance);
  }

  List<HeapGraphElementLive> getInstances(HeapGraph graph) {
    // TODO(terry): Delay would be much faster but retained space needs
    //              computation. Remove if block just return _instances?
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
