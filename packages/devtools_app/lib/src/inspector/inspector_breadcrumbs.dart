import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils.dart';
import 'inspector_text_styles.dart';
import 'inspector_tree.dart';

class InspectorBreadcrumbNavigator extends StatelessWidget {
  const InspectorBreadcrumbNavigator({
    Key key,
    @required this.rows,
    @required this.onTap,
  }) : super(key: key);

  static const _maxNumberOfBreadcrumbs = 4;

  final List<InspectorTreeRow> rows;
  final Function(InspectorTreeRow) onTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox();
    }

    final breadcrumbs = _generateBreadcrumbs(rows);
    return SizedBox(
      height: isDense() ? 24 : 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: breadcrumbs.map((item) {
            if (item.isChevron) {
              return Icon(
                Icons.chevron_right,
                size: defaultIconSize,
              );
            }

            return Flexible(
              child: _InspectorBreadcrumb(
                data: item,
                onTap: () => onTap(item.row),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<_InspectorBreadcrumbData> _generateBreadcrumbs(
    List<InspectorTreeRow> rows,
  ) {
    final List<_InspectorBreadcrumbData> items = rows.map((row) {
      return _InspectorBreadcrumbData.wrap(
        row: row,
        isSelected: row == rows.safeLast,
      );
    }).toList();
    List<_InspectorBreadcrumbData> breadcrumbs;
    if (items.length > _maxNumberOfBreadcrumbs) {
      breadcrumbs = [
        items[0],
        _InspectorBreadcrumbData.more(),
        ...items.sublist(items.length - _maxNumberOfBreadcrumbs, items.length),
      ];
    } else {
      breadcrumbs = items;
    }

    return breadcrumbs.joinWith(_InspectorBreadcrumbData.chevron());
  }
}

class _InspectorBreadcrumb extends StatelessWidget {
  const _InspectorBreadcrumb({
    Key key,
    @required this.data,
    @required this.onTap,
  })  : assert(data != null),
        super(key: key);

  static const BorderRadius _borderRadius =
      BorderRadius.all(Radius.circular(defaultBorderRadius));

  static const _iconScale = .75;

  final _InspectorBreadcrumbData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      data.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: regular.copyWith(fontSize: scaleByFontFactor(11)),
    );

    final icon = data.icon == null
        ? null
        : Transform.scale(
            scale: _iconScale,
            child: Padding(
              padding: const EdgeInsets.only(right: iconPadding),
              child: data.icon,
            ),
          );

    return InkWell(
      onTap: data.isClickable ? onTap : null,
      borderRadius: _borderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: densePadding,
          vertical: borderPadding,
        ),
        decoration: BoxDecoration(
          borderRadius: _borderRadius,
          color: data.isSelected
              ? Theme.of(context).colorScheme.selectedRowBackgroundColor
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) icon,
            Flexible(child: text),
          ],
        ),
      ),
    );
  }
}

class _InspectorBreadcrumbData {
  const _InspectorBreadcrumbData._({
    @required this.row,
    @required this.isSelected,
    @required this.alternativeText,
    @required this.alternativeIcon,
  });

  factory _InspectorBreadcrumbData.wrap({
    @required InspectorTreeRow row,
    @required bool isSelected,
  }) {
    return _InspectorBreadcrumbData._(
      row: row,
      isSelected: isSelected,
      alternativeText: null,
      alternativeIcon: null,
    );
  }

  /// Construct a special item for showing '…' symbol between other items
  factory _InspectorBreadcrumbData.more() {
    return const _InspectorBreadcrumbData._(
      row: null,
      isSelected: false,
      alternativeText: '…',
      alternativeIcon: null,
    );
  }

  factory _InspectorBreadcrumbData.chevron() {
    final icon = Icon(
      Icons.chevron_right,
      size: defaultIconSize,
    );
    return _InspectorBreadcrumbData._(
      row: null,
      isSelected: false,
      alternativeText: null,
      alternativeIcon: icon,
    );
  }

  final InspectorTreeRow row;
  final Widget alternativeIcon;
  final String alternativeText;
  final bool isSelected;

  String get text => alternativeText ?? row?.node?.diagnostic?.description;

  Widget get icon => alternativeIcon ?? row?.node?.diagnostic?.icon;

  bool get isChevron =>
      row == null && alternativeText == null ?? alternativeIcon != null;

  bool get isEllipsis =>
      row == null && alternativeIcon == null && alternativeText != null;

  bool get isClickable => !isSelected && !isEllipsis;
}
