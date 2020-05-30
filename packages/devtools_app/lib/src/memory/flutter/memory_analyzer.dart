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

const bucket10K = '<10k';
const bucket50K = '<50k';
const bucket100K = '<100k';
const bucket500K = '<500k';
const bucket1M = '>1M+';

void imageAnalysis(
  MemoryController controller,
  AnalysisSnapshotReference analysisSnapshot,
  Map<String, List<Reference>> collectedData,
) {
  // TODO(terry): Look at heap rate of growth (used, external, RSS).

  // TODO(terry): Any items with <empty> Reference.isEmpty need to be computed e.g., onExpand,
  collectedData.forEach((key, value) {
    final output = StringBuffer();
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
          final bucketSizes = SplayTreeMap<String, int>();
          for (final ExternalObjectReference child in ref.children) {
            if (child.externalSize < 10000) {
              bucketSizes.putIfAbsent(bucket10K, () => 0);
              bucketSizes[bucket10K] += 1;
            } else if (child.externalSize < 50000) {
              bucketSizes.putIfAbsent(bucket50K, () => 0);
              bucketSizes[bucket50K] += 1;
            } else if (child.externalSize < 100000) {
              bucketSizes.putIfAbsent(bucket100K, () => 0);
              bucketSizes[bucket100K] += 1;
            } else if (child.externalSize < 500000) {
              bucketSizes.putIfAbsent(bucket500K, () => 0);
              bucketSizes[bucket500K] += 1;
            } else {
              bucketSizes.putIfAbsent(bucket1M, () => 0);
              bucketSizes[bucket1M] += 1;
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
              countNote: value,
            ));
          });
          objectNode.addChild(bucketNode);
        }
        print(output.toString());
        output.clear();
        break;
      case 'filters':
      case 'libraries':
        final librariesNode = AnalysisReference('Library $key');
        analysisSnapshot.addChild(librariesNode);

        for (final ClassReference ref in value) {
          // Insure instances are realized (not Reference.empty).
          computeInstanceForClassReference(controller, ref);
          final HeapGraphClassLive liveClass = ref.actualClass;

          final objectNode = AnalysisReference(
            '${ref.name}',
            countNote: liveClass.instancesCount,
          );
          librariesNode.addChild(objectNode);

          switch (ref.name) {
/*
              case 'ImageCache':
                print('TODO');
                break;
*/

            default:
              var instanceIndex = 0;
              for (final ObjectReference objRef in ref.children) {
                final fields = objRef.instance.getFields();
                final AnalysisField fieldsRoot =
                    AnalysisField('__FIELDS__', null);
                for (final field in fields) {
                  if (field.value.isSentinel) continue;

                  final HeapGraphElementLive live = field.value;

                  if (live.references.isNotEmpty) {
                    final fieldObjectNode = AnalysisField(field.key, '');
                    displayObject(fieldObjectNode, live);
                    fieldsRoot.addChild(fieldObjectNode);
                  }

                  final value = displayData(live);
                  if (value != null) {
                    final fieldNode = AnalysisField(field.key, value);
                    fieldsRoot.addChild(fieldNode);
                  }
                }

                final instanceNode = AnalysisInstance(
                  controller,
                  'Instance $instanceIndex',
                  fieldsRoot,
                );
                objectNode.addChild(instanceNode);

                instanceIndex++;
              }
          }
        }
        print(output.toString());
        output.clear();
        break;
    }
  });
}

bool displayObject(
  AnalysisField objectField,
  HeapGraphElementLive live, {
  depth = 0,
  maxDepth = 4,
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
      if (objectFields.isEmpty) return true;

      final newObject = AnalysisField(field.key, '');

      depth++;
      final continueResult = displayObject(newObject, liveRef, depth: depth);
      // Drilled in enough, stop.
      if (continueResult == null) return null;

      objectField.addChild(newObject);
    }

    final value = displayData(liveField);
    if (value != null) {
      final node = AnalysisField(field.key, value);
      objectField.addChild(node);
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
