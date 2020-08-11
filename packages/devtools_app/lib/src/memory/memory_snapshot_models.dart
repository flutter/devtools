// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

import '../trees.dart';
import 'memory_controller.dart';
import 'memory_graph_model.dart';

/// Consolidated list of libraries.  External is the external heap
/// and Filtered is the sum of all filtered (hidden) libraries.
const externalLibraryName = 'External';
const filteredLibrariesName = 'Filtered';

/// Name for predefined Reference and FieldReference should never be
/// seen by user.
const emptyName = '<empty>';
const sentinelName = '<sentinel>';

class Reference extends TreeNode<Reference> {
  factory Reference({
    MemoryController argController,
    HeapGraphClassLive argActualClass,
    String argName,
    bool argIsAllocation = false,
    bool argIsAllocations = false,
    bool argIsAnalysis = false,
    bool argIsSnapshot = false,
    bool argIsLibrary = false,
    bool argIsExternals = false,
    bool argIsExternal = false,
    bool argIsFiltered = false,
    bool argIsClass = false,
    bool argIsObject = false,
    Function argOnExpand,
    Function argOnLeaf,
  }) {
    return Reference._internal(
      controller: argController,
      actualClass: argActualClass,
      name: argName,
      isAllocation: argIsAllocation,
      isAllocations: argIsAllocations,
      isAnalysis: argIsAnalysis,
      isSnapshot: argIsSnapshot,
      isLibrary: argIsLibrary,
      isExternals: argIsExternals,
      isFiltered: argIsFiltered,
      isClass: argIsClass,
      isObject: argIsObject,
      onExpand: argOnExpand,
      onLeaf: argOnLeaf,
    );
  }

  Reference._internal({
    this.controller,
    this.actualClass,
    this.name,
    this.isAllocation = false,
    this.isAllocations = false,
    this.isAnalysis = false,
    this.isSnapshot = false,
    this.isLibrary = false,
    this.isExternals = false,
    this.isExternal = false,
    this.isFiltered = false,
    this.isClass = false,
    this.isObject = false,
    this.onExpand,
    this.onLeaf,
  });

  factory Reference._empty() => Reference._internal(name: emptyName);

  factory Reference._sentinel() => Reference._internal(name: sentinelName);

  Reference.allocationsMonitor(
    String name, {
    Function onExpand,
    Function onLeaf,
  }) : this._internal(
          controller: null,
          name: name,
          isAllocations: true,
          onExpand: onExpand,
          onLeaf: onLeaf,
        );

  Reference.allocationMonitor(MemoryController controller, String name,
      {Function onExpand, Function onLeaf})
      : this._internal(
          controller: controller,
          name: name,
          isAllocation: true,
          onExpand: onExpand,
          onLeaf: onLeaf,
        );

  Reference.analysis(
    MemoryController controller,
    String name, {
    Function onExpand,
    Function onLeaf,
  }) : this._internal(
          controller: controller,
          name: name,
          isAnalysis: true,
          onExpand: onExpand,
          onLeaf: onLeaf,
        );

  Reference.snapshot(
    MemoryController controller,
    String name, {
    Function onExpand,
    Function onLeaf,
  }) : this._internal(
          controller: controller,
          name: name,
          isSnapshot: true,
          onExpand: onExpand,
          onLeaf: onLeaf,
        );

  Reference.library(
    MemoryController controller,
    String name, {
    Function onExpand,
    Function onLeaf,
  }) : this._internal(
          controller: controller,
          name: name,
          isLibrary: true,
          onExpand: onExpand,
          onLeaf: onLeaf,
        );

  Reference.aClass(
    MemoryController controller,
    HeapGraphClassLive actualClass, {
    Function onExpand,
    Function onLeaf,
  }) : this._internal(
          controller: controller,
          actualClass: actualClass,
          name: actualClass.name,
          isClass: true,
          onExpand: onExpand,
          onLeaf: onLeaf,
        );

  /// Name is the object name.
  Reference.object(
    MemoryController controller,
    String name, {
    Function onExpand,
    Function onLeaf,
  }) : this._internal(
          controller: controller,
          name: name,
          isObject: true,
          onExpand: onExpand,
          onLeaf: onLeaf,
        );

  /// External heap
  Reference.externals(
    MemoryController controller, {
    Function onExpand,
  }) : this._internal(
          controller: controller,
          name: externalLibraryName,
          isExternals: true,
          onExpand: onExpand,
        );

