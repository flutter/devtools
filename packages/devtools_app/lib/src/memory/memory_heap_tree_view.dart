// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../config_specific/logger/logger.dart' as logger;
import '../table.dart';
import '../table_data.dart';
import '../theme.dart';
import '../ui/label.dart';
import '../utils.dart';
import 'memory_analyzer.dart';
import 'memory_controller.dart';
import 'memory_filter.dart';
import 'memory_graph_model.dart';
import 'memory_heatmap.dart';
import 'memory_snapshot_models.dart';
import 'memory_utils.dart';

class HeapTree extends StatefulWidget {
  const HeapTree(
    this.controller,
  );

  final MemoryController controller;

  @override
  HeapTreeViewState createState() => HeapTreeViewState();
}

enum SnapshotStatus {
  none,
  streaming,
  graphing,
  grouping,
  done,
}

enum WildcardMatch {
  exact,
  startsWith,
  endsWith,
  contains,
}

/// If no wildcard then exact match.
/// *NNN - ends with NNN
/// NNN* - starts with NNN
/// NNN*ZZZ - starts with NNN and ends with ZZZ
const knowClassesToAnalyzeForImages = <WildcardMatch, List<String>>{
  // Anything that contains the phrase:
  WildcardMatch.contains: [
    'Image',
  ],

  // Anything that starts with:
  WildcardMatch.startsWith: [],

  // Anything that exactly matches:
  WildcardMatch.exact: [
    '_Int32List',
    'FrameInfos',
  ],

  // Anything that ends with:
  WildcardMatch.endsWith: [],
};

/// RegEx expressions to handle the WildcardMatches:
///     Ends with Image:      \[_A-Za-z0-9_]*Image\$
///     Starts with Image:    ^Image
///     Contains Image:       Image
///     Extact Image:         ^Image$
String buildRegExs(Map<WildcardMatch, List<String>> matchingCriteria) {
  final resultRegEx = StringBuffer();
  matchingCriteria.forEach((key, value) {
    if (value.isNotEmpty) {
      final name = value;
      String regEx;
      // TODO(terry): Need to handle $ for identifier names e.g.,
      //              $FOO is a valid identifier.
      switch (key) {
        case WildcardMatch.exact:
          regEx = '^${name.join("\$|^")}\$';
          break;
        case WildcardMatch.startsWith:
          regEx = '^${name.join("|^")}';
          break;
        case WildcardMatch.endsWith:
          regEx = '^\[_A-Za-z0-9]*${name.join("\|[_A-Za-z0-9]*")}\$';
          break;
        case WildcardMatch.contains:
          regEx = '${name.join("|")}';
          break;
        default:
          assert(false, 'buildRegExs: Unhandled WildcardMatch');
      }
      resultRegEx.write(resultRegEx.isEmpty ? '($regEx' : '|$regEx');
    }
  });

  resultRegEx.write(')');
  return resultRegEx.toString();
}

final String knownClassesRegExs = buildRegExs(knowClassesToAnalyzeForImages);

class HeapTreeViewState extends State<HeapTree> with AutoDisposeMixin {
  @visibleForTesting
  static const snapshotButtonKey = Key('Snapshot Button');
  @visibleForTesting
  static const groupByClassButtonKey = Key('Group By Class Button');
  @visibleForTesting
  static const groupByLibraryButtonKey = Key('Group By Library Button');
  @visibleForTesting
  static const collapseAllButtonKey = Key('Collapse All Button');
  @visibleForTesting
  static const expandAllButtonKey = Key('Expand All Button');
  @visibleForTesting
  static const searchButtonKey = Key('Snapshot Search');
  @visibleForTesting
  static const filterButtonKey = Key('Snapshot Filter');
  @visibleForTesting
  static const analyzeButtonKey = Key('Snapshot Analyze');
  @visibleForTesting
  static const settingsButtonKey = Key('Snapshot Settings');

  MemoryController controller;

  Widget snapshotDisplay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<MemoryController>(context);
    if (newController == controller) return;
    controller = newController;

