// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../../trees.dart';
import '../flutter/memory_controller.dart';
import '../flutter/memory_graph_model.dart';

/// Consolidated list of libraries.  External is the external heap
/// and Filtered is the sum of all filtered (hidden) libraries.
const String externalLibraryName = 'External';
const String filteredLibrariesName = 'Filtered';

/// Name for predefined Reference and FieldReference should never be
/// seen by user.
const String emptyName = '<empty>';
const String sentinelName = '<sentinel>';

class Reference extends TreeNode<Reference> {
  Reference._empty()
      : controller = null,
        name = emptyName,
        isLibrary = false,
        isExternal = false,
        isFiltered = false,
        isClass = false,
        isObject = false,
        actualClass = null;

  Reference._sentinel()
      : controller = null,
        name = sentinelName,
        isLibrary = false,
        isExternal = false,
        isFiltered = false,
        isClass = false,
        isObject = false,
        actualClass = null;

  Reference.createLibrary(this.controller, this.name,
      {this.onExpand, this.onLeaf})
      : isLibrary = true,
        isExternal = false,
        isFiltered = false,
        isClass = false,
        isObject = false,
        actualClass = null;

  Reference.createClass(
    this.controller,
    this.actualClass, {
    this.onExpand,
    this.onLeaf,
  })  : name = actualClass.name,
        isLibrary = false,
        isExternal = false,
        isFiltered = false,
        isClass = true,
        isObject = false;

  /// name is the object name.
  Reference.createObject(
    this.controller,
    this.name, {
    this.onExpand,
    this.onLeaf,
  })  : isLibrary = false,
        isExternal = false,
        isFiltered = false,
        isClass = false,
        isObject = true,
        actualClass = null;

  // TODO(terry): Investigate expanding to view all external objects/field inspection?
  /// External heap
  Reference.createExternal(this.controller)
      : isLibrary = false,
        isExternal = true,
        isFiltered = false,
        isClass = false,
        isObject = false,
        actualClass = null,
        name = externalLibraryName;

  // TODO(terry): Investigate expanding to view filtered items.
  /// All filtered libraries and classes
  Reference.createFiltered(this.controller)
      : isLibrary = false,
        isExternal = false,
        isFiltered = true,
        isClass = false,
        isObject = false,
        actualClass = null,
        name = filteredLibrariesName;

  static Reference empty = Reference._empty();

  bool get isEmptyReference => this == empty;

  static Reference sentinel = Reference._sentinel();

  bool get isSentinelReference => this == sentinel;

  final MemoryController controller;

  final HeapGraphClassLive actualClass;

  final String name;

  final bool isLibrary;

  final bool isExternal;

  final bool isFiltered;

  final bool isClass;

  final bool isObject;

  Function onExpand;

  Function onLeaf;

  @override
  void expand() {
    if (onExpand != null) {
      onExpand(this);
      controller.selectedLeaf = null;
    }
    super.expand();
  }

  @override
  void leaf() {
    assert(isObject);

    final objectReference = this as ObjectReference;
    controller.selectedLeaf = objectReference.instance;
    if (onLeaf != null) onLeaf(this);

    super.leaf();
  }
}

class LibraryReference extends Reference {
  LibraryReference(
      MemoryController controller, String libraryName, this.actualClasses)
      : super.createLibrary(
          controller,
          libraryName,
          onExpand: (reference) {
            assert(reference.isLibrary);

            // Need to construct the children.
            if (reference.children.isNotEmpty &&
                reference.children.first.isEmptyReference) {
              reference.children.clear();

              final libraryReference = reference as LibraryReference;
              for (final actualClass in libraryReference.actualClasses) {
                final classRef = ClassReference(controller, actualClass);
                reference.addChild(classRef);

                // Add place holders for the instances.
                final instances =
                    actualClass.getInstances(controller.heapGraph);
                classRef.addAllChildren(List.filled(
                  instances.length,
                  Reference.empty,
                ));
              }
            }
          },
        );

  List<HeapGraphClassLive> actualClasses;
}

class ExternalReference extends Reference {
  ExternalReference(MemoryController controller)
      : super.createExternal(controller);
}

class FilteredReference extends Reference {
  FilteredReference(MemoryController controller)
      : super.createFiltered(controller);
}

