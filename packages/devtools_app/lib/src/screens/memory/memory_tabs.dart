// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../config_specific/logger/logger.dart' as logger;
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/search.dart';
import '../../ui/tab.dart';
import 'memory_controller.dart';
import 'memory_graph_model.dart';
import 'memory_snapshot_models.dart';
import 'panes/allocation_profile/allocation_profile_table_view.dart';
import 'panes/allocation_tracing/allocation_profile_tracing_view.dart';
import 'panes/diff/diff_pane.dart';
import 'panes/leaks/leaks_pane.dart';

const memorySearchFieldKeyName = 'MemorySearchFieldKey';

@visibleForTesting
final memorySearchFieldKey = GlobalKey(debugLabel: memorySearchFieldKeyName);

enum SnapshotStatus {
  none,
  streaming,
  graphing,
  grouping,
  done,
}

@visibleForTesting
class MemoryScreenKeys {
  static const leaksTab = Key('Leaks Tab');
  static const dartHeapTableProfileTab = Key('Dart Heap Profile Tab');
  static const dartHeapAllocationTracingTab =
      Key('Dart Heap Allocation Tracing Tab');
  static const diffTab = Key('Diff Tab');
}

class MemoryTabs extends StatefulWidget {
  const MemoryTabs(
    this.controller,
  );

  final MemoryController controller;

  @override
  _MemoryTabsState createState() => _MemoryTabsState();
}

