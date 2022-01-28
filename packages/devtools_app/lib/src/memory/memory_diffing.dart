// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/core/message_bus.dart';
import 'package:devtools_app/src/theme.dart';
import 'package:devtools_app/src/ui/icons.dart';
import 'package:flutter/material.dart';

import '../globals.dart';
import 'memory_controller.dart';
import 'memory_graph_model.dart';
import 'memory_snapshot_models.dart';

// Diff Image.
/*
Image diffImage(BuildContext context) {
  final themeData = Theme.of(context);
  return createImageIcon(
    themeData.isDarkTheme
        ? 'icons/memory/communities_white.png'
        : 'icons/memory/communities_black.png',
  );
}
*/

ThemedImageIcon diffImage(BuildContext context) {
  // TODO(terry): Match shape in event pane.
  return const ThemedImageIcon(
    darkModeAsset: 'icons/memory/communities_white.png',
    lightModeAsset: 'icons/memory/communities_black.png',
  );
}

class SimpleObject {
  SimpleObject(this.id);

  int id;
}

class ListComputation<T> {
  ListComputation(List<T> previousList, List<T> currentList, this.valueFunction)
      : deletedOnes = previousList.toList(),
        newOnes = currentList.toList();

  /// Items newly created (did not exist in previous).
  final List<T> newOnes;

  // Items that have been deleted (does not exist in current).
  final List<T> deletedOnes;

  /// Items in both previous and current.
  final common = <T>[];

  /// Callback function returns value to compare.
  int Function(T value) valueFunction;

  /// Debug only check. If more than one item all the entries must
  /// be a core type (hashcode of zero).
  void _debugCheckCoreType(List<T> items) {
    assert(() {
      for (var index = 0; index < items.length; index++) {
        assert(valueFunction(items.elementAt(index)) == 0);
      }
    }());
  }

  void difference() {
    // Build the list of instances that have been deleted (does not exist in
    // current snapshot).
    deletedOnes.removeWhere((T l1Item) {
      // Ignore zero hashcode it's invalid (core type).
      if (valueFunction(l1Item) == 0) return false;

      final removeItem = newOnes.where(
        (l2Item) => valueFunction(l1Item) == valueFunction(l2Item),
      );
      if (removeItem.length == 1) {
        // Add to common list, item is in both previous and current.
        common.add(removeItem.first);
        return true;
      }

/*
      if (removeItem.length > 1) {
        final List<T> items = removeItem.toList();
        _debugCheckCoreType(items);
      }
*/
      return false;
    });

    // Build the list of new instances in current snapshot(did not exist in
    // previous snapshot).
    newOnes.removeWhere((l2Item) {
      final removeItem = common.where(
        (commonItem) {
          // Ignore zero hashcode it's invalid (core type).
          if (valueFunction(commonItem) == 0 || valueFunction(l2Item) == 0)
            return false;
          return valueFunction(commonItem) == valueFunction(l2Item);
        },
      );
      if (removeItem.length > 1) {
        _debugCheckCoreType(removeItem);
      }

      return removeItem.isNotEmpty && removeItem.length == 1;
    });
  }

  String get _toStringNewOnes {
    final result = StringBuffer()..write('  New: [');
    final newOnesSize = newOnes.length;
    for (var index = 0; index < newOnesSize; index++) {
      result.write('${valueFunction(newOnes[index])},');
    }
    result.write(']');
    return result.toString();
  }

  String get _toStringDeleteOnes {
    final result = StringBuffer()..write('  Deleted: [');
    final deleteOnesSize = deletedOnes.length;
    for (var index = 0; index < deleteOnesSize; index++) {
      result.write('${valueFunction(deletedOnes[index])},');
    }
    result.write(']');
    return result.toString();
  }

  String get _toStringCommon {
    final result = StringBuffer()..write('  Common: [');
    final commonSize = common.length;
    for (var index = 0; index < commonSize; index++) {
      result.write('${valueFunction(common[index])},');
    }
    result.write(']');
    return result.toString();
  }