  /// External objects
  Reference.external(
    MemoryController controller,
    String name, {
    Function onExpand,
  }) : this._internal(
          controller: controller,
          name: name,
          isExternal: true,
          onExpand: onExpand,
        );

  /// All filtered libraries and classes
  Reference.filtered(MemoryController controller)
      : this._internal(
          controller: controller,
          name: filteredLibrariesName,
          isFiltered: true,
        );

  static Reference empty = Reference._empty();

  bool get isEmptyReference => this == empty;

  static Reference sentinel = Reference._sentinel();

  bool get isSentinelReference => this == sentinel;

  final MemoryController controller;

  final HeapGraphClassLive actualClass;

  final String name;

  /// Allocations are being monitored, user requested monitoring of any
  /// allocated memory.  Parent node containing all monitored classes.
  final bool isAllocations;

  /// A monitored class.
  final bool isAllocation;

  final bool isAnalysis;

  final bool isSnapshot;

  final bool isLibrary;

  /// The External heap (contains all external heap items).
  final bool isExternals;

  /// An External heap item.
  final bool isExternal;

  /// Class or Library is filtered.
  final bool isFiltered;

  final bool isClass;

  final bool isObject;

  int count;

  bool get hasCount => count != null;

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
    if (isObject) {
      final objectReference = this as ObjectReference;
      if (controller.selectedAnalysisLeaf != null ||
          controller.selectedAllocationMonitorLeaf != null) {
        controller.selectedAnalysisLeaf = null;
        controller.selectedAllocationMonitorLeaf = null;
      }
      controller.selectedLeaf = objectReference.instance;
    } else if (isAnalysis && this is AnalysisInstance) {
      final AnalysisInstance analysisInstance = this as AnalysisInstance;
      if (controller.selectedLeaf != null ||
          controller.selectedAllocationMonitorLeaf != null) {
        controller.selectedLeaf = null;
        controller.selectedAllocationMonitorLeaf = null;
      }
      controller.selectedAnalysisLeaf = analysisInstance;
    } else if (isAllocation) {
      final AllocationMonitorReference monitor =
          this as AllocationMonitorReference;
      if (controller.selectedAllocationMonitorLeaf != null) {
        controller.selectedLeaf = null;
        controller.selectedAnalysisLeaf = null;
      }
      controller.selectedAllocationMonitorLeaf = monitor;
    }

    if (onLeaf != null) onLeaf(this);

    super.leaf();
  }
}

class AllocationsMonitorReference extends Reference {
  AllocationsMonitorReference()
      : super.allocationsMonitor('Allocation Monitors');
}

class AllocationMonitorReference extends Reference {
  AllocationMonitorReference(MemoryController controller, this.dateTime)
      : super.allocationMonitor(
          controller,
          'Monitor ${MemoryController.formattedTimestamp(dateTime)}',
        );

  DateTime dateTime;
}

/// Container of all snapshot analyses processed.
class AnalysesReference extends Reference {
  AnalysesReference()
      : super.analysis(
          null,
          'Analysis',
        );
}

/// Snapshot being analyzed.
class AnalysisSnapshotReference extends Reference {
  AnalysisSnapshotReference(
    this.dateTime,
  ) : super.analysis(
          null,
          'Analyzed ${MemoryController.formattedTimestamp(dateTime)}',
        );

  final DateTime dateTime;
}

/// Analysis data.
class AnalysisReference extends Reference {
  AnalysisReference(
    String name, {
    this.countNote,
    this.sizeNote,
  }) : super.analysis(
          null,
          name,
        );

  int countNote;
  int sizeNote;
}

/// Analysis instance.
class AnalysisInstance extends Reference {
  AnalysisInstance(
    MemoryController controller,
    String name,
    this.fieldsRoot,
  ) : super.analysis(
          controller,
          name,
        );

  /// quick view of fields analysis.
  final AnalysisField fieldsRoot;
}

/// Analysis instance.
class AnalysisField extends TreeNode<AnalysisField> {
  AnalysisField(
    this.name,
    this.value,
  );

  AnalysisField._empty()
      : name = null,
        value = null;

  static AnalysisField empty = AnalysisField._empty();

  bool get isEmptyReference => this == empty;

  final String name;
  final String value;
}

