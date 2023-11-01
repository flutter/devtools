// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/ui/colors.dart';
import '../../shared/ui/search.dart';
import 'deep_link_list_view.dart';
import 'deep_links_controller.dart';

const kDeeplinkTableCellDefaultWidth = 200.0;

enum PlatformOS {
  android('Android'),
  ios('iOS');

  const PlatformOS(this.description);
  final String description;
}

/// Contains all data relevant to a deep link.
class LinkData with SearchableDataMixin {
  LinkData({
    required this.domain,
    required this.path,
    required this.os,
    this.scheme = const <String>['http://', 'https://'],
    this.domainError = false,
    this.pathError = false,
    this.associatedPath = const <String>[],
    this.associatedDomains = const <String>[],
  });

  final String path;
  final String domain;
  final List<PlatformOS> os;
  final List<String> scheme;
  final bool domainError;
  final bool pathError;

  final List<String> associatedPath;
  final List<String> associatedDomains;

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return domain.caseInsensitiveContains(regExpSearch) ||
        path.caseInsensitiveContains(regExpSearch);
  }

  @override
  String toString() => 'LinkData($domain $path)';
}

class _ErrorAwareText extends StatelessWidget {
  const _ErrorAwareText({
    required this.text,
    required this.isError,
    required this.controller,
    required this.link,
  });
  final String text;
  final bool isError;
  final DeepLinksController controller;
  final LinkData link;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isError)
          DevToolsTooltip(
            padding: const EdgeInsets.only(
              top: defaultSpacing,
              left: defaultSpacing,
              right: defaultSpacing,
            ),
            preferBelow: true,
            richMessage: WidgetSpan(
              child: SizedBox(
                width: 344,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'This m.shopping.com domain has 1 issue to fix. Fixing this domain will fix ${link.associatedPath.length} associated deep links.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tooltipTextColor,
                        fontSize: defaultFontSize,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        controller.updateDisplayOptions(showSplitScreen: true);
                        controller.selectedLink.value = link;
                      },
                      child: Text(
                        'Fix this domain',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary,
                          fontSize: defaultFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: denseSpacing),
              child: Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
                size: defaultIconSize,
              ),
            ),
          ),
        const SizedBox(width: denseSpacing),
        Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class DomainColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  DomainColumn(this.controller)
      : super(
          'Domain',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  DeepLinksController controller;

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Domain'),
        PopupMenuButton<SortingOption>(
          itemBuilder: (BuildContext context) {
            return [
              _buildPopupMenuSortingEntry(
                controller,
                SortingOption.errorOnTop,
                isPath: false,
              ),
              _buildPopupMenuSortingEntry(
                controller,
                SortingOption.aToZ,
                isPath: false,
              ),
              _buildPopupMenuSortingEntry(
                controller,
                SortingOption.zToA,
                isPath: false,
              ),
            ];
          },
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  String getValue(LinkData dataObject) => dataObject.domain;

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return _ErrorAwareText(
      isError: dataObject.domainError,
      controller: controller,
      text: dataObject.domain,
      link: dataObject,
    );
  }

  // Default to show result with error first.
  @override
  int compare(LinkData a, LinkData b) {
    final SortingOption? sortingOption =
        controller.displayOptions.domainSortingOption;
    if (sortingOption == null) return 0;

    switch (sortingOption) {
      case SortingOption.errorOnTop:
        if (a.domainError) return 1;
        if (b.domainError) return -1;
        return 0;
      case SortingOption.aToZ:
        return a.domain.compareTo(b.domain);
      case SortingOption.zToA:
        return b.domain.compareTo(a.domain);
    }
  }
}

class PathColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  PathColumn(this.controller)
      : super(
          'Path',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  DeepLinksController controller;

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Path'),
        PopupMenuButton<SortingOption>(
          itemBuilder: (BuildContext context) {
            return [
              _buildPopupMenuSortingEntry(
                controller,
                SortingOption.errorOnTop,
                isPath: true,
              ),
              _buildPopupMenuSortingEntry(
                controller,
                SortingOption.aToZ,
                isPath: true,
              ),
              _buildPopupMenuSortingEntry(
                controller,
                SortingOption.zToA,
                isPath: true,
              ),
            ];
          },
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  String getValue(LinkData dataObject) => dataObject.path;

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return _ErrorAwareText(
      isError: dataObject.pathError,
      controller: controller,
      text: dataObject.path,
      link: dataObject,
    );
  }

  // Default to show result with error first.
  @override
  int compare(LinkData a, LinkData b) {
    final SortingOption? sortingOption =
        controller.displayOptions.pathSortingOption;

    if (sortingOption == null) return 0;

    switch (sortingOption) {
      case SortingOption.errorOnTop:
        if (a.pathError) return -1;
        if (b.pathError) return 1;
        return 0;
      case SortingOption.aToZ:
        return a.path.compareTo(b.path);
      case SortingOption.zToA:
        return b.path.compareTo(a.path);
    }
  }
}