    cancel();

    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(true, true);
      });
    });

    addAutoDisposeListener(controller.filterNotifier, () {
      setState(() {
        controller.computeAllLibraries(true, true);
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

    addAutoDisposeListener(controller.searchNotifier, () {
      setState(() {
        closeAutoCompleteOverlay();
      });
    });

    addAutoDisposeListener(controller.searchAutoCompleteNotifier, () {
      setState(autoCompleteOverlaySetState(controller, context));
    });
  }

  @override
  void dispose() {
    // Clean up the TextFieldController and FocusNode.
    searchTextFieldController.dispose();
    searchFieldFocusNode.dispose();

    rawKeyboardFocusNode.dispose();

    super.dispose();
  }

  SnapshotStatus snapshotState = SnapshotStatus.none;

  bool get _isSnapshotRunning =>
      snapshotState != SnapshotStatus.done &&
      snapshotState != SnapshotStatus.none;

  bool get _isSnapshotStreaming => snapshotState == SnapshotStatus.streaming;

  bool get _isSnapshotGraphing => snapshotState == SnapshotStatus.graphing;

  bool get _isSnapshotGrouping => snapshotState == SnapshotStatus.grouping;

  bool get _isSnapshotComplete => snapshotState == SnapshotStatus.done;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_isSnapshotRunning) {
      snapshotDisplay = Column(children: [
        const SizedBox(height: 50.0),
        snapshotDisplay = const CircularProgressIndicator(),
        const SizedBox(height: denseSpacing),
        Text(_isSnapshotStreaming
            ? 'Processing...'
            : _isSnapshotGraphing
                ? 'Graphing...'
                : _isSnapshotGrouping
                    ? 'Grouping...'
                    : _isSnapshotComplete ? 'Done' : '...'),
      ]);
    } else if (controller.snapshotByLibraryData != null) {
      if (controller.showHeatMap.value) {
        snapshotDisplay = HeatMapSizeAnalyzer(
          child: SizedBox.expand(
            child: FlameChart(controller),
          ),
        );
      } else {
        snapshotDisplay = MemorySnapshotTable();
      }
    } else {
      snapshotDisplay = const SizedBox();
    }

    return Column(
      children: [
        Row(
          children: [
            _buildSnapshotControls(textTheme),
            const Expanded(child: SizedBox(width: defaultSpacing)),
            _buildSearchFilterControls(),
          ],
        ),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: OutlineDecoration(
            child: buildSnapshotTables(snapshotDisplay),
          ),
        ),
      ],
    );
  }

  Widget buildSnapshotTables(Widget snapshotDisplay) {
    final hasDetails =
        controller.isLeafSelected || controller.isAnalysisLeafSelected;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(child: snapshotDisplay),
        if (hasDetails) const SizedBox(width: defaultSpacing),
        // TODO(terry): Need better focus handling between 2 tables & up/down
        //              arrows in the right-side field instance view table.
        controller.isLeafSelected
            ? Expanded(child: SnapshotInstanceViewTable())
            : controller.isAnalysisLeafSelected
                ? Expanded(child: AnalysisInstanceViewTable())
                : const SizedBox(),
      ],
    );
  }

  @visibleForTesting
  static const groupByMenuButtonKey = Key('Group By Menu Button');
  @visibleForTesting
  static const groupByMenuItem = Key('Filter Group By Menu Item');
  @visibleForTesting
  static const groupByKey = Key('Filter Group By');

  Widget _groupByDropdown(TextTheme textTheme) {
    final _groupByTypes = [
      MemoryController.groupByLibrary,
      MemoryController.groupByClass,
      MemoryController.groupByInstance,
    ].map<DropdownMenuItem<String>>(
      (
        String value,
      ) {
        return DropdownMenuItem<String>(
          key: groupByMenuItem,
          value: value,
          child: Text(
            'Group by $value',
            key: groupByKey,
          ),
        );
      },
    ).toList();

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: groupByMenuButtonKey,
        style: textTheme.bodyText2,
        value: controller.groupingBy.value,
        onChanged: (String newValue) {
          setState(
            () {
              controller.selectedLeaf = null;
              controller.groupingBy.value = newValue;
              if (controller.snapshots.isNotEmpty) {
                doGroupBy();
              }
            },
          );
        },
        items: _groupByTypes,
      ),
    );
  }

  Widget _buildSnapshotControls(TextTheme textTheme) {
    return Row(
      children: [
        OutlineButton(
          key: snapshotButtonKey,
          onPressed: _isSnapshotRunning ? null : _snapshot,
          child: const MaterialIconLabel(
            Icons.camera,
            'Snapshot',
            includeTextWidth: 200,
          ),
        ),
        const SizedBox(width: defaultSpacing),
        Row(
          children: [
            const Text('Heat Map'),
            Switch(
              value: controller.showHeatMap.value,
              onChanged: (value) {
                setState(() {
                  closeAutoCompleteOverlay();
                  controller.toggleShowHeatMap(value);
                  controller.search = '';
                  controller.selectedLeaf = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(width: defaultSpacing),
        controller.showHeatMap.value
            ? const SizedBox()
            : _groupByDropdown(textTheme),
        const SizedBox(width: defaultSpacing),
        // TODO(terry): Mechanism to handle expand/collapse on both
        // tables objects/fields. Maybe notion in table?
        controller.showHeatMap.value
            ? const SizedBox()
            : OutlineButton(
                key: collapseAllButtonKey,
                onPressed: snapshotDisplay is MemorySnapshotTable
                    ? () {
                        if (snapshotDisplay is MemorySnapshotTable) {
                          controller.groupByTreeTable.dataRoots
                              .every((element) {
                            element.collapseCascading();
                            return true;
                          });
                          if (controller.instanceFieldsTreeTable != null) {
                            // We're collapsing close the fields table.
                            controller.selectedLeaf = null;
                          }
                          setState(() {});
                        }
                      }
                    : null,
                child: const Text('Collapse All'),
              ),
        controller.showHeatMap.value
            ? const SizedBox()
            : OutlineButton(
                key: expandAllButtonKey,
                onPressed: snapshotDisplay is MemorySnapshotTable
                    ? () {
                        if (snapshotDisplay is MemorySnapshotTable) {
                          controller.groupByTreeTable.dataRoots
                              .every((element) {
                            element.expandCascading();
                            return true;
                          });
                          setState(() {});
                        }
                      }
                    : null,
                child: const Text('Expand All'),
              ),
      ],
    );
  }

  FocusNode searchFieldFocusNode;
  TextEditingController searchTextFieldController;
  FocusNode rawKeyboardFocusNode;

  void clearSearchField({force = false}) {
    if (force || controller.search.isNotEmpty) {
      searchTextFieldController.clear();
      controller.search = '';
    }
  }

  Widget createSearchField() {
    // Creating new TextEditingController.
    searchFieldFocusNode = FocusNode();

    searchFieldFocusNode.addListener(() {
      if (!searchFieldFocusNode.hasFocus) {
        closeAutoCompleteOverlay();
      }
    });

    searchTextFieldController = TextEditingController(text: controller.search);
    searchTextFieldController.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.search.length));

    final searchField = CompositedTransformTarget(
      link: autoCompletelayerLink,
      child: TextField(
        key: memorySearchFieldKey,
        autofocus: true,
        enabled: controller.snapshots.isNotEmpty,
        focusNode: searchFieldFocusNode,
        controller: searchTextFieldController,
        onChanged: (value) {
          controller.search = value;
        },
        onEditingComplete: () {
          searchFieldFocusNode.requestFocus();
        },
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(8),
          border: const OutlineInputBorder(),
          labelText: 'Search',
          hintText: 'Search',
          suffix: IconButton(
            padding: const EdgeInsets.all(0.0),
            onPressed: () {
              clearSearchField();
            },
            icon: const Icon(Icons.clear, size: 16),
          ),
        ),
      ),
    );

    if (controller.showHeatMap.value && controller.snapshots.isNotEmpty) {
      searchFieldFocusNode.requestFocus();
    }

    return searchField;
  }

  /// Match, found,  select it and process via ValueNotifiers.
  void selectTheMatch(String foundName) {
    setState(() {
      if (snapshotDisplay is MemorySnapshotTable) {
        controller.groupByTreeTable.dataRoots.every((element) {
          element.collapseCascading();
          return true;
        });
      }
    });

    searchTextFieldController.clear();
    closeAutoCompleteOverlay();
    controller.search = foundName;
    controller.selectTheSearch = true;
    clearSearchField(force: true);
  }

  Widget _buildSearchFilterControls() {
    rawKeyboardFocusNode = FocusNode();

    final searchAndRawKeyboard = RawKeyboardListener(
      child: createSearchField(),
      focusNode: rawKeyboardFocusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey.keyId == LogicalKeyboardKey.escape.keyId) {
            // ESCAPE key pressed clear search TextField.
            clearSearchField();
          } else if (event.logicalKey.keyId == LogicalKeyboardKey.enter.keyId) {
            // ENTER pressed.
            var foundExact = false;
            // Find exact match in autocomplete list - use that as our search value.
            for (final autoEntry in controller.searchAutoComplete.value) {
              if (controller.search.toLowerCase() == autoEntry.toLowerCase()) {
                foundExact = true;
                selectTheMatch(autoEntry);
              }
            }
            // Nothing found, pick first line in dropdown.
            if (!foundExact) {
              final autoCompleteList = controller.searchAutoComplete.value;
              if (autoCompleteList.isNotEmpty) {
                selectTheMatch(autoCompleteList.first);
              }
            }
          }
        }
      },
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          // TODO(terry): Use a more adaptive layout than forcing to 300.0
          width: defaultSearchTextWidth,
          height: defaultSearchTextHeight,
          child: searchAndRawKeyboard,
        ),
        const SizedBox(width: denseSpacing),
        Flexible(
          child: OutlineButton(
            key: filterButtonKey,
            onPressed: _filter,
            child: const MaterialIconLabel(
              Icons.filter_list,
              'Filter',
              includeTextWidth: 200,
            ),
          ),
        ),
        const SizedBox(width: denseSpacing),
        Flexible(
          child: OutlineButton(
            key: analyzeButtonKey,
            onPressed: controller.enableAnalyzeButton() ? _analyze : null,
            child: const MaterialIconLabel(
              Icons.highlight,
              'Analyze',
              includeTextWidth: 200,
            ),
          ),
        ),
        const SizedBox(width: denseSpacing),
        OutlineButton(
          key: settingsButtonKey,
          onPressed: _settings,
          child: const MaterialIconLabel(
            Icons.settings,
            'Settings',
            includeTextWidth: 200,
          ),
        ),
      ],
    );
  }

  void _snapshot() async {
    setState(() {
      snapshotState = SnapshotStatus.streaming;
    });

    final snapshotTimestamp = DateTime.now();

    final graph = await controller.snapshotMemory();
    final snapshotCollectionTime = DateTime.now();

    setState(() {
      snapshotState = SnapshotStatus.graphing;
    });

    // To debug particular classes add their names to the last
    // parameter classNamesToMonitor e.g., ['AppStateModel', 'Terry', 'TerryEntry']
    controller.heapGraph = convertHeapGraph(
      controller,
      graph,
      [],
    );
    final snapshotGraphTime = DateTime.now();

    controller.storeSnapshot(snapshotTimestamp, graph);

    setState(() {
      snapshotState = SnapshotStatus.grouping;
    });

    await doGroupBy();
    controller.computeAllLibraries();
    final snapshotDoneTime = DateTime.now();

    controller.selectedSnapshotTimestamp =
        DateFormat('dd-MMM-yyyy@H:m.s').format(snapshotTimestamp);

    updateListOfSnapshotsUnderAnalysisNode();

    logger.log('Total Snapshot completed in'
        ' ${snapshotDoneTime.difference(snapshotTimestamp).inMilliseconds / 1000} seconds');
    logger.log('  Snapshot collected in'
        ' ${snapshotCollectionTime.difference(snapshotTimestamp).inMilliseconds / 1000} seconds');
    logger.log('  Snapshot graph built in'
        ' ${snapshotGraphTime.difference(snapshotCollectionTime).inMilliseconds / 1000} seconds');
    logger.log('  Snapshot grouping/libraries computed in'
        ' ${snapshotDoneTime.difference(snapshotGraphTime).inMilliseconds / 1000} seconds');

    setState(() {
      snapshotState = SnapshotStatus.done;
    });
  }

  Future<void> doGroupBy() async {
    controller.heapGraph
      ..computeInstancesForClasses()
      ..computeRawGroups()
      ..computeFilteredGroups();
  }

  void _filter() {
    showDialog(
      context: context,
      builder: (BuildContext context) => SnapshotFilterDialog(controller),
    );
  }

  void updateListOfSnapshotsUnderAnalysisNode() {
    final AnalysesReference analysesNode = findAnalysesNode(controller);
    assert(analysesNode != null);

    for (final snapshot in controller.snapshots) {
      final currentSnapDT = snapshot.collectedTimestamp;

      if (analysesNode.children.length == 1) {
        final node = analysesNode.children.first;
        if (node is AnalysisReference && node.name.isEmpty) {
          setState(() {
            analysesNode.collapse();
            analysesNode.children.clear();
          });
        }
      }

      AnalysisSnapshotReference analyzeSnapshot;
      final foundAnalysis = controller.completedAnalyses
          .where((analysis) => analysis.dateTime == currentSnapDT);
      if (foundAnalysis.isNotEmpty) {
        // If there's an analysis of this snapshot then show it.
        analyzeSnapshot = foundAnalysis.single;
      } else {
        analyzeSnapshot = AnalysisSnapshotReference(currentSnapDT);
      }

      analysesNode.addChild(analyzeSnapshot);
    }
  }

  void _analyze() {
    final AnalysesReference analysesNode = findAnalysesNode(controller);
    assert(analysesNode != null);

    final currentSnapDT = controller.snapshots.last.collectedTimestamp;

    // If an analysis of the current snapshot exist then do nothing.
    final foundSnapshot = analysesNode.children.where((analysis) {
      if (analysis is AnalysisSnapshotReference) {
        final AnalysisSnapshotReference node = analysis;
        return node.dateTime == currentSnapDT;
      }
      return false;
    });

    if (foundSnapshot.isNotEmpty && foundSnapshot.first.children.isNotEmpty) {
      // TODO(terry): Disable Analyze button if analysis exist for current snapshot.
      logger.log('Analysis already computed.', logger.LogLevel.warning);
      return;
    }

    // Analyze this snapshot.
    final analyzeSnapshot = foundSnapshot.single;

    final collectedData = collect(controller);

    // Analyze the collected data.

    // 1. Analysis of memory image usage.
    imageAnalysis(controller, analyzeSnapshot, collectedData);

    // Add to our list of completed analyses.
    controller.completedAnalyses.add(analyzeSnapshot);

    // Expand the 'Analysis' node.
    if (!analysesNode.isExpanded) {
      analysesNode.expand();
    }

    // Select the snapshot just analyzed.
    controller.selectionNotifier.value = Selection(
      node: analyzeSnapshot,
      nodeIndex: analyzeSnapshot.index,
      scrollIntoView: true,
    );

    // TODO(terry): Could be done if completedAnalyses was a ValueNotifier.
    //              Although still an empty setState in didChangeDependencies.
    // Rebuild Analyze button.
    setState(() {});
  }

  void _settings() {
    // TODO(terry): TBD
  }
}

