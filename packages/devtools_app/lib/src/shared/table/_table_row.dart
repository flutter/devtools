// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'table.dart';

enum _TableRowType {
  data,
  columnHeader,
  columnGroupHeader,
  filler,
}

enum _TableRowPartDisplayType {
  column,
  columnSpacer,
  columnGroupSpacer,
}

/// Presents a [node] as a row in a table.
///
/// When the given [node] is null, this widget will instead present
/// column headings.
@visibleForTesting
class TableRow<T> extends StatefulWidget {
  /// Constructs a [TableRow] that presents the column values for
  /// [node].
  const TableRow({
    Key? key,
    required this.linkedScrollControllerGroup,
    required this.node,
    required this.columns,
    required this.columnWidths,
    required this.onPressed,
    this.columnGroups,
    this.backgroundColor,
    this.expandableColumn,
    this.isExpanded = false,
    this.isExpandable = false,
    this.isSelected = false,
    this.isShown = true,
    this.enableHoverHandling = false,
    this.displayTreeGuidelines = false,
    this.searchMatchesNotifier,
    this.activeSearchMatchNotifier,
  })  : sortColumn = null,
        sortDirection = null,
        secondarySortColumn = null,
        onSortChanged = null,
        _rowType = _TableRowType.data,
        tall = false,
        super(key: key);