class ClassReference extends Reference {
  ClassReference(MemoryController controller, HeapGraphClassLive actualClass)
      : super.createClass(
          controller,
          actualClass,
          onExpand: (reference) {
            // Need to construct the children.
            if (reference.children.isNotEmpty &&
                reference.children.first.isEmptyReference) {
              reference.children.clear();

              final classReference = reference as ClassReference;

              final instances =
                  classReference.actualClass.getInstances(controller.heapGraph);

              for (var index = 0; index < instances.length; index++) {
                final instance = instances[index];
                final objectRef = ObjectReference(controller, index, instance);
                classReference.addChild(objectRef);
              }
            }
          },
        );

  List<HeapGraphElementLive> get instances =>
      actualClass.getInstances(controller.heapGraph);
}

class ObjectReference extends Reference {
  ObjectReference(MemoryController controller, int index, this.instance)
      : super.createObject(controller, 'Instance $index');

  final HeapGraphElementLive instance;
}

class Snapshot {
  Snapshot(this.collectedTimestamp, this.controller, this.snapshotGraph);

  final MemoryController controller;
  final DateTime collectedTimestamp;
  final HeapSnapshotGraph snapshotGraph;

  final Map<String, LibraryReference> libraries = {};

  List<LibraryReference> librariesToList() =>
      libraries.entries.map((entry) => entry.value).toList();

  List<HeapSnapshotClass> get classes => snapshotGraph.classes;
}

/// Base class for inspecting an instance field type, field name, and value.
class FieldReference extends TreeNode<FieldReference> {
  FieldReference._empty()
      : controller = null,
        instance = null,
        name = emptyName,
        isScaler = false,
        isObject = false,
        type = null,
        value = null;

  FieldReference._sentinel()
      : controller = null,
        instance = null,
        name = sentinelName,
        isScaler = false,
        isObject = false,
        type = null,
        value = null;

  FieldReference.createScaler(
      this.controller, this.instance, this.type, this.name, this.value)
      : isScaler = true,
        isObject = false;

  FieldReference.createObject(
    this.controller,
    this.instance,
    this.type,
    this.name, {
    this.onExpand,
  })  : value = null,
        isScaler = false,
        isObject = true;

  static FieldReference empty = FieldReference._empty();

  bool get isEmptyReference => this == empty;

  static FieldReference sentinel = FieldReference._sentinel();

  bool get isSentinelReference => this == sentinel;

  final MemoryController controller;

  final HeapGraphElementLive instance;

  final String type;

  final String name;

  final String value;

  final bool isScaler;

  final bool isObject;

  Function onExpand;

  @override
  void expand() {
    if (onExpand != null) {
      onExpand(this);
    }
    super.expand();
  }
}

class ScalarFieldReference extends FieldReference {
  ScalarFieldReference(
    MemoryController controller,
    HeapGraphElementLive instance,
    String type,
    String name,
    String value,
  ) : super.createScaler(
          controller,
          instance,
          type,
          name,
          value,
        );
}

class ObjectFieldReference extends FieldReference {
  ObjectFieldReference(
    MemoryController controller,
    HeapGraphElementLive instance,
    String type,
    String name, {
    this.isNull = false,
  }) : super.createObject(
          controller,
          instance,
          type,
          name,
          onExpand: (reference) {
            // Need to construct the children.
            if (reference.children.isNotEmpty &&
                reference.children.first.isEmptyReference) {
              reference.children.clear();

              // Null value nothing to expand.
              if (reference.isScaler) return;

              assert(reference.isObject);
              final objectFieldReference = reference as ObjectFieldReference;

              final objFields = instanceToFieldNodes(
                controller,
                objectFieldReference.instance,
              );

              objectFieldReference.addAllChildren(objFields);
            }
          },
        );

  final bool isNull;
}