  @override
  String toString() {
    final result = StringBuffer();
    if (newOnes.isNotEmpty) result.write('new=${newOnes.length}, ');
    if (deletedOnes.isNotEmpty) result.write('deleted=${deletedOnes.length}, ');
    if (common.isNotEmpty) result.write('common=${common.length}');
    return result.toString();
  }

  // Detailed information.
  String debugToString() =>
      '$_toStringNewOnes\n$_toStringDeleteOnes\n$_toStringCommon\n';
}

// TODO(terry): Remove and add to unit tests.
void testListComputation() {
  final previous = <SimpleObject>[
    SimpleObject(1),
    SimpleObject(2),
    SimpleObject(3),
    SimpleObject(55),
    SimpleObject(7),
    SimpleObject(99),
    SimpleObject(21),
  ];
  final current = <SimpleObject>[
    SimpleObject(1),
    SimpleObject(4),
    SimpleObject(7),
    SimpleObject(65),
    SimpleObject(99),
    SimpleObject(20),
    SimpleObject(21),
  ];

  bool compare(ListComputation<SimpleObject> list,
      {List newOnes, List deletedOnes, List commonOnes}) {
    final newSize = list.newOnes.length;
    final deletedSize = list.deletedOnes.length;
    final commonSize = list.common.length;

    if (newSize != list.newOnes.length) return false;
    for (var index = 0; index < newSize; index++) {
      if (list.newOnes[index].id != newOnes[index]) {
        print(
          'Mismatch NEW index = $index, '
          '[${list.newOnes[index].id}] != [${newOnes[index]}]',
        );
        return false;
      }
    }

    if (deletedSize != list.deletedOnes.length) return false;
    for (var index = 0; index < deletedSize; index++) {
      if (list.deletedOnes[index].id != deletedOnes[index]) {
        print(
          'Mismatch DELETED index = $index, '
          '[${list.deletedOnes[index].id}] != [${deletedOnes[index]}]',
        );
        return false;
      }
    }

    if (commonSize != list.common.length) return false;
    for (var index = 0; index < commonSize; index++) {
      if (list.common[index].id != commonOnes[index]) {
        print(
          'Mismatch COMMON index = $index, '
          '[${list.common[index].id}] != [${commonOnes[index]}]',
        );
        return false;
      }
    }

    return true;
  }

  final computation = ListComputation<SimpleObject>(
    previous,
    current,
    (SimpleObject v) => v.id,
  );
  computation.difference();

  print(computation.debugToString());

  assert(compare(
    computation,
    newOnes: [4, 65, 20],
    deletedOnes: [2, 3, 55],
    commonOnes: [1, 7, 99, 21],
  ));
}

class LibraryToDiff {
  LibraryToDiff(this.name, this.actualClasses);

  String name;
  Set<HeapGraphClassLive> actualClasses;
}

class SnapshotDiffing {
  SnapshotDiffing(
    MemoryController controller,
    this.snapshot1, // currently previous snapshot
    this.snapshot2, // currently last snapshot
  ) {
    heapGraph1 = controller.heapGraph = convertHeapGraph(
      controller,
      snapshot1.snapshotGraph,
      [],
    );
    heapGraph1
      ..computeInstancesForClasses()
      ..computeRawGroups();
//      ..computeFilteredGroups();

    heapGraph2 = controller.heapGraph = convertHeapGraph(
      controller,
      snapshot2.snapshotGraph,
      [],
    );
    heapGraph2
      ..computeInstancesForClasses()
      ..computeRawGroups();
//      ..computeFilteredGroups();
  }

  final Snapshot snapshot1;
  final Snapshot snapshot2;

  HeapGraph heapGraph1; // Previous snaphot HeapGraph (snapshot1).
  HeapGraph heapGraph2; // Current snaphot HeapGraph (snapshot2).

  /// Classes compared in both snapshots (previous and current).
  final classesCompared = <HeapGraphClassLive>[];