/// Snapshot being analyzed.
class SnapshotReference extends Reference {
  SnapshotReference(this.snapshot)
      : super.snapshot(
          null,
          title(snapshot),
        );

  static String title(Snapshot snapshot) {
    if (snapshot == null) return '';

    final timestamp = snapshot.collectedTimestamp;
    final displayTimestamp = MemoryController.formattedTimestamp(timestamp);
    return snapshot.autoSnapshot
        ? 'Snapshot $displayTimestamp Auto'
        : 'Snapshot $displayTimestamp';
  }

  final Snapshot snapshot;
}

class LibraryReference extends Reference {
  LibraryReference(
    MemoryController controller,
    String libraryName,
    this.actualClasses,
  ) : super.library(
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

  Set<HeapGraphClassLive> actualClasses;
}

class ExternalReferences extends Reference {
  ExternalReferences(MemoryController controller, int externalsSize)
      : super.externals(controller);
}

class ExternalReference extends Reference {
  ExternalReference(MemoryController controller, String name, this.liveExternal)
      : super.external(
          controller,
          name,
          onExpand: (reference) {
            assert(reference.isExternal);

            // Need to construct the children.
            if (reference.children.isNotEmpty &&
                reference.children.first.isEmptyReference) {
              reference.children.clear();

              final externalReference = reference as ExternalReference;
              final liveElement = externalReference.liveExternal.live;
              externalReference.addChild(ObjectReference(
                controller,
                0,
                liveElement,
              ));
            }
          },
        );

  final HeapGraphExternalLive liveExternal;
  int sumExternalSizes = 0;
}

class FilteredReference extends Reference {
  FilteredReference(MemoryController controller) : super.filtered(controller);
}

void computeInstanceForClassReference(
  MemoryController controller,
  Reference reference,
) {
  // Need to construct the children if the first child is Reference.empty.
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
}

class ClassReference extends Reference {
  ClassReference(
    MemoryController controller,
    HeapGraphClassLive actualClass,
  ) : super.aClass(
          controller,
          actualClass,
          onExpand: (reference) {
            // Insure the children have been computed.
            computeInstanceForClassReference(controller, reference);
          },
        );

  List<HeapGraphElementLive> get instances =>
      actualClass.getInstances(controller.heapGraph);
}

class ObjectReference extends Reference {
  ObjectReference(
    MemoryController controller,
    int index,
    this.instance,
  ) : super.object(controller, 'Instance $index');

  final HeapGraphElementLive instance;
}

class ExternalObjectReference extends ObjectReference {
  ExternalObjectReference(
    MemoryController controller,
    int index,
    HeapGraphElementLive instance,
    this.externalSize,
  ) : super(
          controller,
          index,
          instance,
        );

  final int externalSize;
}

class Snapshot {
  Snapshot(
    this.collectedTimestamp,
    this.controller,
    this.snapshotGraph,
    this.libraryRoot,
    this.autoSnapshot,
  );

  final bool autoSnapshot;
  final MemoryController controller;
  final DateTime collectedTimestamp;
  final HeapSnapshotGraph snapshotGraph;
  LibraryReference libraryRoot;

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
        ) {
    onExpand = _expandObjectFieldRef;
  }

  void _expandObjectFieldRef(reference) {
    // Need to construct the children.
    if (reference.children.isNotEmpty &&
        reference.children.first.isEmptyReference) {
      // Remove empty entries compute the real values.
      reference.children.clear();

      // Null value nothing to expand.
      if (reference.isScaler) return;
    }

    assert(reference.isObject);
    final ObjectFieldReference objectFieldReference = reference;

    var objFields = instanceToFieldNodes(
      controller,
      objectFieldReference.instance,
    );

    if (objFields.isNotEmpty) {
      final computedFields = <FieldReference>[];
      for (final ref in objFields) {
        if (ref is ObjectFieldReference) {
          computedFields.add(ref);
        } else if (ref is FieldReference) {
          final FieldReference fieldRef = ref;
          final HeapGraphElementLive live = fieldRef.instance;
          final HeapGraphClassLive theClass = live.theClass;
          final predefined = predefinedClasses[theClass.fullQualifiedName];
          if (predefined != null && predefined.isScalar) {
            computedFields.add(createScalar(
              controller,
              fieldRef.name,
              fieldRef.instance,
            ));
          }
        }
      }
      objFields = computedFields;
    }

    objectFieldReference.addAllChildren(objFields);
  }

