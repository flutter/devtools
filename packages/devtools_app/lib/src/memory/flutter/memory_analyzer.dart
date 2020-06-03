// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/table.dart';
import '../../table_data.dart';
import '../../utils.dart';

import 'memory_controller.dart';
import 'memory_graph_model.dart';
import 'memory_heap_tree_view.dart';
import 'memory_snapshot_models.dart';

bool _classMatcher(HeapGraphClassLive liveClass) {
  final regExp = RegExp(knownClassesRegExs);
  return regExp.allMatches(liveClass.name).isNotEmpty;
}

/// Returns a map of all datapoints collected:
///
///   key: 'externals'    value: List<ExternalReference>
///   key: 'filters'      value: List<ClassReference>
///   key: 'libraries'    value: List<ClassReference>
///
Map<String, List<Reference>> collect(MemoryController controller) {
  final Map<String, List<Reference>> result = {};

  // Analyze the external heap for memory information
  final root = controller.libraryRoot;
  assert(root != null);

  final heapGraph = controller.heapGraph;

  for (final library in root.children) {
    if (library.isExternals) {
      final externalsToAnalyze = <ExternalReference>[];

      final ExternalReferences externals = library;
      for (final ExternalReference external in externals.children) {
        assert(external.isExternal);

        final liveExternal = external.liveExternal;
        final size = liveExternal.externalProperty.externalSize;
        final liveElement = liveExternal.live;
        final HeapGraphClassLive liveClass = liveElement.theClass;
        if (_classMatcher(liveClass)) {
          final instances = liveClass.getInstances(heapGraph);
          externalsToAnalyze.add(external);
          print('regex external found ${liveClass.name} '
              'instances=${instances.length} '
              'allocated bytes=$size');
        }
      }
      result['externals'] = externalsToAnalyze;
    } else if (library.isFiltered) {
      final filtersToAnalyze = <ClassReference>[];
      for (final LibraryReference libraryRef in library.children) {
        for (final ClassReference classRef in libraryRef.children) {
          final HeapGraphClassLive liveClass = classRef.actualClass;
          if (_classMatcher(liveClass)) {
            filtersToAnalyze.add(classRef);
            final instances = liveClass.getInstances(heapGraph);
            print('regex filtered found ${classRef.name} '
                'instances=${instances.length}');
          }
        }
        result['filters'] = filtersToAnalyze;
      }
    } else if (library.isLibrary) {
      final librariesToAnalyze = <ClassReference>[];
      for (final ClassReference classRef in library.children) {
        final HeapGraphClassLive liveClass = classRef.actualClass;
        if (_classMatcher(liveClass)) {
          librariesToAnalyze.add(classRef);
          final instances = liveClass.getInstances(heapGraph);
          print('regex library found ${classRef.name} '
              'instances=${instances.length}');
        }
      }
      result['libraries'] = librariesToAnalyze;
    } else if (library.isAnalysis) {
      // Nothing to do on anay analyses.
    }
  }

  return result;
}

AnalysesReference findAnalysesNode(MemoryController controller) {
  for (final child in controller.libraryRoot.children) {
    if (child is AnalysesReference) {
      return child;
    }
  }
  return null;
}

const bucket10K = '1..10K';
const bucket50K = '10K..50K';
const bucket100K = '50K..100K';
const bucket500K = '100K..500K';
const bucket1M = '500K..1M';
const bucket10M = '1M..10M';
const bucket50M = '10M..50M';
const bucketBigM = '50M+';

class Bucket {
  Bucket(this.totalCount, this.totalBytes);

  int totalCount;
  int totalBytes;
}

