// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../common_widgets.dart';
import '../table.dart';
import '../theme.dart';

/// A convenience widget used to create non-scrollable information cards.
///
/// `title` is displayed as the header of the card and is required.
///
/// `rowKeyValues` takes a list of key-value pairs that are to be displayed as
/// individual rows. These rows will have an alternating background color.
///
/// `table` is a widget (typically a table) that is to be displayed after the
/// rows specified for `rowKeyValues`.
class VMInfoCard extends StatelessWidget {
  const VMInfoCard({
    @required this.title,
    this.rowKeyValues,
    this.table,
  });

  final String title;
  final List<MapEntry> rowKeyValues;
  final Widget table;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: VMInfoList(
        title: title,
        rowKeyValues: rowKeyValues,
        table: table,
      ),
    );
  }
}

class VMInfoList extends StatelessWidget {
  const VMInfoList({
    @required this.title,
    this.rowKeyValues,
    this.table,
  });

  final String title;
  final List<MapEntry> rowKeyValues;
  final Widget table;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        areaPaneHeader(
          context,
          title: title,
          needsTopBorder: false,
        ),
        if (rowKeyValues != null)
          ..._prettyRows(
            context,
            [
              for (final row in rowKeyValues)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SelectableText(
                      '${row.key.toString()}:',
                      style: fixedFontStyle(context),
                    ),
                    const SizedBox(width: denseSpacing),
                    Flexible(
                      child: SelectableText(
                        row?.value?.toString() ?? '--',
                        style: fixedFontStyle(context),
                      ),
                    ),
                  ],
                )
            ],
          ),
        if (table != null) table,
      ],
    );
  }

  List<Widget> _prettyRows(BuildContext context, List<Row> rows) {
    return [
      for (int i = 0; i < rows.length; ++i)
        _buildAlternatingRow(context, i, rows[i]),
    ];
  }

  Widget _buildAlternatingRow(BuildContext context, int index, Widget row) {
    return Container(
      color: alternatingColorForIndexWithContext(index, context),
      height: defaultRowHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: defaultSpacing,
      ),
      child: row,
    );
  }
}
