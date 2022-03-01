// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/flutter_widgets/linked_scroll_controller.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/theme.dart';
import 'memory_controller.dart';
import 'memory_snapshot_models.dart';

/// First two libraries are special e.g., dart:* and package:flutter*
const _dartLibraryUriPrefix = 'dart:';
const _flutterLibraryUriPrefix = 'package:flutter';
const _collectionLibraryUri = 'package:collection';
const _intlLibraryUri = 'package:intl';
const _vectorMathLibraryUri = 'package:vector_math';

/// Name displayed in filter dialog, for wildcard groups.
const _prettyPrintDartAbbreviation = '$_dartLibraryUriPrefix*';
const _prettyPrintFlutterAbbreviation = '$_flutterLibraryUriPrefix*';

/// State of the libraries, wildcard included, filtered (shown or hidden).
/// groupBy uses this class to determine is the library should be filtered.
class FilteredLibraries {
  final List<String> _filteredLibraries = [
    _dartLibraryUriPrefix,
    _collectionLibraryUri,
    _flutterLibraryUriPrefix,
    _intlLibraryUri,
    _vectorMathLibraryUri,
  ];

  static String normalizeLibraryUri(Library library) {
    final uriParts = library.uri.split('/');
    final firstPart = uriParts.first;
    if (firstPart.startsWith(_dartLibraryUriPrefix)) {
      return _dartLibraryUriPrefix;
    } else if (firstPart.startsWith(_flutterLibraryUriPrefix)) {
      return _flutterLibraryUriPrefix;
    } else {
      return firstPart;
    }
  }

  List<String> get librariesFiltered =>
      _filteredLibraries.toList(growable: false);

  bool get isDartLibraryFiltered =>
      _filteredLibraries.contains(_dartLibraryUriPrefix);

  bool get isFlutterLibraryFiltered =>
      _filteredLibraries.contains(_flutterLibraryUriPrefix);

  void clearFilters() {
    _filteredLibraries.clear();
  }

  void addFilter(String libraryUri) {
    _filteredLibraries.add(libraryUri);
  }

  void removeFilter(String libraryUri) {
    _filteredLibraries.remove(libraryUri);
  }

  // Keys in the libraries map is a normalized library name.
  List<String> sort() => _filteredLibraries..sort();

  bool isDartLibrary(Library library) =>
      library.uri.startsWith(_dartLibraryUriPrefix);

  bool isFlutterLibrary(Library library) =>
      library.uri.startsWith(_flutterLibraryUriPrefix);

  bool isDartLibraryName(String libraryName) =>
      libraryName.startsWith(_dartLibraryUriPrefix);

  bool isFlutterLibraryName(String libraryName) =>
      libraryName.startsWith(_flutterLibraryUriPrefix);

  bool isLibraryFiltered(String libraryName) =>
      // Are dart:* libraries filtered and its a Dart library?
      (_filteredLibraries.contains(_dartLibraryUriPrefix) &&
          isDartLibraryName(libraryName)) ||
      // Are package:flutter* filtered and its a Flutter package?
      (_filteredLibraries.contains(_flutterLibraryUriPrefix) &&
          isFlutterLibraryName(libraryName)) ||
      // Is this library filtered?
      _filteredLibraries.contains(libraryName);
}

/// State of the libraries and packages (hidden or not) for the filter dialog.
class LibraryFilter {
  LibraryFilter(this.displayName, this.hide);

  /// Displayed library name.
  final String displayName;

  /// Whether classes in this library hidden (filtered).
  bool hide;
}

class SnapshotFilterDialog extends StatefulWidget {
  const SnapshotFilterDialog(this.controller);

  final MemoryController controller;

  @override
  SnapshotFilterState createState() => SnapshotFilterState();
}

