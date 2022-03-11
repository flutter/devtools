// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/auto_dispose_mixin.dart';
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
    final uriParts = library.uri!.split('/');
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
      library.uri!.startsWith(_dartLibraryUriPrefix);

  bool isFlutterLibrary(Library library) =>
      library.uri!.startsWith(_flutterLibraryUriPrefix);

  bool isDartLibraryName(String libraryName) =>
      libraryName.startsWith(_dartLibraryUriPrefix);

  bool isFlutterLibraryName(String libraryName) =>
      libraryName.startsWith(_flutterLibraryUriPrefix);

  bool isLibraryFiltered(String? libraryName) =>
      // Are dart:* libraries filtered and its a Dart library?
      (_filteredLibraries.contains(_dartLibraryUriPrefix) &&
          isDartLibraryName(libraryName!)) ||
      // Are package:flutter* filtered and its a Flutter package?
      (_filteredLibraries.contains(_flutterLibraryUriPrefix) &&
          isFlutterLibraryName(libraryName!)) ||
      // Is this library filtered?
      _filteredLibraries.contains(libraryName);
}

/// State of the libraries and packages (hidden or not) for the filter dialog.
class LibraryFilter {
  LibraryFilter(this.displayName, this.hide);

  /// Displayed library name.
  final String displayName;

  /// Whether classes in this library hidden (filtered).
  bool hide = false;
}

class SnapshotFilterDialog extends StatefulWidget {
  const SnapshotFilterDialog(this.controller);

  final MemoryController controller;

  @override
  SnapshotFilterState createState() => SnapshotFilterState();
}

class SnapshotFilterState extends State<SnapshotFilterDialog>
    with AutoDisposeMixin {
  bool _intitialized = false;

  late final bool oldFilterPrivateClassesValue;

  late final bool oldFilterZeroInstancesValue;

  late final bool oldFilterLibraryNoInstancesValue;

  final oldFilteredLibraries = <String, bool>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_intitialized) return;
    _intitialized = true;

    buildFilters();

    oldFilterPrivateClassesValue = widget.controller.filterPrivateClasses.value;
    oldFilterZeroInstancesValue = widget.controller.filterZeroInstances.value;
    oldFilterLibraryNoInstancesValue =
        widget.controller.filterLibraryNoInstances.value;
  }

  void addLibrary(String libraryName, {bool hideState = false}) {
    final Map<String, List<LibraryFilter>> filteredGroup = {};
    final filters = widget.controller.libraryFilters;

    final isFiltered = filters.isLibraryFiltered(libraryName);
    var groupedName = libraryName;
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
    filteredGroup[groupedName]!.add(LibraryFilter(libraryName, hide));
  }

  void buildFilters() {
    // First time filters created, populate with the default list of libraries
    // to filters

    for (final library in widget.controller.libraryFilters.librariesFiltered) {
      addLibrary(library, hideState: true);
    }
    // If not snapshots, return no libraries to process.
    if (widget.controller.snapshots.isEmpty) return;

    // No libraries to compute until a snapshot exist.
    if (widget.controller.snapshots.isEmpty) return;

    final List<Reference> libraries = widget.controller.libraryRoot == null
        ? widget.controller.activeSnapshot.children
        : widget.controller.libraryRoot!.children;

    libraries..sort((a, b) => a.name!.compareTo(b.name!));

    for (final library in libraries) {
      // Don't include external and filtered these are a composite and can't be filtered out.
      if (library.name != externalLibraryName &&
          library.name != filteredLibrariesName) {
        addLibrary(library.name);
      }
    }
  }

  Widget applyAndCancelButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DialogApplyButton(
          onPressed: () {
            // Re-generate librariesFiltered
            widget.controller.libraryFilters.clearFilters();
            // Re-filter the groups.
            widget.controller.libraryRoot = null;
            if (widget.controller.lastSnapshot != null) {
              widget.controller.heapGraph!.computeFilteredGroups();
              widget.controller.computeAllLibraries(
                graph: widget.controller.lastSnapshot!.snapshotGraph,
              );
            }

            widget.controller.updateFilter();
          },
        ),
        const SizedBox(width: defaultSpacing),
        DialogCancelButton(
          cancelAction: () {
            widget.controller.filterPrivateClasses.value =
                oldFilterPrivateClassesValue;
            widget.controller.filterZeroInstances.value =
                oldFilterZeroInstancesValue;
            widget.controller.filterLibraryNoInstances.value =
                oldFilterLibraryNoInstancesValue;
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
                        notifier: widget.controller.filterPrivateClasses,
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
                        notifier: widget.controller.filterZeroInstances,
                      ),
                      const Text('Hide Classes with No Instances'),
                    ],
                  ),
                  Row(
                    children: [
                      NotifierCheckbox(
                        notifier: widget.controller.filterLibraryNoInstances,
                      ),
                      const Text('Hide Library with No Instances'),
                    ],
                  ),
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
