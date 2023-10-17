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

import 'deep_links_controller.dart';
import 'deep_links_screen.dart';

const kDeeplinkTableCellDefaultWidth = 200.0;

/// Contains all data relevant to a deep link.
class LinkData with SearchableDataMixin {
  LinkData({
    required this.domain,
    required this.path,
    required this.os,
    this.scheme = const <String>['Http://', 'Https://'],
    this.domainError = false,
    this.pathError = false,
  });

  final List<String> path;
  final List<String> domain;
  final List<String> os;
  final List<String> scheme;
  final bool domainError;
  final bool pathError;

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return (domain.join().caseInsensitiveContains(regExpSearch) == true) ||
        (path.join().caseInsensitiveContains(regExpSearch) == true);
  }

  @override
  String toString() => 'LinkData($domain $path)';

  // Used for [TableViewType.pathView].
  LinkData mergebyPath(LinkData? linkdata) {
    if (linkdata == null) return this;
    assert(path.single == linkdata.path.single);
    return LinkData(
      domain: [...domain, ...linkdata.domain],
      path: path,
      os: os,
      pathError: pathError,
    );
  }

  // Used for [TableViewType.domainView].
  LinkData mergebyDomain(LinkData? linkdata) {
    if (linkdata == null) return this;
    assert(domain.single == linkdata.domain.single);
    return LinkData(
      domain: domain,
      path: [...path, ...linkdata.path],
      os: os,
      domainError: domainError,
    );
  }
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
  String getValue(LinkData dataObject) => dataObject.domain.single;

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return _ErrorAwareText(
      isError: dataObject.domainError,
      text: dataObject.domain.single,
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
  String getValue(LinkData dataObject) => dataObject.path.first;

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return _ErrorAwareText(
      isError: dataObject.pathError,
      text: dataObject.path.first,
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
  String getValue(LinkData dataObject) => dataObject.path.length.toString();
}

class NumberOfAssociatedDomainColumn extends ColumnData<LinkData> {
  NumberOfAssociatedDomainColumn()
      : super(
          'Number of associated domain',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  @override
  String getValue(LinkData dataObject) => dataObject.domain.length.toString();
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
        PopupMenuButton<SchemeFilterOption>(
          onSelected: (option) {
            controller.updateFilterOptions(schemeOption: option);
          },
          itemBuilder: (BuildContext context) {
            return [SchemeFilterOption.http, SchemeFilterOption.custom]
                .map(
                  (value) => PopupMenuItem<SchemeFilterOption>(
                    value: value,
                    child: Row(
                      children: [
                        ValueListenableBuilder<SchemeFilterOption>(
                          valueListenable:
                              controller.schemeFilterOptionNotifier,
                          builder: (context, option, _) => Checkbox(
                            value: option == value,
                            onChanged: (bool? checked) {
                              if (checked!) {
                                controller.updateFilterOptions(
                                    schemeOption: value);
                              } else {
                                controller.updateFilterOptions(
                                  schemeOption: SchemeFilterOption.showAll,
                                );
                              }
                            },
                          ),
                        ),
                        if (value == SchemeFilterOption.http)
                          const Text('Http://, https://'),
                        if (value == SchemeFilterOption.custom)
                          const Text('Custom scheme'),
                      ],
                    ),
                  ),
                )
                .toList();
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
        PopupMenuButton<OsFilterOption>(
          onSelected: (option) {
            controller.updateFilterOptions(osOption: option);
          },
          itemBuilder: (BuildContext context) {
            return OsFilterOption.values
                .map(
                  (value) => PopupMenuItem<OsFilterOption>(
                    value: value,
                    child: Row(
                      children: [
                        ValueListenableBuilder<OsFilterOption>(
                          valueListenable: controller.osFilterOptionNotifier,
                          builder: (context, option, _) => Checkbox(
                            value: option == value,
                            onChanged: (bool? checked) {
                              if (checked!) {
                                controller.updateFilterOptions(osOption: value);
                              } else {
                                controller.updateFilterOptions(
                                  osOption: OsFilterOption.showAll,
                                );
                              }
                            },
                          ),
                        ),
                        if (value == OsFilterOption.showAll)
                          const Text('Android, iOS'),
                        if (value == OsFilterOption.android)
                          const Text('Android'),
                        if (value == OsFilterOption.ios) const Text('iOS'),
                      ],
                    ),
                  ),
                )
                .toList();
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
  String getValue(LinkData dataObject) => dataObject.os.join(',');
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
        PopupMenuButton<StatusFilterOption>(
          onSelected: (option) {
            controller.updateFilterOptions(statusOption: option);
          },
          itemBuilder: (BuildContext context) {
            var statusFilterOptions = <StatusFilterOption>[];
            switch (tableViewType) {
              case TableViewType.singleUrlView:
                statusFilterOptions = [
                  StatusFilterOption.failedAllCheck,
                  StatusFilterOption.failedDomainCheck,
                  StatusFilterOption.failedPathCheck,
                  StatusFilterOption.noIssue,
                ];
                break;
              case TableViewType.domainView:
                statusFilterOptions = [
                  StatusFilterOption.failedDomainCheck,
                  StatusFilterOption.noIssue,
                ];
                break;
              case TableViewType.pathView:
                statusFilterOptions = [
                  StatusFilterOption.failedPathCheck,
                  StatusFilterOption.noIssue,
                ];
                break;
            }
            return statusFilterOptions
                .map(
                  (value) => PopupMenuItem<StatusFilterOption>(
                    value: value,
                    child: Row(
                      children: [
                        ValueListenableBuilder<StatusFilterOption>(
                          valueListenable:
                              controller.statusFilterOptionNotifier,
                          builder: (context, option, _) => Checkbox(
                            value: option == value,
                            onChanged: (bool? checked) {
                              if (checked!) {
                                controller.updateFilterOptions(
                                  statusOption: value,
                                );
                              } else {
                                controller.updateFilterOptions(
                                  statusOption: StatusFilterOption.showAll,
                                );
                              }
                            },
                          ),
                        ),
                        if (value == StatusFilterOption.failedAllCheck)
                          const Text('Failed domain and path checks'),
                        if (value == StatusFilterOption.failedDomainCheck)
                          const Text('Failed domain checks'),
                        if (value == StatusFilterOption.failedPathCheck)
                          const Text('Failed path checks'),
                        if (value == StatusFilterOption.noIssue)
                          const Text('No issues found'),
                      ],
                    ),
                  ),
                )
                .toList();
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
