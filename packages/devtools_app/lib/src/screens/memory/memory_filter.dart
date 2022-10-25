// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../primitives/auto_dispose_mixin.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/theme.dart';
import 'memory_controller.dart';
import 'memory_snapshot_models.dart';
import 'primitives/filter_config.dart';

/// Name displayed in filter dialog, for wildcard groups.
const _prettyPrintDartAbbreviation = '$dartLibraryUriPrefix*';
const _prettyPrintFlutterAbbreviation = '$flutterLibraryUriPrefix*';

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

    final parameters = widget.controller.filterConfig;
    oldFilterPrivateClassesValue = parameters.filterPrivateClasses.value;
    oldFilterZeroInstancesValue = parameters.filterZeroInstances.value;
    oldFilterLibraryNoInstancesValue =
        parameters.filterLibraryNoInstances.value;
  }

  void addLibrary(String libraryName, {bool hideState = false}) {
    final filteredGroup = <String, List<LibraryFilter>>{};
    final filters = widget.controller.filterConfig.libraryFilters;

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

    for (final library
        in widget.controller.filterConfig.libraryFilters.librariesFiltered) {
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
        assert(library.name != null);
        addLibrary(library.name!);
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
            widget.controller.filterConfig.libraryFilters.clearFilters();
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
            widget.controller.filterConfig.filterPrivateClasses.value =
                oldFilterPrivateClassesValue;
            widget.controller.filterConfig.filterZeroInstances.value =
                oldFilterZeroInstancesValue;
            widget.controller.filterConfig.filterLibraryNoInstances.value =
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
      title: DialogTitleText(
          theme: theme, text: 'Memory Filter Libraries and Classes'),
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
                        notifier:
                            widget.controller.filterConfig.filterPrivateClasses,
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
                        notifier:
                            widget.controller.filterConfig.filterZeroInstances,
                      ),
                      const Text('Hide Classes with No Instances'),
                    ],
                  ),
                  Row(
                    children: [
                      NotifierCheckbox(
                        notifier: widget
                            .controller.filterConfig.filterLibraryNoInstances,
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