  final bool isNull;
}

/// Return list of FieldReference nodes (TableTree use) from the fields of an instance.
List<FieldReference> instanceToFieldNodes(
  MemoryController controller,
  HeapGraphElementLive instance,
) {
  final List<FieldReference> root = [];
  final List<MapEntry<String, HeapGraphElement>> fields = instance.getFields();

  var sentinelCount = 0;
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
        ));
      } else {
        sentinelCount++;
        root.add(FieldReference.sentinel);
      }
    }
    fieldIndex++;
  }

  if (root.isNotEmpty && sentinelCount > 0) {
    root.removeWhere((e) => e.isSentinelReference);
  }

  return root;
}

/// Return a FieldReference node (TableTree use) from the field of an instance.
FieldReference fieldToFieldReference(
  MemoryController controller,
  HeapGraphElementLive instance,
  MapEntry<String, HeapGraphElement> fieldElement,
) {
  if (fieldElement.value is HeapGraphElementSentinel) {
    // TODO(terry): Debug for now, eliminate, user's don't need to know.
    return FieldReference.sentinel;
  }

  final theGraph = controller.heapGraph;

  final actual = fieldElement.value as HeapGraphElementLive;
  final HeapGraphClassLive theClass = actual.theClass;
  // Debugging a particular field displayed use fieldElement.key (field name)
  // to break.

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
      final isAMap = isBuiltInMap(theClass);
      if (isAMap || isBuiltInList(theClass)) {
        return listToFieldEntries(
          controller,
          actual,
          fieldElement.key,
          data.length,
          isHashMap: isAMap, // TODO(terry): Just a test. &&&&&
        );
      }
    } else if (isBuiltInHashMap(theClass)) {
      for (var ref in fieldElement.value.references) {
        if (ref is! HeapGraphElementSentinel) {
          final HeapGraphElementLive actual = ref;
          final HeapGraphClassLive theClass = actual.theClass;
          if (isBuiltInList(theClass)) {
            final hashMapData = actual.origin.data;
            if (hashMapData.runtimeType == HeapSnapshotObjectLengthData) {
              return listToFieldEntries(
                controller,
                ref,
                fieldElement.key,
                hashMapData.length ~/ 2,
                isHashMap: true,
              );
            }
          }
        }
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
//      assert(false, 'Unexpected object - expected scalar.');
      dataValue = data.length.toString();
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
  int size, {
  isHashMap = false,
}) {
  bool isAMap = false;
  HeapGraphElementLive actualListElement;
  ObjectFieldReference listObjectReference;
  if (reference is HeapGraphElementLive) {
    final actualListClass = reference.theClass as HeapGraphClassLive;
    if (isBuiltInList(actualListClass)) {
      // Add the list entry.
      actualListElement = reference;
      listObjectReference = ObjectFieldReference(
        controller,
        actualListElement,
        isHashMap ? 'HashMap' : 'List',
        isHashMap ? '$fieldName {$size}' : '[$size]',
      );
    } else if (isBuiltInMap(actualListClass)) {
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
            isAMap = true;
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
  final hasKeyValues = isAMap && realEntries.length == size;

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
          if (isAMap) {
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
          listEntry ??= ObjectFieldReference(
            controller,
            entryElement,
            entryClass.name,
            '[$listIndex]',
          );
          if (entryElement.references.isNotEmpty) {
            // Key of the Map is an object.
            if (isAMap) {
              final keyFields = entryElement.getFields();
              for (final keyField in keyFields) {
                final key = keyField.key;
                final value = keyField.value;

                // Skip sentinels and null values.
                if (!value.isSentinel && !dataIsNull(value)) {
                  final HeapGraphElementLive live = value;
                  final HeapGraphClassLive theClass = live.theClass;
                  final keyObjectRef = ObjectFieldReference(
                    controller,
                    live,
                    theClass.name,
                    '$key',
                  );

                  keyObjectRef.addChild(FieldReference.empty);
                  listEntry.addChild(keyObjectRef);
                }
              }
            }
          }
        }

        // Entry type to expand later.
        if (!isAMap) {
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

bool dataIsNull(HeapGraphElementLive live) =>
    live.origin.data.runtimeType == HeapSnapshotObjectNullData;

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
