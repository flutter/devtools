// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';
import '../../trees.dart';

class Reference extends TreeNode<Reference> {
  Reference.empty()
      : _graph = null,
        name = null,
        _library = false;

  Reference.createLibrary(this._graph, this.name, {this.onExpand})
      : _library = true;

  Reference.createClass(this._graph, int classId, {this.onExpand})
      : _library = false,
        name = _graph.classes[classId].name;

  /// name is the object name.
  Reference.createObject(this._graph, this.name, {this.onExpand})
      : _library = false;

  /// Hide the default constructor.
  Reference._()
      : _graph = null,
        name = null,
        _library = false;

  final HeapSnapshotGraph _graph;

  final String name;

  final bool _library;

  bool get isEmpty => _graph == null;

  HeapSnapshotGraph get graph => _graph;

  bool get isLibrary => _library;

  bool get isClass => !_library;

  Function onExpand;

  @override
  void expand() {
    if (onExpand != null) onExpand(this);
    super.expand();
  }
}

class LibraryReference extends Reference {
  LibraryReference(HeapSnapshotGraph graph, String libraryName, this.uri)
      : super.createLibrary(graph, libraryName, onExpand: (reference) {
          // Delay classes computation until library is expanded.
          final libraryRef = reference as LibraryReference;
          if (!libraryRef.isClassesComputed && libraryRef.classIds.isNotEmpty) {
            // Throw away all fake empty entries.
            libraryRef.children.clear();
            // Compute live allocated classes from this library.
            if (libraryRef.name == '') {
              print(">>>> STOP empty");
            }
            libraryRef.computeClasses();
          }
        });

  final String uri;

  bool _classesComputed = false;

  bool get isClassesComputed => _classesComputed;

  /// List of classes associated with this library.
  final List<int> classIds = [];

  final List<ClassReference> classes = [];

  HeapSnapshotClass getClassDetail(ClassReference classRef) =>
      _graph?.classes[classRef.classId];

  void computeClasses() {
    if (!isClassesComputed) {
      for (var classId in classIds) {
        final classRef = ClassReference(graph, classId);
//if (classRef.name.startsWith('Terry')) {
if (classRef.classId >= 4280 && classRef.classId <=4290) {
          print(">>>> STOP class ${classRef.name}, classId=${classRef.classId}");
}
        // TODO(terry): classes is redudant - remove.

//if (classRef.name.startsWith('Terry')) {
if (classRef.classId >= 4280 && classRef.classId <=4290) {

        classes.add(classRef);
        children.add(classRef);
}
      }

      // Each class has been computed set the flag. Maybe we can reuse if order
      // by object instead of library/class.
      // TODO(terry): Maybe premature?
      for (var classRef in classes) {
        classRef._computed = true;
      }

      // All classes in library computed.
      _classesComputed = true;
    }
  }
}

class ClassReference extends Reference {
  ClassReference(HeapSnapshotGraph graph, this.classId)
      : super.createClass(graph, classId, onExpand: (reference) {
          // Delay classes computation until library is expanded.
          final classRef = reference as ClassReference;
          print(">>>> expanding ClassRef ${classRef.name}<<<<<");
          if (classRef.isComputed) {
            // Remove the fake child for we can expand.
            classRef.children.clear();
            classRef.computeObjects();
          }
        }) {
    children.add(Reference.empty());
  }

  int classId;

  bool _computed = false;

  bool get isComputed => _computed;

  List<int> objectIndexes = [];

  void computeObjects() {
    final objectsLength = _graph.objects.length;
    print(">>> computeObjects objectsLength=$objectsLength");
    final objects = _graph.objects;
    for (var index = 0; index < objectsLength; index++) {
//print("index=$index, objects[index].classId=[${objects[index].classId}]");
      if (classId == objects[index].classId) {
        objectIndexes.add(index);
      }
    }
    for (var index in objectIndexes) {
      children.add(ObjectReference(graph, index));
    }

    _computed = true;
  }
}

class ObjectReference extends Reference {
  ObjectReference(HeapSnapshotGraph graph, this.objectIndex)
      : super.createObject(graph, 'object_$objectIndex', onExpand: (reference) {
          print(">>>> expanding ObjectReference <<<<<");
        });

  int objectIndex;
}

class Snapshot {
  Snapshot(this.collectedTimestamp, this.snapshotGraph) {
    root = LibraryReference(snapshotGraph, '___ROOT___', null);
  }

  final DateTime collectedTimestamp;
  final HeapSnapshotGraph snapshotGraph;

//  final Map<String, LibraryReference> libraries = {};

  LibraryReference root;

  List<Reference> librariesToList() =>
//      libraries.entries.map((entry) => entry.value).toList();
      root.children;

  List<HeapSnapshotClass> get classes => snapshotGraph.classes;

  void computeAllLibraries() {
    // Compute all libraries.

    // This is the classId (index in snapshotGraph.classes) is the classId
    // used to reference any class in objects, references, etc..
    var classId = 0;
    for (var classSnapshot in snapshotGraph.classes) {
      LibraryReference libReference = root.children.singleWhere((library) {
        return classSnapshot.libraryName == library.name;
      }, orElse: () => null);

      // Library not found add to list of children.
      if (libReference == null) {
        libReference = LibraryReference(
          snapshotGraph,
          classSnapshot.libraryName,
          classSnapshot.libraryUri.toString(),
        );
        root.addChild(libReference);
      }
      libReference.classIds.add(classId);

      classId++;
    }

    final emptyClass = Reference.empty();
    for (final entry in root.children) {
      assert(entry.isLibrary);
      final libRef = entry as LibraryReference;
      if (libRef.classIds.isNotEmpty) {
        // Add place holders for the classes.
        libRef.addAllChildren(List.filled(libRef.classIds.length, emptyClass));
      }
    }
  }

  void computeObjectsInLibrary(String libraryName) {
//    final library = libraries[libraryName];
// TODO(terry): Need to find base on libraryName.
//    final library = root.children[libraryName];
//    assert(library != null);
  }
}