class _MemoryTabsState extends State<MemoryTabs>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, MemoryTabs>,
        SearchFieldMixin<MemoryTabs>,
        TickerProviderStateMixin {
  static const _gaPrefix = 'memoryTab';

  late List<Tab> _tabs;
  late TabController _tabController;
  final ValueNotifier<int> _currentTab = ValueNotifier(0);

  late AnimationController _animation;

  void _initTabs() {
    _tabs = [
      DevToolsTab.create(
        key: MemoryScreenKeys.dartHeapTableProfileTab,
        tabName: 'Profile',
        gaPrefix: _gaPrefix,
      ),
      DevToolsTab.create(
        key: MemoryScreenKeys.dartHeapAllocationTracingTab,
        tabName: 'Allocation Tracing',
        gaPrefix: _gaPrefix,
      ),
      DevToolsTab.create(
        key: MemoryScreenKeys.diffTab,
        gaPrefix: _gaPrefix,
        tabName: 'Diff',
      ),
      if (widget.controller.shouldShowLeaksTab.value)
        DevToolsTab.create(
          key: MemoryScreenKeys.leaksTab,
          gaPrefix: _gaPrefix,
          tabName: 'Leaks',
        ),
    ];

    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() => _currentTab.value = _tabController.index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();

    _initTabs();

    addAutoDisposeListener(controller.shouldShowLeaksTab, () {
      setState(() {
        _initTabs();
      });
    });

    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.selectionSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.filterNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.leafSelectedNotifier, () {
      setState(() {
        controller.computeRoot();
      });
    });

    addAutoDisposeListener(controller.leafAnalysisSelectedNotifier, () {
      setState(() {
        controller.computeAnalysisInstanceRoot();
      });
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();

    super.dispose();
  }

  /// Enable to output debugging information for auto-snapshot.
  /// WARNING: Do not checkin with this flag set to true.
  final debugSnapshots = false;

  SnapshotStatus snapshotState = SnapshotStatus.none;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: defaultSpacing),
        ValueListenableBuilder<int>(
          valueListenable: _currentTab,
          builder: (context, index, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TabBar(
                labelColor: themeData.textTheme.bodyLarge!.color,
                isScrollable: true,
                controller: _tabController,
                tabs: _tabs,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            controller: _tabController,
            children: [
              // Profile Tab
              KeepAliveWrapper(
                child: AllocationProfileTableView(
                  controller: controller.allocationProfileController,
                ),
              ),
              const KeepAliveWrapper(
                child: AllocationProfileTracingView(),
              ),
              // Diff tab.
              KeepAliveWrapper(
                child: DiffPane(
                  diffController: controller.diffPaneController,
                ),
              ),
              // Leaks tab.
              if (controller.shouldShowLeaksTab.value)
                const KeepAliveWrapper(child: LeaksPane()),
            ],
          ),
        ),
      ],
    );
  }

  Widget tableExample(IconData? iconData, String entry) {
    final themeData = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconData == null
            ? Text(' ', style: themeData.fixedFontStyle)
            : Icon(iconData),
        Text(entry, style: themeData.fixedFontStyle),
      ],
    );
  }

  Widget helpScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Click a leaf node instance of a class to\n'
          'inspect the fields of that instance e.g.,',
        ),
        const SizedBox(height: defaultSpacing),
        tableExample(Icons.expand_more, 'dart:collection'),
        tableExample(Icons.expand_more, 'SplayTreeMap'),
        const SizedBox(height: denseRowSpacing),
        tableExample(null, 'Instance 0'),
      ],
    );
  }

  Timer? removeUpdateBubble;

  Widget textWidgetWithUpdateCircle(
    String text, {
    TextStyle? style,
    double? size,
  }) {
    final textWidth = textWidgetWidth(text, style: style);

    return Stack(
      children: [
        Positioned(
          child: Container(
            width: textWidth + 10,
            child: Text(text, style: style),
          ),
        ),
        Positioned(
          right: 0,
          child: Container(
            alignment: Alignment.topRight,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue[400],
            ),
            child: const Icon(Icons.fiber_manual_record, size: 0),
          ),
        ),
      ],
    );
  }

  static const maxWidth = 800.0;

  double textWidgetWidth(String message, {TextStyle? style}) {
    // Longest message must fit in this width.
    const constraints = BoxConstraints(
      maxWidth: maxWidth,
    );

    // TODO(terry): Is there a better (less heavyweight) way of computing text
    //              width than using the widget pipeline?
    final richTextWidget = Text.rich(TextSpan(text: message), style: style)
        .build(context) as RichText;
    final renderObject = richTextWidget.createRenderObject(context);
    renderObject.layout(constraints);
    final boxes = renderObject.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: TextSpan(text: message).toPlainText().length,
      ),
    );

    final textWidth = boxes.last.right;

    if (textWidth > maxWidth) {
      // TODO(terry): If message > 800 pixels in width (not possible
      //              today) but could be more robust.
      logger.log(
        'Computed text width > $maxWidth ($textWidth)\nmessage=$message.',
        logger.LogLevel.warning,
      );
    }

    return textWidth;
  }

  Future<void> doGroupBy() async {
    controller.heapGraph!
      ..computeInstancesForClasses()
      ..computeRawGroups()
      ..computeFilteredGroups();
  }
}

/// Snapshot TreeTable
class MemoryHeapTable extends StatefulWidget {
  @override
  MemoryHeapTableState createState() => MemoryHeapTableState();
}

/// A table of the Memory graph class top-down call tree.
class MemoryHeapTableState extends State<MemoryHeapTable>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, MemoryHeapTable> {
  final TreeColumnData<Reference> _treeColumn = _LibraryRefColumn();

  final List<ColumnData<Reference>> _columns = [];

  @override
  void initState() {
    super.initState();

    // Setup the table columns.
    _columns.addAll([
      _treeColumn,
      _ClassOrInstanceCountColumn(),
      _ShallowSizeColumn(),
      // TODO(terry): Don't display until dominator is implemented
      //              Issue https://github.com/flutter/devtools/issues/2688
      // _RetainedSizeColumn(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();

    // Update the tree when the tree state changes e.g., expand, collapse, etc.
    addAutoDisposeListener(controller.treeChangedNotifier, () {
      if (controller.isTreeChanged) {
        setState(() {});
      }
    });

    // Update the tree when the memorySource changes.
    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.filterNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });
  }

