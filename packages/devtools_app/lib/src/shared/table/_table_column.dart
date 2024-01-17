// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'table.dart';

/// If a [ColumnData] implements this interface, it can override how that cell
/// is rendered.
abstract class ColumnRenderer<T> {
  /// Render the given [data] to a [Widget].
  ///
  /// This method can return `null` to indicate that the default rendering
  /// should be used instead.
  /// `isRowHovered` is only used when `enableHoverHandling` is `true` on the table
  /// that this column belongs to.
  Widget? build(
    BuildContext context,
    T data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  });
}

/// If a [ColumnData] implements this interface, it can override how that column
/// header is rendered.
abstract class ColumnHeaderRenderer<T> {
  /// Render the column header to a [Widget].
  ///
  /// This method can return `null` to indicate that the default rendering
  /// should be used instead.
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  );
}

class _ColumnHeader<T> extends StatelessWidget {
  const _ColumnHeader({
    Key? key,
    required this.column,
    required this.isSortColumn,
    required this.sortDirection,
    required this.onSortChanged,
    this.secondarySortColumn,
  }) : super(key: key);

  final ColumnData<T> column;

  final ColumnData<T>? secondarySortColumn;

  final bool isSortColumn;

  final SortDirection sortDirection;

  final Function(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  })? onSortChanged;

  @override
  Widget build(BuildContext context) {
    late Widget content;
    final title = Text(
      column.title,
      overflow: TextOverflow.ellipsis,
      textAlign: column.headerAlignment,
    );

    final headerContent = Row(
      mainAxisAlignment: column.mainAxisAlignment,
      children: [
        if (isSortColumn && column.supportsSorting) ...[
          Icon(
            sortDirection == SortDirection.ascending
                ? Icons.expand_less
                : Icons.expand_more,
            size: defaultIconSize,
          ),
          const SizedBox(width: densePadding),
        ],
        Expanded(
          child: column.titleTooltip != null
              ? DevToolsTooltip(
                  message: column.titleTooltip,
                  padding: const EdgeInsets.all(denseSpacing),
                  child: title,
                )
              : title,
        ),
      ],
    );

    content = column.includeHeader
        ? InkWell(
            canRequestFocus: false,
            onTap: column.supportsSorting
                ? () => _handleSortChange(
                      column,
                      secondarySortColumn: secondarySortColumn,
                    )
                : null,
            child: headerContent,
          )
        : headerContent;
    return content;
  }

  void _handleSortChange(
    ColumnData<T> columnData, {
    ColumnData<T>? secondarySortColumn,
  }) {
    SortDirection direction;
    if (isSortColumn) {
      direction = sortDirection.reverse();
    } else if (columnData.numeric) {
      direction = SortDirection.descending;
    } else {
      direction = SortDirection.ascending;
    }
    onSortChanged?.call(
      columnData,
      direction,
      secondarySortColumn: secondarySortColumn,
    );
  }
}

class _ColumnGroupHeaderRow extends StatelessWidget {
  const _ColumnGroupHeaderRow({
    required this.groups,
    required this.columnWidths,
    required this.scrollController,
    Key? key,
  }) : super(key: key);

  final List<ColumnGroup> groups;

  final List<double> columnWidths;

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      decoration: BoxDecoration(
        border: Border(
          bottom: defaultBorderSide(Theme.of(context)),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        itemCount: groups.length + groups.numSpacers,
        itemBuilder: (context, int i) {
          if (i % 2 == 1) {
            return const _ColumnGroupSpacer();
          }

          final group = groups[i ~/ 2];
          final groupRange = group.range;
          double groupWidth = 0.0;
          for (int j = groupRange.begin as int; j < groupRange.end; j++) {
            final columnWidth = columnWidths[j];
            groupWidth += columnWidth;
            if (j < groupRange.end - 1) {
              groupWidth += columnSpacing;
            }
          }
          return Container(
            alignment: Alignment.center,
            width: groupWidth,
            child: group.title,
          );
        },
      ),
    );
  }
}

class _ColumnGroupSpacer extends StatelessWidget {
  const _ColumnGroupSpacer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: (columnGroupSpacingWithPadding - columnGroupSpacing) / 2,
      ),
      child: Container(
        width: columnGroupSpacing,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              Theme.of(context).focusColor,
              Colors.black,
            ],
          ),
        ),
      ),
    );
  }
}