class SnapshotInstanceViewTable extends StatefulWidget {
  @override
  SnapshotInstanceViewState createState() => SnapshotInstanceViewState();
}

/// Table of the fields of an instance (type, name and value).
class SnapshotInstanceViewState extends State<SnapshotInstanceViewTable>
    with AutoDisposeMixin {
  MemoryController controller;

  final TreeColumnData<FieldReference> treeColumn = _FieldTypeColumn();
  final List<ColumnData<FieldReference>> columns = [];

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
      _FieldNameColumn(),
      _FieldValueColumn(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    controller.instanceFieldsTreeTable = TreeTable<FieldReference>(
      dataRoots: controller.instanceRoot,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (typeRef) => PageStorageKey<String>(typeRef.name),
      sortColumn: columns[0],
      sortDirection: SortDirection.ascending,
    );

    return controller.instanceFieldsTreeTable;
  }
}

class _FieldTypeColumn extends TreeColumnData<FieldReference> {
  _FieldTypeColumn() : super('Type');

  @override
  dynamic getValue(FieldReference dataObject) =>
      dataObject.isEmptyReference || dataObject.isSentinelReference
          ? ''
          : dataObject.type;

  @override
  String getDisplayValue(FieldReference dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(FieldReference a, FieldReference b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 250.0;
}

class _FieldNameColumn extends ColumnData<FieldReference> {
  _FieldNameColumn() : super('Name');

  @override
  dynamic getValue(FieldReference dataObject) =>
      dataObject.isEmptyReference ? '' : dataObject.name;

  @override
  String getDisplayValue(FieldReference dataObject) =>
      '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(FieldReference a, FieldReference b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 150.0;
}

class _FieldValueColumn extends ColumnData<FieldReference> {
  _FieldValueColumn() : super('Value');

  @override
  dynamic getValue(FieldReference dataObject) =>
      dataObject.isEmptyReference || dataObject.isSentinelReference
          ? ''
          : dataObject.value;

  @override
  String getDisplayValue(FieldReference dataObject) {
    if (dataObject is ObjectFieldReference && !dataObject.isNull) {
      // Real object that isn't Null value is empty string.
      return '';
    }

    var value = getValue(dataObject);
    if (value is String && value.length > 30) {
      value = '${value.substring(0, 13)}…${value.substring(value.length - 17)}';
    }
    return '$value';
  }

  @override
  bool get supportsSorting => true;

  @override
  int compare(FieldReference a, FieldReference b) {
    final Comparable valueA = getValue(a);
    final Comparable valueB = getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 250.0;
}

/// Snapshot TreeTable

class MemorySnapshotTable extends StatefulWidget {
  @override
  MemorySnapshotTableState createState() => MemorySnapshotTableState();
}

/// A table of the Memory graph class top-down call tree.
class MemorySnapshotTableState extends State<MemorySnapshotTable>
    with AutoDisposeMixin {
  MemoryController controller;

  final TreeColumnData<Reference> treeColumn = _LibraryRefColumn();
  final List<ColumnData<Reference>> columns = [];

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
    addAutoDisposeListener(controller.filterNotifier, () {
      setState(() {
        controller.computeAllLibraries(true, true);
      });
    });

    addAutoDisposeListener(controller.searchAutoCompleteNotifier);

    addAutoDisposeListener(controller.selectTheSearchNotifier, () {
      if (_trySelectItem()) {
        setState(() {
          closeAutoCompleteOverlay();
        });
      }
    });

    addAutoDisposeListener(controller.searchNotifier, () {
      if (_trySelectItem()) {
        setState(() {
          closeAutoCompleteOverlay();
        });
      }
    });
  }

  bool _trySelectItem() {
    final searchingValue = controller.search;
    if (searchingValue.isNotEmpty) {
      if (controller.selectTheSearch) {
        // Found an exact match.
        selectItemInTree(searchingValue);
        controller.selectTheSearch = false;
        controller.search = '';
        return true;
      }

      // No exact match, return the list of possible matches.
      controller.clearSearchAutoComplete();

      final externalMatches = <String>[];
      final filteredMatches = <String>[];
      final matches = <String>[];

      switch (controller.groupingBy.value) {
        case MemoryController.groupByLibrary:
          for (final reference in controller.groupByTreeTable.dataRoots) {
            if (reference.isLibrary) {
              matches.addAll(matchesInLibrary(reference, searchingValue));
            } else if (reference.isExternals) {
              final ExternalReferences refs = reference;
              for (final ExternalReference ext in refs.children) {
                final match = matchSearch(ext, searchingValue);
                if (match != null) {
                  externalMatches.add(match);
                }
              }
            } else if (reference.isFiltered) {
              // Matches in the filtered nodes.
              final FilteredReference filteredReference = reference;
              for (final library in filteredReference.children) {
                filteredMatches.addAll(matchesInLibrary(
                  library,
                  searchingValue,
                ));
              }
            }
          }
          break;
        case MemoryController.groupByClass:
          matches.addAll(matchClasses(
              controller.groupByTreeTable.dataRoots, searchingValue));
          break;
        case MemoryController.groupByInstance:
          // TODO(terry): TBD
          break;
      }

      // Ordered in importance (matches, external, filtered).
      matches.addAll(externalMatches);
      matches.addAll(filteredMatches);

      // Remove duplicates and sort the matches.
      final normalizedMatches = matches.toSet().toList()..sort();
      // Use the top 10 matches:
      controller.searchAutoComplete.value = normalizedMatches.sublist(
          0,
          min(
            topMatchesLimit,
            normalizedMatches.length,
          ));
    }

    return false;
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
    for (final ClassReference classReference in classReferences) {
      matches.addAll(_maybeAddMatch(classReference, searchingValue));
    }

    // Remove duplicates
    return matches;
  }

  /// Return null if no match, otherwise string.
  String matchSearch(Reference ref, String matchString) {
    final knownName = ref.name.toLowerCase();
    if (knownName.contains(matchString.toLowerCase())) {
      return ref.name;
    }
    return null;
  }

  /// This finds and selects an exact match in the tree.
  /// Returns `true` if [searchingValue] is found in the tree.
  bool selectItemInTree(String searchingValue) {
    switch (controller.groupingBy.value) {
      case MemoryController.groupByLibrary:
        for (final reference in controller.groupByTreeTable.dataRoots) {
          if (reference.isLibrary) {
            final foundIt = _selectItemInTree(reference, searchingValue);
            if (foundIt) return true;
          } else if (reference.isFiltered) {
            // Matches in the filtered nodes.
            final FilteredReference filteredReference = reference;
            for (final library in filteredReference.children) {
              final foundIt = _selectItemInTree(library, searchingValue);
              if (foundIt) return true;
            }
          } else if (reference.isExternals) {
            final ExternalReferences refs = reference;
            for (final ExternalReference external in refs.children) {
              final foundIt = _selectItemInTree(external, searchingValue);
              if (foundIt) return true;
            }
          }
        }
        break;
      case MemoryController.groupByClass:
        for (final reference in controller.groupByTreeTable.dataRoots) {
          if (reference.isClass) {
            return _selecteClassInTree(reference, searchingValue);
          }
        }
        break;
      case MemoryController.groupByInstance:
        // TODO(terry): TBD
        break;
    }

    return false;
  }

  bool _selectInTree(Reference reference, search) {
    if (reference.name == search) {
      controller.selectionNotifier.value = Selection(
        node: reference,
        nodeIndex: reference.index,
        scrollIntoView: true,
      );
      controller.clearSearchAutoComplete();
      return true;
    }
    return false;
  }

  bool _selectItemInTree(Reference reference, String searchingValue) {
    // TODO(terry): Only finds first one.
    if (_selectInTree(reference, searchingValue)) return true;

    // Check the class names in the library
    return _selecteClassInTree(reference, searchingValue);
  }

  bool _selecteClassInTree(Reference reference, String searchingValue) {
    // Check the class names in the library
    for (final Reference classReference in reference.children) {
      // TODO(terry): Only finds first one.
      if (_selectInTree(classReference, searchingValue)) return true;
    }

    return false;
  }

  void setupColumns() {
    columns.addAll([
      treeColumn,
      _ClassOrInstanceCountColumn(),
      _ShallowSizeColumn(),
      _RetainedSizeColumn(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    LibraryReference root = controller.computeAllLibraries();
    if (controller.groupingBy.value == MemoryController.groupByClass) {
      root = controller.classRoot;
    }

    controller.groupByTreeTable = TreeTable<Reference>(
      dataRoots: root.children,
      columns: columns,
      treeColumn: treeColumn,
      keyFactory: (libRef) => PageStorageKey<String>(libRef.name),
      sortColumn: columns[0],
      sortDirection: SortDirection.ascending,
      selectionNotifier: controller.selectionNotifier,
    );

    return controller.groupByTreeTable;
  }
}

class _LibraryRefColumn extends TreeColumnData<Reference> {
  _LibraryRefColumn() : super('Library or Class');

  @override
  dynamic getValue(Reference dataObject) {
    // Should never be empty when we're displaying in table.
    assert(!dataObject.isEmptyReference);

    String value;
    if (dataObject.isLibrary) {
      value = (dataObject as LibraryReference).name;
      final splitValues = value.split('/');

      value = splitValues.length > 1
          ? '${splitValues[0]}/${splitValues[1]}'
          : splitValues[0];
    } else {
      value = dataObject.name;
    }

    return value;
  }

  @override
  String getDisplayValue(Reference dataObject) => getValue(dataObject);

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(Reference dataObject) {
    return dataObject.name;
  }

  @override
  double get fixedWidthPx => 250.0;
}

class _ClassOrInstanceCountColumn extends ColumnData<Reference> {
  _ClassOrInstanceCountColumn()
      : super('Count', alignment: ColumnAlignment.right);

  @override
  dynamic getValue(Reference dataObject) {
    assert(!dataObject.isEmptyReference);

    if (dataObject.name == MemoryController.libraryRootNode ||
        dataObject.name == MemoryController.classRootNode) return '';

    if (dataObject.isExternals) {
      if (dataObject.hasCount) return dataObject.count;

      var count = 0;
      for (ExternalReference externalRef in dataObject.children) {
        count += externalRef.children.length;
      }
      return count;
    } else if (dataObject.isExternal) {
      return dataObject.children.length;
    } else if (dataObject.isFiltered) {
      int sum = 0;
      final FilteredReference filteredRef = dataObject;
      for (final LibraryReference child in filteredRef.children) {
        for (final HeapGraphClassLive liveClass in child.actualClasses) {
          // Have the instances been realized (null implies no)
          if (liveClass.instancesCount != null) {
            sum += liveClass.instancesCount;
          }
        }
      }

      return sum;
    } else if (dataObject.isAnalysis && dataObject is AnalysisReference) {
      final AnalysisReference analysisReference = dataObject;
      final count = analysisReference.countNote;
      return count == null ? '' : count;
    }

    final count = _computeCount(dataObject);

    return count == null ? '--' : count;
  }

  /// Return of null implies count can't be computed.
  int _computeCount(Reference ref) {
    // Only compute the children counts once then store in the Reference.
    if (ref.hasCount) return ref.count;

    int count;

    if (ref.isClass) {
      final ClassReference classRef = ref;
      count = _computeClassInstances(classRef.actualClass);
    } else if (ref.isLibrary) {
      count = 0;
      // Return number of classes.
      final LibraryReference libraryReference = ref;
      for (final heapClass in libraryReference.actualClasses) {
        count += _computeClassInstances(heapClass);
      }
    } else if (ref.isFiltered) {
      count = 0;
      final FilteredReference filteredRef = ref;
      for (final LibraryReference child in filteredRef.children) {
        for (final heapClass in child.actualClasses) {
          count += _computeClassInstances(heapClass);
        }
      }
    }

    // Only compute once.
    ref.count = count;

    return count;
  }

  int _computeClassInstances(HeapGraphClassLive liveClass) =>
      liveClass.instancesCount != null ? liveClass.instancesCount : null;

  @override
  String getDisplayValue(Reference dataObject) => '${getValue(dataObject)}';

  @override
  bool get supportsSorting => true;

  @override
  int compare(Reference a, Reference b) {
    // Analysis is always before.
    final Comparable valueA = a.isAnalysis ? 0 : getValue(a);
    final Comparable valueB = b.isAnalysis ? 0 : getValue(b);
    return valueA.compareTo(valueB);
  }

  @override
  double get fixedWidthPx => 75.0;
}

class _ShallowSizeColumn extends ColumnData<Reference> {
  _ShallowSizeColumn() : super('Shallow', alignment: ColumnAlignment.right);

  int sizeAllVisibleLibraries(List<Reference> references) {
    var sum = 0;
    for (final ref in references) {
      if (ref.isLibrary) {
        final libraryReference = ref as LibraryReference;
        for (final actualClass in libraryReference.actualClasses) {
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
      final snapshotGraph = dataObject.controller.snapshots.last.snapshotGraph;
      return snapshotGraph.shallowSize + snapshotGraph.externalSize;
    }

    if (dataObject.isLibrary) {
      // Return number of classes.
      final libraryReference = dataObject as LibraryReference;
      var sum = 0;
      for (final actualClass in libraryReference.actualClasses) {
        sum += actualClass.instancesTotalShallowSizes;
      }
      return sum;
    } else if (dataObject.isClass) {
      final classReference = dataObject as ClassReference;
      return classReference.actualClass.instancesTotalShallowSizes;
    } else if (dataObject.isObject) {
      // Return number of instances.
      final objectReference = dataObject as ObjectReference;

      var size = objectReference.instance.origin.shallowSize;

      // If it's an external object then return the externalSize too.
      if (dataObject is ExternalObjectReference) {
        final ExternalObjectReference externalRef = dataObject;
        size += externalRef.externalSize;
      }

      return size;
    } else if (dataObject.isFiltered) {
      final sum =
          sizeAllVisibleLibraries(dataObject.controller.libraryRoot.children);
      final snapshotGraph = dataObject.controller.snapshots.last.snapshotGraph;
      return snapshotGraph.shallowSize - sum;
    } else if (dataObject.isExternals) {
      return dataObject.controller.snapshots.last.snapshotGraph.externalSize;
    } else if (dataObject.isExternal) {
      return (dataObject as ExternalReference).sumExternalSizes;
    } else if (dataObject.isAnalysis && dataObject is AnalysisReference) {
      final AnalysisReference analysisReference = dataObject;
      final size = analysisReference.sizeNote;
      return size == null ? '' : size;
    }

    return '';
  }

  @override
  String getDisplayValue(Reference dataObject) {
    final value = getValue(dataObject);

    // TODO(terry): Add percent to display too.
/*
    final total = dataObject.controller.snapshots.last.snapshotGraph.capacity;
    final percentage = (value / total) * 100;
    final displayPercentage = percentage < .050 ? '<<1%' : '${NumberFormat.compact().format(percentage)}%';
    print('$displayPercentage [${NumberFormat.compact().format(percentage)}%]');
*/
    if (dataObject.isAnalysis && value is! int) return '';

    return NumberFormat.compact().format(value);
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

  @override
  double get fixedWidthPx => 100.0;
}

class _RetainedSizeColumn extends ColumnData<Reference> {
  _RetainedSizeColumn() : super('Retained', alignment: ColumnAlignment.right);

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
      for (final actualClass in libraryReference.actualClasses)
        sum += actualClass.instancesTotalShallowSizes;
      return sum;
    } else if (dataObject.isClass) {
      final classReference = dataObject as ClassReference;
      return classReference.actualClass.instancesTotalShallowSizes;
    } else if (dataObject.isObject) {
      // Return number of instances.
      final objectReference = dataObject as ObjectReference;
      return objectReference.instance.origin.shallowSize;
    } else if (dataObject.isExternals) {
      return dataObject.controller.snapshots.last.snapshotGraph.externalSize;
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

  @override
  double get fixedWidthPx => 100.0;
}