  List<String> _maybeAddMatch(Reference reference, String search) {
    final matches = <String>[];

    final match = matchSearch(reference, search);
    if (match != null) {
      matches.add(match);
    }

    return matches;
  }

  List<String> matchesInLibrary(
    LibraryReference libraryReference,
    String searchingValue,
  ) {
    final matches = _maybeAddMatch(libraryReference, searchingValue);

    final List<Reference> classes = libraryReference.children;
    matches.addAll(matchClasses(classes, searchingValue));

    return matches;
  }

  List<String> matchClasses(
    List<Reference> classReferences,
    String searchingValue,
  ) {
    final matches = <String>[];

    // Check the class names in the library
    for (final ClassReference classReference
        in classReferences.cast<ClassReference>()) {
      matches.addAll(_maybeAddMatch(classReference, searchingValue));
    }

    // Remove duplicates
    return matches;
  }

  /// Return null if no match, otherwise string.
  String? matchSearch(Reference ref, String matchString) {
    final knownName = ref.name!.toLowerCase();
    if (knownName.contains(matchString.toLowerCase())) {
      return ref.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final root = controller.buildTreeFromAllData();
    Widget result;
    if (root != null && root.children.isNotEmpty) {
      // Snapshots and analyses exists display the trees.
      controller.groupByTreeTable = TreeTable<Reference>(
        keyFactory: (libRef) => PageStorageKey<String?>(libRef.name),
        dataRoots: root.children,
        dataKey: 'memory-snapshot-tree',
        columns: _columns,
        treeColumn: _treeColumn,
        defaultSortColumn: _columns[0],
        defaultSortDirection: SortDirection.ascending,
        selectionNotifier: controller.selectionSnapshotNotifier,
      );

      result = controller.groupByTreeTable;
    } else {
      // Nothing collected yet (snapshots/analyses) - return an empty area.
      result = const SizedBox();
    }
    return OutlineDecoration(child: result);
  }
}

class _LibraryRefColumn extends TreeColumnData<Reference> {
  _LibraryRefColumn() : super('Library or Class');

  @override
  String getValue(Reference dataObject) {
    // Should never be empty when we're displaying in table.
    assert(!dataObject.isEmptyReference);

    if (dataObject.isLibrary) {
      final value = (dataObject as LibraryReference).name ?? '';
      final splitValues = value.split('/');

      return splitValues.length > 1
          ? '${splitValues[0]}/${splitValues[1]}'
          : splitValues[0];
    }

    return dataObject.name ?? '';
  }

  @override
  String getDisplayValue(Reference dataObject) => getValue(dataObject);

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(Reference dataObject) {
    return dataObject.name ?? '';
  }
}

class _ClassOrInstanceCountColumn extends ColumnData<Reference> {
  _ClassOrInstanceCountColumn()
      : super(
          'Count',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(75.0),
        );

  @override
  int getValue(Reference dataObject) {
    assert(!dataObject.isEmptyReference);

    // Although the method returns dynamic this implementatation only
    // returns int.

    if (dataObject.name == MemoryController.libraryRootNode ||
        dataObject.name == MemoryController.classRootNode) return 0;

    if (dataObject.isExternal) {
      return dataObject.children.length;
    }

    if (dataObject.isAnalysis && dataObject is AnalysisReference) {
      final AnalysisReference analysisReference = dataObject;
      return analysisReference.countNote ?? 0;
    }

    if (dataObject.isSnapshot && dataObject is SnapshotReference) {
      int count = 0;
      final SnapshotReference snapshotRef = dataObject;
      for (final child in snapshotRef.children) {
        count += _computeCount(child);
      }
      return count;
    }

    return _computeCount(dataObject);
  }

