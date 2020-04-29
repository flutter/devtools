// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../flutter/memory_controller.dart';

// TODO(terry): Ask Ben, what is a class name of ::?
/// Internal class names :: automatically filter out.
const String internalClassName = '::';

// TODO(terry): Bake in types instead of comparing a fully qualified class name.
const String predefinedNull = 'dart:core,Null';
const String predefinedString = 'dart:core,_OneByteString';
const String predefinedList = 'dart:core,_List';
const String predefinedMap = 'dart:collection,_InternalLinkedHashMap';

class Predefined {
  const Predefined(this.prettyName, this.isScalar);

  final String prettyName;
  final bool isScalar;
}

/// Structure key is fully qualified class name and the value is
/// a List first entry is pretty name known to users second entry
/// is if the type is a scalar.
const Map<String, Predefined> predefinedClasses = {
  'dart:core,bool': Predefined('bool', true),
  // TODO(terry): Handle Smi too (Integer)?
  // Integers not Smi but fit into 64bits.
  'dart:core,_Mint': Predefined('int', true),
  'dart:core,_Double': Predefined('Double', true),
  predefinedString: Predefined('String', true),
  predefinedList: Predefined('List', false),
  predefinedMap: Predefined('Map', false),
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

  final Map<String, int> builtInClasses = {};

  if (classNamesToMonitor != null && classNamesToMonitor.isNotEmpty) {
    print('WARNING: Remove classNamesToMonitor before PR submission. '
        '$classNamesToMonitor');
  }

  // Construct all the classes in the snapshot.
  final List<HeapGraphClassActual> classes =
      List<HeapGraphClassActual>(graph.classes.length);
  for (int i = 0; i < graph.classes.length; i++) {
    final HeapSnapshotClass c = graph.classes[i];

    final className = c.name;
    // Remember builtin classes classId e.g., bool, String (_OneByteString), etc.
    // The classId is the index into the graph.classes list.
    final libraryClassName = '${c.libraryUri},${c.name}';
    // It's a exact match libraryName,className once we match the classId drives
    // the class matching.
    if (predefinedClasses.containsKey(libraryClassName)) {
      builtInClasses.putIfAbsent(libraryClassName, () => i);
    }

    // Debugging code to monitor a particular class.  ClassesToMonitor should be
    // empty before commiting PRs.
    if (classNamesToMonitor != null &&
        classNamesToMonitor.isNotEmpty &&
        classNamesToMonitor.contains(className)) {
      print('WARNING: class $className is monitored.');
      _monitorClasses.putIfAbsent(i, () => className);
    }

    classes[i] = HeapGraphClassActual(c);
  }

  // Pre-allocate the number of objects in the snapshot.
  final List<HeapGraphElementActual> elements =
      List<HeapGraphElementActual>(graph.objects.length);

  // Construct all objects.
  for (int i = 0; i < graph.objects.length; i++) {
    final HeapSnapshotObject o = graph.objects[i];
    elements[i] = HeapGraphElementActual(o);
  }

  // Associate each object with a Class.
  for (int i = 0; i < graph.objects.length; i++) {
    final HeapSnapshotObject o = graph.objects[i];
    final HeapGraphElementActual converted = elements[i];
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

  bool instancesComputed = false;

  /// Known built-in classes.
  final Map<String, int> builtInClasses;

  /// Sentinel Class, all class sentinels point to this object.
  final HeapGraphClassSentinel classSentinel;

  /// Indexed by classId.
  final List<HeapGraphClassActual> classes;

  /// Sentinel Object, all object sentinels point to this object.
  final HeapGraphElementSentinel elementSentinel;

  /// Index by objectId.
  final List<HeapGraphElementActual> elements;

  /// Group all classes by all libraries.
  final Map<String, List<HeapGraphClassActual>> rawGroupByLibrary = {};

  /// Group all classes by libraries - with applied filters.
  final Map<String, List<HeapGraphClassActual>> groupByLibrary = {};

  /// Group all instances by all classes.
  final Map<String, List<HeapGraphElementActual>> rawGroupByClass = {};

  /// Group all instances by all classes - with applied filters.
  final Map<String, List<HeapGraphElementActual>> groupByClass = {};

  String normalizeLibraryName(HeapSnapshotClass theClass) {
    final uri = theClass.libraryUri;
    final scheme = uri.scheme;

    if (scheme == 'package' || scheme == 'dart') {
      return '$scheme:${uri.pathSegments[0]}';
    }

    assert(theClass.libraryName.isEmpty);
    return 'src';
  }

  bool computeRawGroups() {
    // Only compute once.
    if (rawGroupByLibrary.isNotEmpty || rawGroupByClass.isNotEmpty) return true;

    for (HeapGraphClassActual c in classes) {
      final StringBuffer sb = StringBuffer();

      final libraryKey = normalizeLibraryName(c.origin);

      // Collect classes for each library (group by library).
      sb.write(libraryKey);
      final librarySbToString = sb.toString();
      rawGroupByLibrary[librarySbToString] ??= [];
      rawGroupByLibrary[librarySbToString].add(c);
      sb.clear();

      // Collect instances for each class (group by class)
      for (HeapGraphElementActual instance in c.getInstances(this)) {
        sb.write(c.name);
        c.instancesTotalShallowSizes += instance.origin.shallowSize;
        final classSbToString = sb.toString();
        rawGroupByClass[classSbToString] ??= [];
        rawGroupByClass[classSbToString].add(instance);
        sb.clear();
      }
    }

    return true;
  }

  bool computeFilteredGroups() {
    // Clone groupByClass from raw group.
    groupByClass.clear();
    rawGroupByClass.forEach((key, value) {
      groupByClass[key] = value.toList();
    });

    // Prune classes that are private or have zero instances.
    groupByClass.removeWhere((className, instances) =>
        (controller.filterZeroInstances && instances.isEmpty) ||
        (controller.filterPrivateClasses && className.startsWith('_')) ||
        className == internalClassName);

    // Clone groupByLibrary from raw group.
    groupByLibrary.clear();
    rawGroupByLibrary.forEach((key, value) {
      groupByLibrary[key] = value.toList();
    });

    // Prune libraries if all their classes are private or have zero instances.
    groupByLibrary.removeWhere((libraryName, classes) {
      classes.removeWhere((actual) =>
          (controller.filterZeroInstances &&
              actual.getInstances(this).isEmpty) ||
          (controller.filterPrivateClasses && actual.name.startsWith('_')) ||
          actual.name == internalClassName);

      // Hide this library?
      if (controller.libraryFilters.isLibraryFiltered(libraryName)) return true;

      return controller.filterLibraryNoInstances && classes.isEmpty;
    });

    return true;
  }

  // TODO(terry): Need dominator graph for flow.
  /// Compute all instances, needed for retained space.
  void computeInstancesForClasses() {
    if (!instancesComputed) {
      for (var i = 0; i < elements.length; i++) {
        final HeapGraphElementActual instance = elements[i];
        instance.theClass.addInstance(instance);
      }

      instancesComputed = true;
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

  String getPrettyPrint(Map<Uri, Map<String, List<String>>> prettyPrints) {
    if (this is HeapGraphElementActual) {
      final HeapGraphElementActual me = this;
      if (me.theClass.toString() == '_OneByteString') {
        return '"${me.origin.data}"';
      }
      if (me.theClass.toString() == '_SimpleUri') {
        return '_SimpleUri['
            "${me.getField("_uri").getPrettyPrint(prettyPrints)}]";
      }
      if (me.theClass.toString() == '_Uri') {
        return "_Uri[${me.getField("scheme").getPrettyPrint(prettyPrints)}:"
            "${me.getField("path").getPrettyPrint(prettyPrints)}]";
      }
      if (me.theClass is HeapGraphClassActual) {
        final HeapGraphClassActual c = me.theClass;
        final Map<String, List<String>> classToFields =
            prettyPrints[c.libraryUri];
        if (classToFields != null) {
          final List<String> fields = classToFields[c.name];
          if (fields != null) {
            return '${c.name}[' +
                fields.map((field) {
                  return '$field: '
                      '${me.getField(field)?.getPrettyPrint(prettyPrints)}';
                }).join(', ') +
                ']';
          }
        }
      }
    }
    return toString();
  }
}

/// Object marked for removal on next GC.
class HeapGraphElementSentinel extends HeapGraphElement {
  @override
  String toString() => 'HeapGraphElementSentinel';
}

/// Live element.
class HeapGraphElementActual extends HeapGraphElement {
  HeapGraphElementActual(this.origin);

  final HeapSnapshotObject origin;
  HeapGraphClass theClass;

  HeapGraphElement getField(String name) {
    if (theClass is HeapGraphClassActual) {
      final HeapGraphClassActual c = theClass;
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
    if (theClass is HeapGraphClassActual) {
      final HeapGraphClassActual c = theClass;
      for (HeapSnapshotField field in c.origin.fields) {
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
  final List<HeapGraphElementActual> _instances = [];

  int instancesTotalShallowSizes = 0;

  void addInstance(HeapGraphElementActual instance) {
    _instances.add(instance);
  }

  List<HeapGraphElementActual> getInstances(HeapGraph graph) {
    // TODO(terry): Delay would be much faster but retained space needs
    //              computation. Remove if block just return _instances?
    if (_instances == null) {
      for (int i = 0; i < graph.elements.length; i++) {
        final HeapGraphElementActual converted = graph.elements[i];
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

class HeapGraphClassActual extends HeapGraphClass {
  HeapGraphClassActual(this.origin) {
    _check();
  }

  void _check() {
    assert(origin != null);
  }

  final HeapSnapshotClass origin;

  String get name => origin.name;

  Uri get libraryUri => origin.libraryUri;

  String get fullQualifiedName => '${libraryUri.toString()},$name';

  @override
  String toString() => name;
}
