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
  });
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isError)
          Padding(
            padding: const EdgeInsets.only(right: denseSpacing),
            child: Icon(
              Icons.error,
              color: Theme.of(context).colorScheme.error,
              size: defaultIconSize,
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
    implements ColumnRenderer<LinkData> {
  DomainColumn()
      : super(
          'Domain',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  @override
  bool get supportsSorting => true;

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
      text: dataObject.domain,
    );
  }

  // Shows result with error first.
  @override
  int compare(LinkData a, LinkData b) {
    if (a.domainError) return -1;
    if (b.domainError) return 1;
    return getValue(a).compareTo(getValue(b));
  }
}

class PathColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData> {
  PathColumn()
      : super(
          'Path',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  @override
  bool get supportsSorting => true;

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
      text: dataObject.path,
    );
  }

  // Shows result with error first.
  @override
  int compare(LinkData a, LinkData b) {
    if (a.pathError) return -1;
    if (b.pathError) return 1;
    return getValue(a).compareTo(getValue(b));
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
    implements ColumnHeaderRenderer<LinkData> {
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
              _buildPopupMenuEntry(controller, FilterOption.http),
              _buildPopupMenuEntry(controller, FilterOption.custom),
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
  String getValue(LinkData dataObject) => dataObject.scheme.join(',');
}

class OSColumn extends ColumnData<LinkData>
    implements ColumnHeaderRenderer<LinkData> {
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
              _buildPopupMenuEntry(controller, FilterOption.android),
              _buildPopupMenuEntry(controller, FilterOption.ios),
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
  String getValue(LinkData dataObject) =>
      dataObject.os.map((e) => e.description).toList().join(',');
}

class StatusColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  StatusColumn(this.controller, this.tableViewType)
      : super(
          'Status',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  DeepLinksController controller;

  TableViewType tableViewType;

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
              if (tableViewType != TableViewType.domainView)
                _buildPopupMenuEntry(
                  controller,
                  FilterOption.failedPathCheck,
                ),
              if (tableViewType != TableViewType.pathView)
                _buildPopupMenuEntry(
                  controller,
                  FilterOption.failedDomainCheck,
                ),
              _buildPopupMenuEntry(controller, FilterOption.noIssue),
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

PopupMenuEntry<FilterOption> _buildPopupMenuEntry(
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
            value: option.filters[filterOption],
            onChanged: (bool? checked) => controller.updateFilterOptions(
              option: filterOption,
              value: checked!,
            ),
          ),
        ),
        Text(filterOption.description),
      ],
    ),
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