  /// Return a count based on the Reference type e.g., library, filtered,
  /// class, externals, etc.  Only compute once, store in the Reference.
  int _computeCount(Reference ref) {
    // Only compute the children counts once then store in the Reference.
    if (ref.hasCount) return ref.count!;

    int count = 0;

    if (ref.isClass) {
      final classRef = ref as ClassReference;
      count = _computeClassInstances(classRef.actualClass!)!;
    } else if (ref.isLibrary) {
      // Return number of classes.
      final LibraryReference libraryReference = ref as LibraryReference;
      for (final heapClass in libraryReference.actualClasses!) {
        count += _computeClassInstances(heapClass)!;
      }
    } else if (ref.isFiltered) {
      final FilteredReference filteredRef = ref as FilteredReference;
      for (final LibraryReference child
          in filteredRef.children.cast<LibraryReference>()) {
        for (final heapClass in child.actualClasses!) {
          count += _computeClassInstances(heapClass)!;
        }
      }
    } else if (ref.isExternals) {
      for (ExternalReference externalRef
          in ref.children.cast<ExternalReference>()) {
        count += externalRef.children.length;
      }
    } else if (ref.isExternal) {
      final ExternalReference externalRef = ref as ExternalReference;
      count = externalRef.children.length;
    }

    // Only compute once.
    ref.count = count;

    return count;
  }

  int? _computeClassInstances(HeapGraphClassLive liveClass) =>
      liveClass.instancesCount != null ? liveClass.instancesCount : null;

  /// Internal helper for all count values.
  String _displayCount(int? count) => count == null ? '--' : '$count';

  @override
  String getDisplayValue(Reference dataObject) =>
      _displayCount(getValue(dataObject));

  @override
  bool get supportsSorting => true;

  @override
  int compare(Reference a, Reference b) {
    // Analysis is always before.
    final Comparable valueA = a.isAnalysis ? 0 : getValue(a);
    final Comparable valueB = b.isAnalysis ? 0 : getValue(b);
    return valueA.compareTo(valueB);
  }
}

class _ShallowSizeColumn extends ColumnData<Reference> {
  _ShallowSizeColumn()
      : super(
          'Shallow',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(100.0),
        );

  int sizeAllVisibleLibraries(List<Reference> references) {
    var sum = 0;
    for (final ref in references) {
      if (ref.isLibrary) {
        final libraryReference = ref as LibraryReference;
        for (final actualClass in libraryReference.actualClasses!) {
          sum += actualClass.instancesTotalShallowSizes;
        }
      }
    }
    return sum;
  }

  @override
  dynamic getValue(Reference dataObject) {
    // Should never be empty when we're displaying in table.
    assert(!dataObject.isEmptyReference);

    if (dataObject.name == MemoryController.libraryRootNode ||
        dataObject.name == MemoryController.classRootNode) {
      final snapshot = dataObject.controller!.getSnapshot(dataObject)!;
      final snapshotGraph = snapshot.snapshotGraph;
      return snapshotGraph.shallowSize + snapshotGraph.externalSize;
    }

    if (dataObject.isAnalysis && dataObject is AnalysisReference) {
      final AnalysisReference analysisReference = dataObject;
      final size = analysisReference.sizeNote;
      return size ?? '';
    } else if (dataObject.isSnapshot && dataObject is SnapshotReference) {
      var sum = 0;
      final SnapshotReference snapshotRef = dataObject;
      for (final childRef in snapshotRef.children) {
        sum += _sumShallowSize(childRef) ?? 0;
      }
      return sum;
    } else {
      final sum = _sumShallowSize(dataObject);
      return sum ?? '';
    }
  }

