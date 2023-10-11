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

  final String path;
  final String domain;
  final List<String> os;
  final List<String> scheme;
  final bool domainError;
  final bool pathError;

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
}

class SchemeColumn extends ColumnData<LinkData> {
  SchemeColumn()
      : super(
          'Scheme',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  @override
  String getValue(LinkData dataObject) => dataObject.scheme.join(',');
}

class OSColumn extends ColumnData<LinkData> {
  OSColumn()
      : super(
          'OS',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

  @override
  String getValue(LinkData dataObject) => dataObject.os.join(',');
}

class StatusColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData> {
  StatusColumn()
      : super(
          'Status',
          fixedWidthPx: scaleByFontFactor(kDeeplinkTableCellDefaultWidth),
        );

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

// TODO: implement this column.
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