/// Return list of FieldReference nodes (TableTree use) from the fields of an instance.
List<FieldReference> instanceToFieldNodes(
  MemoryController controller,
  HeapGraphElementLive instance,
) {
  final List<FieldReference> root = [];
  final List<MapEntry<String, HeapGraphElement>> fields = instance.getFields();

  var sentinel = 0;
  var fieldIndex = 0;
  for (var fieldElement in fields) {
    // Ignore internal patching fields.
    if (fieldElement.key != '__parts') {
      if (fieldElement.value is! HeapGraphElementSentinel &&
          instance.references[fieldIndex] is! HeapGraphElementSentinel) {
        root.add(fieldToFieldReference(
          controller,
          instance,
          fieldElement,
          fieldIndex,
        ));
      } else {
        sentinel++;
        root.add(FieldReference.sentinel);
      }
    }
    fieldIndex++;
  }

  if (root.length > 1 && sentinel > 0) {
    root.removeWhere((e) => e.isSentinelReference);
  }

  return root;
}

/// Return a FieldReference node (TableTree use) from the field of an instance.
FieldReference fieldToFieldReference(
  MemoryController controller,
  HeapGraphElementLive instance,
  MapEntry<String, HeapGraphElement> fieldElement,
  int fieldIndex,
) {
  if (fieldElement.value is HeapGraphElementSentinel) {
    // TODO(terry): Debug for now, eliminate, user's don't need to know.
    return FieldReference.sentinel;
  }

  final actual = fieldElement.value as HeapGraphElementLive;
  final theGraph = controller.heapGraph;

  final int indexIntoClass = actual.origin.classId; // One based Index.
  if (!controller.heapGraph.builtInClasses.containsValue(indexIntoClass - 1)) {
    return objectToFieldReference(
      controller,
      theGraph,
      fieldElement,
      actual,
    );
  } else {
    final data = actual.origin.data;
    if (data.runtimeType == HeapSnapshotObjectLengthData) {
      final HeapGraphElementLive actual = instance.references[fieldIndex];
      final HeapGraphClassLive theClass = actual.theClass;
      final fullClassName = theClass.fullQualifiedName;
      if (fullClassName == predefinedMap) {
        return listToFieldEntries(
            controller, actual, fieldElement.key, data.length);
      } else if (fullClassName == predefinedList) {
        return listToFieldEntries(
            controller, actual, fieldElement.key, data.length);
      }
    }

    return createScalar(controller, fieldElement.key, actual);
  }
}

/// Create a scalar field for display in the Table Tree.
FieldReference createScalar(
  MemoryController controller,
  String fieldName,
  HeapGraphElementLive actual,
) {
  final data = actual.origin.data;

  String dataValue;
  String dataType = '';
  switch (data.runtimeType) {
    case HeapSnapshotObjectNoData:
      dataValue = 'Object No Data';
      break;
    case HeapSnapshotObjectNullData:
      dataValue = 'null';
      break;
    case HeapSnapshotObjectLengthData:
      assert(false, 'Unexpected object - expected scalar.');
      break;
    default:
      dataValue = data.toString();
      final dataTypeClass =
          controller.heapGraph.classes[actual.origin.classId - 1];
      final predefined = predefinedClasses[dataTypeClass.fullQualifiedName];
      dataType = predefined.prettyName;
  }

  return FieldReference.createScaler(
    controller,
    actual,
    dataType,
    fieldName,
    dataValue,
  );
}