  int? _sumShallowSize(Reference ref) {
    if (ref.isLibrary) {
      // Return number of classes.
      final libraryReference = ref as LibraryReference;
      var sum = 0;
      for (final actualClass in libraryReference.actualClasses!) {
        sum += actualClass.instancesTotalShallowSizes;
      }
      return sum;
    } else if (ref.isClass) {
      final classReference = ref as ClassReference;
      return classReference.actualClass!.instancesTotalShallowSizes;
    } else if (ref.isObject) {
      // Return number of instances.
      final objectReference = ref as ObjectReference;

      var size = objectReference.instance.origin.shallowSize;

      // If it's an external object then return the externalSize too.
      if (ref is ExternalObjectReference) {
        final ExternalObjectReference externalRef = ref;
        size += externalRef.externalSize;
      }

      return size;
    } else if (ref.isFiltered) {
      final snapshot = ref.controller!.getSnapshot(ref)!;
      final sum = sizeAllVisibleLibraries(snapshot.libraryRoot?.children ?? []);
      final snapshotGraph = snapshot.snapshotGraph;
      return snapshotGraph.shallowSize - sum;
    } else if (ref.isExternals) {
      final snapshot = ref.controller!.getSnapshot(ref)!;
      return snapshot.snapshotGraph.externalSize;
    } else if (ref.isExternal) {
      return (ref as ExternalReference).sumExternalSizes;
    }

    return null;
  }

  @override
  String getDisplayValue(Reference dataObject) {
    final value = getValue(dataObject);

    // TODO(terry): Add percent to display too.
/*
    final total = dataObject.controller.snapshots.last.snapshotGraph.capacity;
    final percentage = (value / total) * 100;
    final displayPercentage = percentage < .050 ? '<<1%'
        : '${NumberFormat.compact().format(percentage)}%';
    print('$displayPercentage [${NumberFormat.compact().format(percentage)}%]');
*/
    if ((dataObject.isAnalysis ||
            dataObject.isAllocations ||
            dataObject.isAllocation) &&
        value is! int) return '';

    return prettyPrintBytes(
      value as int,
      kbFractionDigits: 1,
      includeUnit: true,
    )!;
  }

  @override
  bool get supportsSorting => true;

  @override
  int compare(Reference a, Reference b) {
    // Analysis is always before.
    final Comparable valueA = a.isAnalysis ? 0 : getValue(a);
    final Comparable valueB = b.isAnalysis ? 0 : getValue(b);
    return valueA.compareTo(valueB);
  }
}

// TODO(terry): Remove ignore when dominator is implemented.
// ignore: unused_element
class _RetainedSizeColumn extends ColumnData<Reference> {
  _RetainedSizeColumn()
      : super(
          'Retained',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(100.0),
        );

  @override
  dynamic getValue(Reference dataObject) {
    // Should never be empty when we're displaying in table.
    assert(!dataObject.isEmptyReference);

    if (dataObject.name == MemoryController.libraryRootNode ||
        dataObject.name == MemoryController.classRootNode) return '';

    if (dataObject.isLibrary) {
      // Return number of classes.
      final libraryReference = dataObject as LibraryReference;
      var sum = 0;
      for (final actualClass in libraryReference.actualClasses!) {
        sum += actualClass.instancesTotalShallowSizes;
      }
      return sum;
    } else if (dataObject.isClass) {
      final classReference = dataObject as ClassReference;
      return classReference.actualClass!.instancesTotalShallowSizes;
    } else if (dataObject.isObject) {
      // Return number of instances.
      final objectReference = dataObject as ObjectReference;
      return objectReference.instance.origin.shallowSize;
    } else if (dataObject.isExternals) {
      return dataObject.controller!.lastSnapshot!.snapshotGraph.externalSize;
    } else if (dataObject.isExternal) {
      return (dataObject as ExternalReference)
          .liveExternal
          .externalProperty
          .externalSize;
    }

    return '';
  }

  @override
  String getDisplayValue(Reference dataObject) {
    final value = getValue(dataObject);
    return '$value';
  }

  @override
  bool get supportsSorting => true;

  @override
  int compare(Reference a, Reference b) {
    // Analysis is always before.
    final Comparable valueA = a.isAnalysis ? 0 : getValue(a);
    final Comparable valueB = b.isAnalysis ? 0 : getValue(b);
    return valueA.compareTo(valueB);
  }
}