void imageAnalysis(
  MemoryController controller,
  AnalysisSnapshotReference analysisSnapshot,
  Map<String, List<Reference>> collectedData,
) {
  // TODO(terry): Look at heap rate of growth (used, external, RSS).

  // TODO(terry): Any items with <empty> Reference.isEmpty need to be computed e.g., onExpand,
  collectedData.forEach((key, value) {
    switch (key) {
      case 'externals':
        final externalsNode = AnalysisReference('Externals');
        analysisSnapshot.addChild(externalsNode);
        for (final ExternalReference ref in value) {
          final HeapGraphExternalLive liveExternal = ref.liveExternal;
          final HeapGraphElementLive liveElement = liveExternal.live;

          /// TODO(terry): Eliminate or show sentinels for total instances?
          final objectNode = AnalysisReference(
            '${ref.name}',
            countNote: liveElement.theClass.instancesCount,
          );
          externalsNode.addChild(objectNode);
          var childExternalSizes = 0;
          final bucketSizes = SplayTreeMap<String, Bucket>();
          for (final ExternalObjectReference child in ref.children) {
            if (child.externalSize < 10000) {
              bucketSizes.putIfAbsent(bucket10K, () => Bucket(0, 0));
              bucketSizes[bucket10K].totalCount += 1;
              bucketSizes[bucket10K].totalBytes += child.externalSize;
            } else if (child.externalSize < 50000) {
              bucketSizes.putIfAbsent(bucket50K, () => Bucket(0, 0));
              bucketSizes[bucket50K].totalCount += 1;
              bucketSizes[bucket50K].totalBytes += child.externalSize;
            } else if (child.externalSize < 100000) {
              bucketSizes.putIfAbsent(bucket100K, () => Bucket(0, 0));
              bucketSizes[bucket100K].totalCount += 1;
              bucketSizes[bucket100K].totalBytes += child.externalSize;
            } else if (child.externalSize < 500000) {
              bucketSizes.putIfAbsent(bucket500K, () => Bucket(0, 0));
              bucketSizes[bucket500K].totalCount += 1;
              bucketSizes[bucket500K].totalBytes += child.externalSize;
            } else if (child.externalSize < 1000000) {
              bucketSizes.putIfAbsent(bucket1M, () => Bucket(0, 0));
              bucketSizes[bucket1M].totalCount += 1;
              bucketSizes[bucket1M].totalBytes += child.externalSize;
            } else if (child.externalSize < 10000000) {
              bucketSizes.putIfAbsent(bucket10M, () => Bucket(0, 0));
              bucketSizes[bucket10M].totalCount += 1;
              bucketSizes[bucket10M].totalBytes += child.externalSize;
            } else if (child.externalSize < 50000000) {
              bucketSizes.putIfAbsent(bucket50M, () => Bucket(0, 0));
              bucketSizes[bucket50M].totalCount += 1;
              bucketSizes[bucket50M].totalBytes += child.externalSize;
            } else {
              bucketSizes.putIfAbsent(bucketBigM, () => Bucket(0, 0));
              bucketSizes[bucketBigM].totalCount += 1;
              bucketSizes[bucketBigM].totalBytes += child.externalSize;
            }

            childExternalSizes += child.externalSize;
          }

          final bucketNode = AnalysisReference(
            'Buckets',
            sizeNote: childExternalSizes,
          );
          bucketSizes.forEach((key, value) {
            bucketNode.addChild(AnalysisReference(
              '$key',
              countNote: value.totalCount,
              sizeNote: value.totalBytes,
            ));
          });
          objectNode.addChild(bucketNode);
        }
        break;
      case 'filters':
      case 'libraries':
        final librariesNode = AnalysisReference('Library $key');

        final matches = drillIn(controller, librariesNode, value);

        final imageCacheNode = processMatches(controller, matches);
        if (imageCacheNode != null) {
          librariesNode.addChild(imageCacheNode);
        }

        analysisSnapshot.addChild(librariesNode);
    }
  });
}

AnalysisReference processMatches(
  MemoryController controller,
  Map<String, List<String>> matches,
) {
  // Root __FIELDS__ is a container for children, the children
  // are added, later, to a treenode - if the treenode should
  // be created.
  final AnalysisField pending = AnalysisField(
    '__FIELDS__',
    null,
  );
  final AnalysisField cache = AnalysisField(
    '__FIELDS__',
    null,
  );
  final AnalysisField live = AnalysisField(
    '__FIELDS__',
    null,
  );

  var countPending = 0;
  var countCache = 0;
  var countLive = 0;
  bool imageCacheFound = false;
  matches.forEach((key, values) {
    final fields = key.split('.');
    imageCacheFound = fields[0] == imageCache;

    for (final value in values) {
      switch (fields[1]) {
        case '_pendingImages':
          countPending++;
          pending.addChild(AnalysisField('url', value));
          break;
        case '_cache':
          countCache++;
          cache.addChild(AnalysisField('url', value));
          break;
        case '_liveImages':
          countLive++;
          live.addChild(AnalysisField('url', value));
          break;
      }
    }
  });

  if (imageCacheFound) {
    final imageCacheNode = AnalysisReference(
      imageCache,
      countNote: countPending + countCache + countLive,
    );

    final pendingNode = AnalysisReference(
      'Pending',
      countNote: countPending,
    );

    final cacheNode = AnalysisReference(
      'Cache',
      countNote: countCache,
    );

    final liveNode = AnalysisReference(
      'Live',
      countNote: countLive,
    );

    final pendingInstance = AnalysisInstance(
      controller,
      'Images',
      pending,
    );
    final cacheInstance = AnalysisInstance(
      controller,
      'Images',
      cache,
    );
    final liveInstance = AnalysisInstance(
      controller,
      'Images',
      live,
    );

    pendingNode.addChild(pendingInstance);
    imageCacheNode.addChild(pendingNode);

    cacheNode.addChild(cacheInstance);
    imageCacheNode.addChild(cacheNode);

    liveNode.addChild(liveInstance);
    imageCacheNode.addChild(liveNode);

    return imageCacheNode;
  }

  return null;
}

