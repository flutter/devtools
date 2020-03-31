// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/controllers.dart';
import '../../flutter/table.dart';
import '../../table_data.dart';
import '../../ui/flutter/label.dart';
import '../../ui/material_icons.dart';

import 'memory_controller.dart';
import 'memory_snapshot_models.dart';

class HeapTree extends StatefulWidget {
  const HeapTree(
    this.controller,
  );

  final MemoryController controller;

  //List<HeapSnapshotClass> data;

  @override
  HeapTreeViewState createState() => HeapTreeViewState();
}

class HeapTreeViewState extends State<HeapTree> with AutoDisposeMixin {
  @visibleForTesting
  static const filterButtonKey = Key('Snapshot Filter');
  @visibleForTesting
  static const searchButtonKey = Key('Snapshot Search');
  @visibleForTesting
  static const settingsButtonKey = Key('Snapshot Settings');

  MemoryController controller;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    controller = Controllers.of(context).memory;

    cancel();

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
//        controller.updatedMemorySource();
//        _refreshCharts();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
//    final textTheme = Theme.of(context).textTheme;
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSnapshotControls(),
        ],
      ),
      Expanded(
        child: MemoryGraphTable(),
      ),
    ]);
  }

  Widget _buildSnapshotControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: OutlineButton(
              key: searchButtonKey,
              onPressed: _search,
              child: Label(
                search,
                'Search',
                minIncludeTextWidth: 2000,
              ),
            ),
          ),
          const SizedBox(width: 16.0),
          Flexible(
            child: OutlineButton(
              key: filterButtonKey,
              onPressed: _filter,
              child: Label(
                filterIcon,
                'Filter',
                minIncludeTextWidth: 2000,
              ),
            ),
          ),
          Flexible(
            child: OutlineButton(
              key: settingsButtonKey,
              onPressed: _settings,
              child: Label(
                settings,
                'Settings',
                minIncludeTextWidth: 2000,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _search() {}

  void _filter() {}

  void _settings() {}
}

class MemoryGraphTable extends StatefulWidget {
  @override
  MemoryGraphTableState createState() => MemoryGraphTableState();
}

/// A table of the Memory graph class top-down call tree.
class MemoryGraphTableState extends State<MemoryGraphTable>
    with AutoDisposeMixin {
  MemoryController controller;

  final TreeColumnData<Reference> treeColumn = LibraryRefColumn();
  final List<ColumnData<Reference>> columns = [];

  @override
  void initState() {
    setupColumns();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    controller = Controllers.of(context).memory;

    cancel();

    // Update the chart when the memorySource changes.
    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {});
    });
  }

  void setupColumns() {
    columns.addAll([
      //_ClassNameColumn(),
      treeColumn,
      _ClassLibraryClassCountColumn(),
      _ClassLibraryUriColumn(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return TreeTable<Reference>(
//      dataRoots: controller.snapshotByLibraryData,
      dataRoots: [controller.lastSnapshot.root],
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (libRef) => PageStorageKey<String>(libRef.name),
    );

//    return FlatTable<LibraryReference>(
//      columns: columns,
//      data: controller.snapshotByLibraryData,
//      keyFactory: (libRef) => Key(libRef.name),
//      startAtBottom: false,
//      onItemSelected: (library) {
//        // Compute classes for the library selected.
//        library.computeClasses();
//
//        print(">>>> Library selected ${library.name}");
//        final heapClasses = controller.lastSnapshot.snapshotGraph.classes;
//        for (var theClass in library.classes) {
//          var className = heapClasses[theClass.classId].name;
//          print("   class $className");
//        }
//        return selected = item;
//      },
//    );
  }
}

class LibraryRefColumn extends TreeColumnData<Reference> {
  LibraryRefColumn() : super('Library/Classes');

  static const maxMethodNameLength = 75;

  @override
  dynamic getValue(Reference dataObject) {
    return dataObject.name;
  }
//  dynamic getValue(Reference dataObject) => dataObject.name;

  @override
  String getDisplayValue(Reference dataObject) {
    if (dataObject.isLibrary) {
/*
      final libraryRef = dataObject as LibraryReference;
      if (!libraryRef.isClassesComputed && libraryRef.classIds.isNotEmpty) {
        libraryRef.children.clear();
        libraryRef.computeClasses();
      }
*/
//      print("in LibraryRef");
    } else if (dataObject.isLibrary) {
      print("in classRef");
    } else if (dataObject.isEmpty) {
      print("in empty");
    }
    if (dataObject.isEmpty) {
      return '';
    } else if (dataObject.name.length > maxMethodNameLength) {
      return dataObject.name.substring(0, maxMethodNameLength) + '...';
    }
    return dataObject.name;
  }

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(Reference dataObject) => dataObject.name;
}
/*
class _ClassNameColumn extends ColumnData<LibraryReference> {
  _ClassNameColumn() : super('Library Name');

  @override
  String getValue(LibraryReference dataObject) => dataObject.name;

  @override
  double get fixedWidthPx => 300.0;
}
*/

class _ClassLibraryClassCountColumn extends ColumnData<Reference> {
  _ClassLibraryClassCountColumn() : super('Classes');

  @override
  String getValue(Reference dataObject) {
    final value = (dataObject.isLibrary)
        ? '${(dataObject as LibraryReference).classIds.length}'
        : '';
    return value;
  }

  @override
  double get fixedWidthPx => 300.0;
}

class _ClassLibraryUriColumn extends ColumnData<Reference> {
  _ClassLibraryUriColumn() : super('URI');

  @override
  String getValue(Reference dataObject) {
    final value = (dataObject.isLibrary)
        ? (dataObject as LibraryReference).uri.toString()
        : '';
    return value;
  }

  @override
  double get fixedWidthPx => 300.0;
}