  /// Classes in snapshot2 (current snapshot) that are not in snapshot1 (previous snapshot).
  final appearClasses = <HeapGraphClassLive>[];

  /// Classes in snapshot1 (previous snapshot) that are not in snapshot2 (current snapshot).
  /// Implies this class and all its instances disappeard from the current snapshot2 compared to
  /// existing in snapshot1 (previous snapshot).
  final goneClasses = <HeapGraphClassLive>[];

  /// Computed snapshot differences for each class (new, deleted, common).
  final diffComputations =
      <HeapGraphClassLive, ListComputation<HeapGraphElementLive>>{};

  void computeDiffForSnapShots() {
    // Compute all libraries.
    // Group by library
    final libraryDiffs1 = <LibraryToDiff>[];

    heapGraph1.rawGroupByLibrary.forEach((libraryName, classes) {
      LibraryToDiff libraryDiff = libraryDiffs1.singleWhere((library) {
        return libraryName == library.name;
      }, orElse: () => null);

      // Library not found add to list of children.
      if (libraryDiff == null) {
        libraryDiff = LibraryToDiff(libraryName, classes);
        libraryDiffs1.add(libraryDiff);
      }
    });

    final libraryDiffs2 = <LibraryToDiff>[];
    heapGraph2.rawGroupByLibrary.forEach((libraryName, classes) {
      LibraryToDiff libraryDiff = libraryDiffs1.singleWhere((library) {
        return libraryName == library.name;
      }, orElse: () => null);

      // Library not found add to list of children.
      if (libraryDiff == null) {
        libraryDiff = LibraryToDiff(libraryName, classes);
        libraryDiffs2.add(libraryDiff);
      }
    });

    final librariesDiffed = <String>[];
    final librariesNotInSnapshot1 = <String>[];
    final librariesNotInSnapshot2 = <String>[];

    heapGraph2.rawGroupByLibrary.forEach((
      String libraryName2,
      Set<HeapGraphClassLive> classes2,
    ) {
      final libraryFound1 = heapGraph1.rawGroupByLibrary.entries.singleWhere(
        (library) {
          return library.key == libraryName2;
        },
        orElse: () => null,
      );
      if (libraryFound1 != null) {
        librariesDiffed.add(libraryFound1.key);

        // Diff the classes and instances of each identity hash.
        final Set<HeapGraphClassLive> classes1 = libraryFound1.value;
        compareClasses(classes1, classes2);
      } else {
        // Snapshot 1 library not found in snapshot2.
        librariesNotInSnapshot2.add(libraryName2);
      }
    });

    // Any libaries not in snapshot1?
    final librariesDiffedLength = librariesDiffed.length;
    for (var index = 0; index < librariesDiffedLength; index++) {
      final libraryName = librariesDiffed[index];
      final libraryNotProcessed =
          heapGraph1.rawGroupByLibrary.entries.singleWhere(
        (library) => library.key == libraryName,
        orElse: () => null,
      );
      if (libraryNotProcessed != null) {
        librariesNotInSnapshot1.add(libraryName);
      }
    }

    // TODO(terry): goneClasses are not very useful they are classes which are not active (most classes
    //              are not active). Consider eliminating.

    // Show the libraries/classes that are gone (instances at zero) from other snapshots being diffed.
    if (goneClasses.isNotEmpty) {
      final result = StringBuffer();
      final goneSize = goneClasses.length;
      result.write('Classes gone: $goneSize\n');
//      for (var index = 0; index < goneSize; index++) {
//        result.write('${goneClasses[index].name}, ');
//      }
      print(result.toString());
    }

    // Show the libraries/classes that appeared from other snapshots being diffed.
    if (appearClasses.isNotEmpty) {
      final result = StringBuffer();
      final appearSize = appearClasses.length;
      result.write('Classes appearing: $appearSize\n');
//      for (var index = 0; index < appearSize; index++) {
//        result.write('${appearClasses[index].name}, ');
//      }
      print(result.toString());
    }

    // Show the classes/instances that have changed (new, deleted, common).
    diffComputations.forEach((theClass, diffComputation) {
      if (diffComputation.newOnes.isNotEmpty ||
          diffComputation.deletedOnes.isNotEmpty) {
        print('Class ${theClass.name} $diffComputation');
      }
    });
  }