// TODO(terry): Add a test to insure this output is never seen before checkin.
// Name of class to monitor field/object drill in, e.g.,
//
//   debugMonitorDrillIn = 'ImageCache';
String debugMonitorClass;

void debugMonitor(String msg) {
  // TODO(terry): Enable below to monitor.
  // if (debugMonitorClass == null) return;
  // print('--> $debugMonitorClass:$msg');
}

ClassFields fieldsStack = ClassFields();

Map<String, List<String>> drillIn(
  MemoryController controller,
  AnalysisReference librariesNode,
  List<Reference> references, {
  createTreeNodes = false,
}) {
  final Map<String, List<String>> result = {};

  final matcher = ObjectMatcher((className, fields, value) {
    final key = '$className.${fields.join(".")}';
    result.putIfAbsent(key, () => []);
    result[key].add(value);
  });

  for (final ClassReference classRef in references) {
    if (!matcher.isClassMatched(classRef.name)) continue;

    // Insure instances are realized (not Reference.empty).
    computeInstanceForClassReference(controller, classRef);
    final HeapGraphClassLive liveClass = classRef.actualClass;

    AnalysisReference objectNode;
    if (createTreeNodes) {
      objectNode = AnalysisReference(
        '${classRef.name}',
        countNote: liveClass.instancesCount,
      );
      librariesNode.addChild(objectNode);
    }

    // TODO(terry): Enable debug code, validates an object's fields/values.
    // debugMonitorClass = classRef.name == imageCache ? '${classRef.name}' : '';

    fieldsStack.push(classRef.name);

    var instanceIndex = 0;
    debugMonitor('Class ${classRef.name} Instance=$instanceIndex');
    for (final ObjectReference objRef in classRef.children) {
      final fields = objRef.instance.getFields();
      // Root __FIELDS__ is a container for children, the children
      // are added, later, to a treenode - if the treenode should
      // be created.
      final AnalysisField fieldsRoot = AnalysisField(
        '__FIELDS__',
        null,
      );

      for (final field in fields) {
        if (field.value.isSentinel) continue;

        final HeapGraphElementLive live = field.value;

        if (live.references.isNotEmpty) {
          debugMonitor('${field.key} OBJECT Start');

          final fieldObjectNode = AnalysisField(field.key, '');

          fieldsStack.push(field.key);
          displayObject(
            matcher,
            fieldObjectNode,
            live,
            createTreeNodes: createTreeNodes,
          );
          fieldsStack.pop();

          if (createTreeNodes) {
            fieldsRoot.addChild(fieldObjectNode);
          }
          debugMonitor('${field.key} OBJECT End');
        } else {
          final value = displayData(live);
          if (value != null) {
            fieldsStack.push(field.key);
            matcher.findFieldMatch(fieldsStack, value);
            fieldsStack.pop();

            debugMonitor('${field.key} = ${value}');
            if (createTreeNodes) {
              final fieldNode = AnalysisField(field.key, value);
              fieldsRoot.addChild(fieldNode);
            }
          } else {
            debugMonitor('${field.key} Skipped null');
          }
        }
      }

      if (createTreeNodes) {
        final instanceNode = AnalysisInstance(
          controller,
          'Instance $instanceIndex',
          fieldsRoot,
        );
        objectNode.addChild(instanceNode);
      }

      instanceIndex++;
    }

    fieldsStack.pop(); // Pop class name.
  }

  return result;
}

bool displayObject(
  ObjectMatcher matcher,
  AnalysisField objectField,
  HeapGraphElementLive live, {
  depth = 0,
  maxDepth = 4,
  createTreeNodes = false,
}) {
  if (depth >= maxDepth) return null;
  if (live.references.isEmpty) return true;

  final fields = live.getFields();
  for (final field in fields) {
    if (field.value.isSentinel) continue;

    final HeapGraphElementLive liveField = field.value;
    for (final ref in liveField.references) {
      if (ref.isSentinel) continue;
      final HeapGraphElementLive liveRef = ref;
      final objectFields = liveRef.getFields();
      if (objectFields.isEmpty) continue;

      final newObject = AnalysisField(field.key, '');
      debugMonitor('${field.key} OBJECT start [depth=$depth]');

      depth++;

      fieldsStack.push(field.key);
      final continueResult = displayObject(
        matcher,
        newObject,
        liveRef,
        depth: depth,
        createTreeNodes: createTreeNodes,
      );
      fieldsStack.pop();

      depth--;
      // Drilled in enough, stop.
      if (continueResult == null) continue;

      if (createTreeNodes) {
        objectField.addChild(newObject);
      }
      debugMonitor('${field.key} OBJECT end  [depth=$depth]');
    }

    final value = displayData(liveField);
    if (value != null) {
      fieldsStack.push(field.key);
      matcher.findFieldMatch(fieldsStack, value);
      fieldsStack.pop();

      debugMonitor('${field.key}=$value');
      if (createTreeNodes) {
        final node = AnalysisField(field.key, value);
        objectField.addChild(node);
      }
    }
  }

  return true;
}