/// Display a List.
FieldReference listToFieldEntries(
  MemoryController controller,
  HeapGraphElement reference,
  String fieldName,
  int size,
) {
  bool isMap = false;
  HeapGraphElementLive actualListElement;
  ObjectFieldReference listObjectReference;
  if (reference is HeapGraphElementLive) {
    final actualListClass = reference.theClass as HeapGraphClassLive;
    final fullClassName = actualListClass.fullQualifiedName;
    if (fullClassName == predefinedList) {
      // Add the list entry.
      actualListElement = reference;
      listObjectReference = ObjectFieldReference(
        controller,
        actualListElement,
        'List',
        '[$size]',
      );
    } else if (fullClassName == predefinedMap) {
      // Add the Map field name and the key/value pairs.
      actualListElement = reference;
      listObjectReference = ObjectFieldReference(
        controller,
        actualListElement,
        'Map',
        '$fieldName { ${size ~/ 2} }',
      );

      // Look for list of Map values.
      for (final reference in actualListElement.references) {
        if (reference is HeapGraphElementLive) {
          final HeapGraphClassLive theClass = reference.theClass;
          final fullClassName = theClass.fullQualifiedName;
          if (fullClassName == predefinedList) {
            actualListElement = reference;
            isMap = true;
            break;
          }
        }
      }
    }
  }

  assert(listObjectReference != null);

  var listIndex = 0;
  final allEntryReferences = actualListElement.references;
  final referencesLength = allEntryReferences.length;

  // Find all the Map key/value pairs (for integer keys the key maybe missing).
  // TODO(terry): Need to verify.
  final List<HeapGraphElement> realEntries = [];
  for (var entryElementIndex = 0;
      entryElementIndex < referencesLength;
      entryElementIndex++) {
    final entry = allEntryReferences[entryElementIndex];
    if (entry is HeapGraphElementLive) {
      final HeapGraphElementLive entryElement = entry;
      final HeapGraphClassLive actualClass = entryElement.theClass;
      if (actualClass.fullQualifiedName != predefinedNull) {
        realEntries.add(entryElement);
      }
    }
  }

  // TODO(terry): Need to verify.
  // Only value key if size != to number of real entries.
  final hasKeyValues = isMap && realEntries.length == size;

  for (var realEntryIndex = 0;
      realEntryIndex < realEntries.length;
      realEntryIndex++) {
    final entryElement = realEntries[realEntryIndex];
    if (entryElement is HeapGraphElementLive) {
      final entryClass = entryElement.theClass;
      if (entryClass is HeapGraphClassLive &&
          entryClass.fullQualifiedName != predefinedNull) {
        final predefined = predefinedClasses[entryClass.fullQualifiedName];
        FieldReference listEntry;
        if (predefined != null && predefined.isScalar) {
          if (isMap) {
            if (hasKeyValues) {
              final HeapGraphElementLive valueElement =
                  realEntries[realEntryIndex + 1];
              realEntryIndex++;
              // The value entry is computed on key expansion.
              var predefined = predefinedClasses[entryClass.fullQualifiedName];
              listEntry = ObjectFieldReference(
                controller,
                entryElement,
                '${predefined.prettyName}',
                'key \'${entryElement.origin.data}\'',
              );

              FieldReference valueEntry;
              final HeapGraphClassLive valueClass = valueElement.theClass;
              predefined = predefinedClasses[valueClass.fullQualifiedName];
              if (predefined != null && predefined.isScalar) {
                valueEntry = createScalar(controller, 'value', valueElement);
              } else {
                valueEntry = ObjectFieldReference(
                  controller,
                  valueElement,
                  valueClass.name,
                  'value',
                );
                // Compute the object's fields when onExpand hit.
                valueEntry.addChild(FieldReference.empty);
              }
              listEntry.addChild(valueEntry);
            } else {
              // This is the value w/o any idea the index is the key.
              listEntry =
                  createScalar(controller, 'value $listIndex', entryElement);
            }
          } else {
            // Display the scalar entry.
            listEntry = createScalar(controller, fieldName, entryElement);
          }
        } else {
          // The List entries are computed on expansion.
          listEntry = ObjectFieldReference(
            controller,
            entryElement,
            entryClass.name,
            '[$listIndex]',
          );
        }

        // Entry type to expand later.
        if (!isMap) {
          listEntry.addChild(FieldReference.empty);
        }

        // Add our [n] entry.
        listObjectReference.addChild(listEntry);

        // TODO(terry): Consider showing all entries - is it useful?
        // Add each entry to the list, up to 100.
        if (listIndex++ > 100) break;
      }
    }
  }

  return listObjectReference;
}

/// Return a ObjectFieldReference node (TableTree use) from the field that
/// is an object (instance).  This object's field will be computed when
/// the ObjectFieldReference node is expanded.
FieldReference objectToFieldReference(
  MemoryController controller,
  HeapGraph theGraph,
  MapEntry<String, HeapGraphElement> objectEntry,
  HeapGraphElementLive actual,
) {
  final elementActual = objectEntry.value as HeapGraphElementLive;
  final classActual = elementActual.theClass as HeapGraphClassLive;

  final isNullValue = actual.origin.data == null;
  final reference = ObjectFieldReference(
    controller,
    actual,
    classActual.name,
    objectEntry.key,
    isNull: isNullValue,
  );

  // If the object isn't null then add one fake empty child, so node
  // can be expanded.  The object's fields are computed on expansion.
  reference.addAllChildren(List.filled(
    isNullValue ? 0 : 1,
    FieldReference.empty,
  ));

  return reference;
}