  void compareClasses(
    Set<HeapGraphClassLive> classes1,
    Set<HeapGraphClassLive> classes2,
  ) {
    print('Library ${classes1.first.fullQualifiedName.libraryName} '
        'processing:');

    final classesSize2 = classes2.length;
    for (var index2 = 0; index2 < classesSize2; index2++) {
      final HeapGraphClassLive class2 = classes2.elementAt(index2);
      if (class2.name == 'Code' ||
          class2.name == 'CodeSourceMap' ||
          class2.name == 'Context' ||
          class2.name == 'Field' ||
          class2.name == 'Function' ||
          class2.name == 'ICData' ||
          class2.name == 'Instructions' ||
          class2.name == 'PcDescriptors' ||
          //class2.name == '_Double' ||
          //class2.name == '_List' ||
          //class2.name == '_Mint' ||
          //class2.name == '_OneByteString' ||
          class2.name == '_FunctionType' ||
          class2.name == '_Type') {
        print('SKIPPED ${class2.name} in '
            'library ${class2.fullQualifiedName.libraryName}');
        continue;
      }
      if (class2.name.isEmpty) {
        print('Empty class  $class2 SKIPPED');
      }
      if (class2.name.isNotEmpty) {
        var foundClasses1 = classes1.where(
          (HeapGraphClassLive theClass1) => theClass1.name == class2.name,
        );
        if (foundClasses1.length > 1) {
          // How is this possible? See class named __SegmentedControlState&State&TickerProviderStateMixin
          foundClasses1 = null;
        }

        final foundClass1 = foundClasses1?.first;
        if (foundClass1 != null) {
          classesCompared.add(class2);
          print(">>>>> Starting TO COMPARE INSTANCES....");

          final diffComputation = compareInstances(foundClass1, class2);
          diffComputations[foundClass1] = diffComputation;
        } else {
          // Class not found in previous snapshot so it's a newly created in
          // the current snapshot.
          appearClasses.add(class2);
        }
      }
    }

    final classesComparedSize = classesCompared.length;
    for (var index = 0; index < classesComparedSize; index++) {
      final HeapGraphClassLive classCompared = classesCompared.elementAt(index);
      if (classCompared.name.isEmpty) {
        print('Empty class name $classCompared.name SKIPPED');
      }
      final classFound = classes1.singleWhere(
        (HeapGraphClassLive theClass1) => theClass1.name == classCompared.name,
        orElse: () => null,
      );
      if (classFound == null) {
        goneClasses.add(classCompared);
      }
    }
  }

  ListComputation<HeapGraphElementLive> compareInstances(
    HeapGraphClassLive classes1, // previous snapshot classes
    HeapGraphClassLive classes2, // current snapshot classes
  ) {
    final instances1 = classes1.getInstances(heapGraph1)
      ..sort((instanceA, instanceB) => instanceA.origin.identityHashCode
          .compareTo(instanceB.origin.identityHashCode));

    final instances2 = classes2.getInstances(heapGraph2)
      ..sort((instanceA, instanceB) => instanceA.origin.identityHashCode
          .compareTo(instanceB.origin.identityHashCode));

//    testListComputation();

    messageBus.addEvent(BusEvent('toast', data: 'Computing diff...'));

    final startTime = DateTime.now();

    final diffComputation = ListComputation<HeapGraphElementLive>(
      instances1,
      instances2,
      (HeapGraphElementLive v) => v.snapshotHashCode,
    );

    diffComputation.difference();

    final diffComputedSecs = DateTime.now().difference(startTime).inSeconds;
    messageBus.addEvent(
      BusEvent(
        'toast',
        data: ' Diff computed in $diffComputedSecs seconds.',
      ),
    );

    return diffComputation;
  }
}