String displayData(instance) {
  String result;

  switch (instance.origin.data.runtimeType) {
    case HeapSnapshotObjectNullData:
    case HeapSnapshotObjectNoData:
    case Null:
    case TypeArguments:
      break;
    default:
      result = '${instance.origin.data}';
  }

  return result;
}

class AnalysisInstanceViewTable extends StatefulWidget {
  @override
  AnalysisInstanceViewState createState() => AnalysisInstanceViewState();
}

/// Table of the fields of an instance (type, name and value).
class AnalysisInstanceViewState extends State<AnalysisInstanceViewTable>
    with AutoDisposeMixin {
  MemoryController controller;

  final TreeColumnData<AnalysisField> treeColumn = _AnalysisFieldNameColumn();
  final List<ColumnData<AnalysisField>> columns = [];

  @override
  void initState() {
    setupColumns();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<MemoryController>(context);
    if (newController == controller) return;
    controller = newController;

    cancel();

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(true, true);
      });
    });
  }

  void setupColumns() {
    columns.addAll([
      treeColumn,
      _AnalysisFieldValueColumn(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    controller.analysisFieldsTreeTable = TreeTable<AnalysisField>(
      dataRoots: controller.analysisInstanceRoot,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (typeRef) => PageStorageKey<String>(typeRef.name),
      sortColumn: columns[0],
      sortDirection: SortDirection.ascending,
    );

    return controller.analysisFieldsTreeTable;
  }
}

class _AnalysisFieldNameColumn extends TreeColumnData<AnalysisField> {
  _AnalysisFieldNameColumn() : super('Name');

  @override
  dynamic getValue(AnalysisField dataObject) => dataObject.name;

  @override
  String getDisplayValue(AnalysisField dataObject) => '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(AnalysisField a, AnalysisField b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 250.0;
}

class _AnalysisFieldValueColumn extends ColumnData<AnalysisField> {
  _AnalysisFieldValueColumn() : super('Value');

  @override
  dynamic getValue(AnalysisField dataObject) => dataObject.value;

  @override
  String getDisplayValue(AnalysisField dataObject) {
    var value = getValue(dataObject);
    if (value is String && value.length > 30) {
      value = '${value.substring(0, 13)}…${value.substring(value.length - 17)}';
    }
    return '$value';
  }

  @override
  bool get supportsSorting => true;

  @override
  int compare(AnalysisField a, AnalysisField b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 250.0;
}

class ClassFields {
  final List<String> _fields = [];

  void clear() {
    _fields.clear();
  }

  int get length => _fields.length;

  void push(String name) {
    _fields.add(name);
  }

  String pop() => _fields.removeLast();

  String elementAt(int index) => _fields.elementAt(index);
}

const imageCache = 'ImageCache';

/// Callback function when an ObjectReference's class name and fields all match.
/// Parameters:
///   className that matched
///   fields that all matched
///   value of the matched objectReference
///
typedef CompletedFunction = void Function(
    String className, List<String> fields, dynamic value);

class ObjectMatcher {
  ObjectMatcher(this._matchCompleted);

  static const Map<String, List<List<String>>> matcherDrillIn = {
    '$imageCache': [
      ['_pendingImages', 'data_', 'completer', 'context_', 'url'],
      ['_cache', 'data_', 'completer', 'context_', 'url'],
      ['_liveImages', 'data_', 'completer', 'context_', 'url'],
    ]
  };

  final CompletedFunction _matchCompleted;

  bool isClassMatched(String className) =>
      matcherDrillIn.containsKey(className);

  List<List<String>> _findClassMatch(String className) =>
      matcherDrillIn[className];

  /// First field name match.
  bool findFieldMatch(ClassFields classFields, dynamic value) {
    bool matched = false;

    final className = classFields._fields.elementAt(0);
    final listOfFieldsToMatch = _findClassMatch(className);

    if (listOfFieldsToMatch != null) {
      for (final fieldsToMatch in listOfFieldsToMatch) {
        final fieldsSize = fieldsToMatch.length;
        if (fieldsSize == classFields._fields.length - 1) {
          for (var index = 0; index < fieldsSize; index++) {
            if (fieldsToMatch[index] ==
                classFields._fields.elementAt(index + 1)) {
              matched = true;
            } else {
              matched = false;
              break;
            }
          }
        }

        if (matched) {
          _matchCompleted(className, fieldsToMatch, value);
          break;
        }
      }
    }

    return matched;
  }
}