  /// Constructs a [TableRow] that is empty.
  const TableRow.filler({
    Key? key,
    required this.linkedScrollControllerGroup,
    required this.columns,
    required this.columnWidths,
    this.columnGroups,
    this.backgroundColor,
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        isSelected = false,
        onPressed = null,
        expandableColumn = null,
        isShown = true,
        sortColumn = null,
        sortDirection = null,
        secondarySortColumn = null,
        onSortChanged = null,
        searchMatchesNotifier = null,
        activeSearchMatchNotifier = null,
        tall = false,
        enableHoverHandling = false,
        displayTreeGuidelines = false,
        _rowType = _TableRowType.filler,
        super(key: key);

  /// Constructs a [TableRow] that presents the column titles instead
  /// of any [node].
  const TableRow.tableColumnHeader({
    Key? key,
    required this.linkedScrollControllerGroup,
    required this.columns,
    required this.columnWidths,
    required this.columnGroups,
    required this.sortColumn,
    required this.sortDirection,
    required this.onSortChanged,
    this.secondarySortColumn,
    this.onPressed,
    this.tall = false,
    this.backgroundColor,
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        isSelected = false,
        expandableColumn = null,
        isShown = true,
        searchMatchesNotifier = null,
        activeSearchMatchNotifier = null,
        displayTreeGuidelines = false,
        enableHoverHandling = false,
        _rowType = _TableRowType.columnHeader,
        super(key: key);

  /// Constructs a [TableRow] that presents column group titles instead of any
  /// [node].
  const TableRow.tableColumnGroupHeader({
    Key? key,
    required this.linkedScrollControllerGroup,
    required this.columnGroups,
    required this.columnWidths,
    required this.sortColumn,
    required this.sortDirection,
    required this.onSortChanged,
    this.secondarySortColumn,
    this.onPressed,
    this.tall = false,
    this.backgroundColor,
  })  : node = null,
        isExpanded = false,
        isExpandable = false,
        isSelected = false,
        expandableColumn = null,
        columns = const [],
        isShown = true,
        searchMatchesNotifier = null,
        activeSearchMatchNotifier = null,
        displayTreeGuidelines = false,
        enableHoverHandling = false,
        _rowType = _TableRowType.columnGroupHeader,
        super(key: key);

  final LinkedScrollControllerGroup linkedScrollControllerGroup;

  final T? node;

  final List<ColumnData<T>> columns;

  final List<ColumnGroup>? columnGroups;

  final ItemSelectedCallback<T>? onPressed;

  final List<double> columnWidths;

  final bool isSelected;

  final _TableRowType _rowType;

  final bool tall;

  final bool enableHoverHandling;

  /// Which column, if any, should show expansion affordances
  /// and nested rows.
  final ColumnData<T>? expandableColumn;

  /// Whether or not this row is expanded.
  ///
  /// This dictates the orientation of the expansion arrow
  /// that is drawn in the [expandableColumn].
  ///
  /// Only meaningful if [isExpanded] is true.
  final bool isExpanded;

  /// Whether or not this row can be expanded.
  ///
  /// This dictates whether an expansion arrow is
  /// drawn in the [expandableColumn].
  final bool isExpandable;

  /// Whether or not this row is shown.
  ///
  /// When the value is toggled, this row will appear or disappear.
  final bool isShown;

  /// The background color of the row.
  ///
  /// If null, defaults to `Theme.of(context).canvasColor`.
  final Color? backgroundColor;

  final ColumnData<T>? sortColumn;

  final SortDirection? sortDirection;

  final ColumnData<T>? secondarySortColumn;

  final Function(
    ColumnData<T> column,
    SortDirection direction, {
    ColumnData<T>? secondarySortColumn,
  })? onSortChanged;

  final ValueListenable<List<T>>? searchMatchesNotifier;

  final ValueListenable<T?>? activeSearchMatchNotifier;

  final bool displayTreeGuidelines;

  @override
  State<TableRow<T>> createState() => _TableRowState<T>();
}

class _TableRowState<T> extends State<TableRow<T>>
    with
        TickerProviderStateMixin,
        CollapsibleAnimationMixin,
        AutoDisposeMixin,
        SearchableMixin {
  Key? contentKey;

  late ScrollController scrollController;

  bool isSearchMatch = false;

  bool isActiveSearchMatch = false;

  bool isHovering = false;

  @override
  void initState() {
    super.initState();
    contentKey = ValueKey(this);
    scrollController = widget.linkedScrollControllerGroup.addAndGet();
    _initSearchListeners();
  }

  @override
  void didUpdateWidget(TableRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    setExpanded(widget.isExpanded);
    if (oldWidget.linkedScrollControllerGroup !=
        widget.linkedScrollControllerGroup) {
      scrollController.dispose();
      scrollController = widget.linkedScrollControllerGroup.addAndGet();
    }

    cancelListeners();
    _initSearchListeners();
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final widgetOnPressed = widget.onPressed;

    Function()? onPressed;
    if (node != null && widgetOnPressed != null) {
      onPressed = () => widgetOnPressed(node);
    }

    final row = tableRowFor(
      context,
      onPressed: onPressed,
    );

    final box = SizedBox(
      height: widget._rowType == _TableRowType.data
          ? defaultRowHeight
          : defaultHeaderHeight +
              (widget.tall ? scaleByFontFactor(densePadding) : 0.0),
      child: Material(
        color: _searchAwareBackgroundColor(),
        child: onPressed != null
            ? InkWell(
                canRequestFocus: false,
                key: contentKey,
                onTap: onPressed,
                child: row,
              )
            : row,
      ),
    );
    return box;
  }

  void _initSearchListeners() {
    if (widget.searchMatchesNotifier != null) {
      searchMatches = widget.searchMatchesNotifier!.value;
      isSearchMatch = searchMatches.contains(widget.node);
      addAutoDisposeListener(widget.searchMatchesNotifier, () {
        final isPreviousMatch = searchMatches.contains(widget.node);
        searchMatches = widget.searchMatchesNotifier!.value;
        final isNewMatch = searchMatches.contains(widget.node);

        // We only want to rebuild the row if it the match status has changed.
        if (isPreviousMatch != isNewMatch) {
          setState(() {
            isSearchMatch = isNewMatch;
          });
        }
      });
    }

    if (widget.activeSearchMatchNotifier != null) {
      activeSearchMatch = widget.activeSearchMatchNotifier!.value;
      isActiveSearchMatch = activeSearchMatch == widget.node;
      addAutoDisposeListener(widget.activeSearchMatchNotifier, () {
        final isPreviousActiveSearchMatch = activeSearchMatch == widget.node;
        activeSearchMatch = widget.activeSearchMatchNotifier!.value;
        final isNewActiveSearchMatch = activeSearchMatch == widget.node;

        // We only want to rebuild the row if it the match status has changed.
        if (isPreviousActiveSearchMatch != isNewActiveSearchMatch) {
          setState(() {
            isActiveSearchMatch = isNewActiveSearchMatch;
          });
        }
      });
    }
  }

  Color _searchAwareBackgroundColor() {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = widget.backgroundColor ?? colorScheme.surface;
    if (widget.isSelected) {
      return colorScheme.selectedRowBackgroundColor;
    }
    final searchAwareBackgroundColor = isSearchMatch
        ? Color.alphaBlend(
            isActiveSearchMatch
                ? activeSearchMatchColorOpaque
                : searchMatchColorOpaque,
            backgroundColor,
          )
        : backgroundColor;
    return searchAwareBackgroundColor;
  }

  Alignment _alignmentFor(ColumnData<T> column) {
    switch (column.alignment) {
      case ColumnAlignment.center:
        return Alignment.center;
      case ColumnAlignment.right:
        return Alignment.centerRight;
      case ColumnAlignment.left:
      default:
        return Alignment.centerLeft;
    }
  }

  /// Presents the content of this row.
  Widget tableRowFor(BuildContext context, {VoidCallback? onPressed}) {
    Widget columnFor(ColumnData<T> column, double columnWidth) {
      Widget? content;
      final theme = Theme.of(context);
      final node = widget.node;
      if (widget._rowType == _TableRowType.filler) {
        content = const SizedBox.shrink();
      } else if (widget._rowType == _TableRowType.columnHeader) {
        Widget defaultHeaderRenderer() => _ColumnHeader(
              column: column,
              isSortColumn: column == widget.sortColumn,
              secondarySortColumn: widget.secondarySortColumn,
              sortDirection: widget.sortDirection!,
              onSortChanged: widget.onSortChanged,
            );

        // ignore: avoid-unrelated-type-assertions, false positive.
        if (column is ColumnHeaderRenderer) {
          content = (column as ColumnHeaderRenderer)
              .buildHeader(context, defaultHeaderRenderer);
        }
        // If ColumnHeaderRenderer.build returns null, fall back to the default
        // rendering.
        content ??= defaultHeaderRenderer();
      } else if (node != null) {
        // TODO(kenz): clean up and pull all this code into _ColumnDataRow
        // widget class.
        final padding = column.getNodeIndentPx(node);
        assert(padding >= 0);
        // ignore: avoid-unrelated-type-assertions, false positive.
        if (column is ColumnRenderer) {
          content = (column as ColumnRenderer).build(
            context,
            node,
            isRowSelected: widget.isSelected,
            isRowHovered: isHovering,
            onPressed: onPressed,
          );
        }
        // If ColumnRenderer.build returns null, fall back to the default
        // rendering.
        content ??= Text.rich(
          TextSpan(
            text: column.getDisplayValue(node),
            children: [
              if (column.getCaption(node) != null)
                TextSpan(
                  text: ' ${column.getCaption(node)}',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
            style: column.contentTextStyle(
              context,
              node,
              isSelected: widget.isSelected,
            ),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: column.contentTextAlignment,
        );

        final tooltip = column.getTooltip(node);
        final richTooltip = column.getRichTooltip(node, context);
        if (tooltip.isNotEmpty || richTooltip != null) {
          content = DevToolsTooltip(
            message: richTooltip == null ? tooltip : null,
            richMessage: richTooltip,
            waitDuration: tooltipWaitLong,
            child: content,
          );
        }

        if (column == widget.expandableColumn) {
          final expandIndicator = widget.isExpandable
              ? ValueListenableBuilder(
                  valueListenable: expandController,
                  builder: (context, _, __) {
                    return RotationTransition(
                      turns: expandArrowAnimation,
                      child: Icon(
                        Icons.expand_more,
                        color: theme.colorScheme.onSurface,
                        size: defaultIconSize,
                      ),
                    );
                  },
                )
              : SizedBox(width: defaultIconSize, height: defaultIconSize);
          content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              expandIndicator,
              Expanded(child: content),
            ],
          );
        }
        content = Padding(
          padding: EdgeInsets.only(left: padding),
          child: ClipRect(
            child: content,
          ),
        );
      } else {
        throw Exception(
          'Expected a non-null node for this table column, but node == null.',
        );
      }

      content = SizedBox(
        width: columnWidth,
        child: Align(
          alignment: _alignmentFor(column),
          child: content,
        ),
      );
      if (widget.displayTreeGuidelines &&
          node != null &&
          node is TreeNode &&
          column is TreeColumnData) {
        content = CustomPaint(
          painter: _RowGuidelinePainter(
            node.level,
            theme.colorScheme,
          ),
          child: content,
        );
      }
      return DefaultTextStyle(
        style: theme.regularTextStyle,
        child: content,
      );
    }

    if (widget._rowType == _TableRowType.columnGroupHeader) {
      final groups = widget.columnGroups!;
      return _ColumnGroupHeaderRow(
        groups: groups,
        columnWidths: widget.columnWidths,
        scrollController: scrollController,
      );
    }

    final rowDisplayParts = <_TableRowPartDisplayType>[];
    final groups = widget.columnGroups;
    if (groups != null && groups.isNotEmpty) {
      for (int i = 0; i < groups.length; i++) {
        final groupParts = List.generate(
          groups[i].range.size as int,
          (index) => _TableRowPartDisplayType.column,
        ).joinWith(_TableRowPartDisplayType.columnSpacer);
        rowDisplayParts.addAll(groupParts);
        if (i < groups.length - 1) {
          rowDisplayParts.add(_TableRowPartDisplayType.columnGroupSpacer);
        }
      }
    } else {
      final parts = List.generate(
        widget.columns.length,
        (_) => _TableRowPartDisplayType.column,
      ).joinWith(_TableRowPartDisplayType.columnSpacer);
      rowDisplayParts.addAll(parts);
    }

    // Maps the indices from [rowDisplayParts] to the corresponding index of
    // each column in [widget.columns].
    final columnIndexMap = <int, int>{};
    // Add scope to guarantee [columnIndexTracker] is not used outside of this
    // block.
    {
      var columnIndexTracker = 0;
      for (int i = 0; i < rowDisplayParts.length; i++) {
        final type = rowDisplayParts[i];
        if (type == _TableRowPartDisplayType.column) {
          columnIndexMap[i] = columnIndexTracker;
          columnIndexTracker++;
        }
      }
    }

    Widget rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        itemCount: widget.columns.length + widget.columns.numSpacers,
        itemBuilder: (context, int i) {
          final displayTypeForIndex = rowDisplayParts[i];
          switch (displayTypeForIndex) {
            case _TableRowPartDisplayType.column:
              final index = columnIndexMap[i]!;
              return columnFor(
                widget.columns[index],
                widget.columnWidths[index],
              );
            case _TableRowPartDisplayType.columnSpacer:
              return const SizedBox(
                width: columnSpacing,
                child: VerticalDivider(width: columnSpacing),
              );
            case _TableRowPartDisplayType.columnGroupSpacer:
              return const _ColumnGroupSpacer();
          }
        },
      ),
    );

    if (widget.enableHoverHandling) {
      rowContent = MouseRegion(
        onEnter: (_) => setState(() => isHovering = true),
        onExit: (_) => setState(() => isHovering = false),
        child: rowContent,
      );
    }

    if (widget._rowType == _TableRowType.columnHeader) {
      return OutlineDecoration.onlyBottom(child: rowContent);
    }
    return rowContent;
  }

  @override
  bool get isExpanded => widget.isExpanded;

  @override
  void onExpandChanged(bool expanded) {}

  @override
  bool shouldShow() => widget.isShown;
}