class SnapshotFilterState extends State<SnapshotFilterDialog>
    with AutoDisposeMixin {
  MemoryController controller;

  LinkedScrollControllerGroup _controllers;

  ScrollController _letters;

  bool oldFilterPrivateClassesValue;

  bool oldFilterZeroInstancesValue;

  bool oldFilterLibraryNoInstancesValue;

  final oldFilteredLibraries = <String, bool>{};

  @override
  void initState() {
    super.initState();

    _controllers = LinkedScrollControllerGroup();

    _letters = _controllers.addAndGet();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (controller == widget.controller) return;

    controller = widget.controller;

    buildFilters();

    oldFilterPrivateClassesValue = controller.filterPrivateClasses.value;
    oldFilterZeroInstancesValue = controller.filterZeroInstances.value;
    oldFilterLibraryNoInstancesValue =
        controller.filterLibraryNoInstances.value;

    final oldFiltered = controller.filteredLibrariesByGroupName;
    for (var key in oldFiltered.keys) {
      oldFilteredLibraries[key] = oldFiltered[key].first.hide;
    }
  }

  void addLibrary(String libraryName, {bool hideState = false}) {
    final filteredGroup = controller.filteredLibrariesByGroupName;
    final filters = controller.libraryFilters;

    final isFiltered = filters.isLibraryFiltered(libraryName);
    String groupedName = libraryName;
    bool hide = hideState;
    if (isFiltered) {
      if (filters.isDartLibraryName(libraryName)) {
        groupedName = _prettyPrintDartAbbreviation;
      } else if (filters.isFlutterLibraryName(libraryName)) {
        groupedName = _prettyPrintFlutterAbbreviation;
      }
    }
    hide = isFiltered;

    // Used by checkboxes in dialog.
    filteredGroup[groupedName] ??= [];
    filteredGroup[groupedName].add(LibraryFilter(libraryName, hide));
  }

  void buildFilters() {
    if (controller == null) return;

    // First time filters created, populate with the default list of libraries
    // to filters
    if (controller.filteredLibrariesByGroupName.isEmpty) {
      for (final library in controller.libraryFilters.librariesFiltered) {
        addLibrary(library, hideState: true);
      }
      // If not snapshots, return no libraries to process.
      if (controller.snapshots.isEmpty) return;
    }

    // No libraries to compute until a snapshot exist.
    if (controller.snapshots.isEmpty) return;

    final libraries = controller.libraryRoot == null
        ? controller.activeSnapshot.children
        : controller.libraryRoot.children;

    libraries..sort((a, b) => a.name.compareTo(b.name));

    for (final library in libraries) {
      // Don't include external and filtered these are a composite and can't be filtered out.
      if (library.name != externalLibraryName &&
          library.name != filteredLibrariesName) {
        addLibrary(library.name);
      }
    }
  }

  /// Process wildcard groups dart:* and package:flutter*. If a wildcard group is
  /// toggled from on to off then all the dart: packages will appear if the group
  /// dart:* is toggled back on then all the dart: packages must be removed.
  void cleanupFilteredLibrariesByGroupName() {
    final filteredGroup = controller.filteredLibrariesByGroupName;
    final dartGlobal = filteredGroup[_prettyPrintDartAbbreviation].first.hide;
    final flutterGlobal =
        filteredGroup[_prettyPrintFlutterAbbreviation].first.hide;

    filteredGroup.removeWhere((groupName, libraryFilter) {
      if (dartGlobal &&
          groupName != _prettyPrintDartAbbreviation &&
          groupName.startsWith(_dartLibraryUriPrefix)) {
        return true;
      } else if (flutterGlobal &&
          groupName != _prettyPrintFlutterAbbreviation &&
          groupName.startsWith(_flutterLibraryUriPrefix)) {
        return true;
      }

      return false;
    });
  }

  Widget createLibraryListBox(BoxConstraints constraints) {
    final allLibraries =
        controller.filteredLibrariesByGroupName.keys.map((String key) {
      return CheckboxListTile(
        title: Text(key),
        dense: true,
        value: controller.filteredLibrariesByGroupName[key].first?.hide,
        onChanged: (bool value) {
          setState(() {
            for (var filter in controller.filteredLibrariesByGroupName[key]) {
              filter.hide = value;
            }
          });
        },
      );
    }).toList();

    // TODO(terry): Need to change all of this to use flex, not the below computation.
    return SizedBox(
      height: constraints.maxHeight / 4,
      child: ListView(controller: _letters, children: allLibraries),
    );
  }

  Widget applyAndCancelButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DialogApplyButton(
          onPressed: () {
            // Re-generate librariesFiltered
            controller.libraryFilters.clearFilters();
            controller.filteredLibrariesByGroupName.forEach((groupName, value) {
              if (value.first.hide) {
                var filteredName = groupName;
                if (filteredName.endsWith('*')) {
                  filteredName = filteredName.substring(
                    0,
                    filteredName.length - 1,
                  );
                }
                controller.libraryFilters.addFilter(filteredName);
              }
            });
            // Re-filter the groups.
            controller.libraryRoot = null;
            if (controller.lastSnapshot != null) {
              controller.heapGraph.computeFilteredGroups();
              controller.computeAllLibraries(
                graph: controller.lastSnapshot.snapshotGraph,
              );
            }
            cleanupFilteredLibrariesByGroupName();
            controller.updateFilter();
          },
        ),
        const SizedBox(width: defaultSpacing),
        DialogCancelButton(
          cancelAction: () {
            controller.filterPrivateClasses.value =
                oldFilterPrivateClassesValue;
            controller.filterZeroInstances.value = oldFilterZeroInstancesValue;
            controller.filterLibraryNoInstances.value =
                oldFilterLibraryNoInstancesValue;

            // Restore hide state.
            controller.filteredLibrariesByGroupName.forEach((key, values) {
              final oldHide = oldFilteredLibraries[key];
              for (var value in values) {
                value.hide = oldHide;
              }
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dialog has three main vertical sections:
    //      - three checkboxes
    //      - one list of libraries with at least 5 entries
    //      - one row of buttons Ok/Cancel
    // For very tall app keep the dialog at a reasonable height w/o too much vertical whitespace.
    // The listbox area is the area that grows to accommodate the list of known libraries.

    final constraints = BoxConstraints(
      maxWidth: defaultDialogWidth,
      maxHeight: MediaQuery.of(context).size.height,
    );

    final theme = Theme.of(context);

    return DevToolsDialog(
      title: dialogTitleText(theme, 'Memory Filter Libraries and Classes'),
      includeDivider: false,
      content: Container(
        width: defaultDialogWidth,
        child: Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...dialogSubHeader(theme, 'Snapshot Filters'),
                  Row(
                    children: [
                      NotifierCheckbox(
                        notifier: controller.filterPrivateClasses,
                      ),
                      const DevToolsTooltip(
                        message: 'Hide class names beginning with '
                            'an underscore e.g., _className',
                        child: Text('Hide Private Classes'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      NotifierCheckbox(
                        notifier: controller.filterZeroInstances,
                      ),
                      const Text('Hide Classes with No Instances'),
                    ],
                  ),
                  Row(
                    children: [
                      NotifierCheckbox(
                        notifier: controller.filterLibraryNoInstances,
                      ),
                      const Text('Hide Library with No Instances'),
                    ],
                  ),
                  const SizedBox(height: defaultSpacing),
                  ...dialogSubHeader(
                    theme,
                    'Hide Libraries or Packages '
                    '(${controller.filteredLibrariesByGroupName.length})',
                  ),
                  createLibraryListBox(constraints),
                  applyAndCancelButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