class NumberOfAssociatedPathColumn extends ColumnData<LinkData> {
  NumberOfAssociatedPathColumn()
      : super(
          'Number of associated path',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  @override
  String getValue(LinkData dataObject) =>
      dataObject.associatedPath.length.toString();
}

class NumberOfAssociatedDomainColumn extends ColumnData<LinkData> {
  NumberOfAssociatedDomainColumn()
      : super(
          'Number of associated domain',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  @override
  String getValue(LinkData dataObject) =>
      dataObject.associatedDomains.length.toString();
}

class SchemeColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  SchemeColumn(this.controller)
      : super(
          'Scheme',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  DeepLinksController controller;

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Scheme'),
        PopupMenuButton<FilterOption>(
          itemBuilder: (BuildContext context) {
            return [
              _buildPopupMenuFilterEntry(controller, FilterOption.http),
              _buildPopupMenuFilterEntry(controller, FilterOption.custom),
            ];
          },
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return Text(getValue(dataObject));
  }

  @override
  String getValue(LinkData dataObject) => dataObject.scheme.join(', ');
}

class OSColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  OSColumn(this.controller)
      : super(
          'OS',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  DeepLinksController controller;

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('OS'),
        PopupMenuButton<FilterOption>(
          itemBuilder: (BuildContext context) {
            return [
              _buildPopupMenuFilterEntry(controller, FilterOption.android),
              _buildPopupMenuFilterEntry(controller, FilterOption.ios),
            ];
          },
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return Text(getValue(dataObject));
  }

  @override
  String getValue(LinkData dataObject) =>
      dataObject.os.map((e) => e.description).toList().join(', ');
}

class StatusColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  StatusColumn(this.controller, this.viewType)
      : super(
          'Status',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  DeepLinksController controller;

  TableViewType viewType;

  @override
  String getValue(LinkData dataObject) {
    if (dataObject.domainError) {
      return 'Failed domain checks';
    } else if (dataObject.pathError) {
      return 'Failed path checks';
    } else {
      return 'No issues found';
    }
  }

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Status'),
        PopupMenuButton<FilterOption>(
          itemBuilder: (BuildContext context) {
            return [
              if (viewType != TableViewType.domainView)
                _buildPopupMenuFilterEntry(
                  controller,
                  FilterOption.failedPathCheck,
                ),
              if (viewType != TableViewType.pathView)
                _buildPopupMenuFilterEntry(
                  controller,
                  FilterOption.failedDomainCheck,
                ),
              _buildPopupMenuFilterEntry(controller, FilterOption.noIssue),
            ];
          },
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    if (dataObject.domainError || dataObject.pathError) {
      return Text(
        getValue(dataObject),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    } else {
      return Text(
        'No issues found',
        style: TextStyle(color: Theme.of(context).colorScheme.green),
        overflow: TextOverflow.ellipsis,
      );
    }
  }
}

// TODO: Implement this column.
class NavigationColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData> {
  NavigationColumn()
      : super(
          '',
          fixedWidthPx: scaleByFontFactor(40),
        );

  @override
  String getValue(LinkData dataObject) => '';

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return const Icon(Icons.arrow_forward);
  }
}

PopupMenuEntry<FilterOption> _buildPopupMenuFilterEntry(
  DeepLinksController controller,
  FilterOption filterOption,
) {
  return PopupMenuItem<FilterOption>(
    value: filterOption,
    child: Row(
      children: [
        ValueListenableBuilder<DisplayOptions>(
          valueListenable: controller.displayOptionsNotifier,
          builder: (context, option, _) => Checkbox(
            value: option.filters.contains(filterOption),
            onChanged: (bool? checked) => controller.updateDisplayOptions(
              removedFilter: checked! ? null : filterOption,
              addedFilter: checked ? filterOption : null,
            ),
          ),
        ),
        Text(filterOption.description),
      ],
    ),
  );
}

PopupMenuEntry<SortingOption> _buildPopupMenuSortingEntry(
  DeepLinksController controller,
  SortingOption sortingOption, {
  required bool isPath,
}) {
  return PopupMenuItem<SortingOption>(
    onTap: () {
      controller.updateDisplayOptions(
        pathSortingOption: isPath ? sortingOption : null,
        domainSortingOption: isPath ? null : sortingOption,
      );
    },
    value: sortingOption,
    child: Text(sortingOption.description),
  );
}

class FlutterProject {
  FlutterProject({
    required this.path,
    required this.androidVariants,
  });
  final String path;
  final List<String> androidVariants;
}
