import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../devtools_app.dart';
import 'inspector_text_styles.dart';

class InspectorBreadcrumbNavigator extends StatelessWidget {
  const InspectorBreadcrumbNavigator({
    Key key,
    @required this.rows,
    @required this.onTap,
  }) : super(key: key);

  final List<InspectorTreeRow> rows;
  final Function(InspectorTreeRow) onTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox();
    }

    final items = _getBreadcrumbs(rows);
    final breadcrumbs = _getBreadcrumbWithChevron(items);
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

  List<_InspectorBreadcrumbData> _getBreadcrumbs(List<InspectorTreeRow> rows) {
    final List<_InspectorBreadcrumbData> items = rows
        .map((e) => _InspectorBreadcrumbData.wrap(e, e == rows.safeLast))
        .toList();
    if (items.length > 5) {
      return []
        ..add(items[0])
        ..add(_InspectorBreadcrumbData.more())
        ..addAll(items.sublist(items.length - 4, items.length));
    } else {
      return items;
    }
  }

  Iterable<_InspectorBreadcrumbData> _getBreadcrumbWithChevron(
      List<_InspectorBreadcrumbData> items) sync* {
    for (int i = 0; i < items.length; i++) {
      yield items[i];

      if (i != items.length - 1) {
        yield _InspectorBreadcrumbData.chevron();
      }
    }
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
      BorderRadius.all(Radius.circular(4));

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
            scale: .75,
            child: Padding(
              padding: const EdgeInsets.only(right: iconPadding),
              child: data.icon,
            ),
          );

    return InkWell(
      onTap: data.isClickable ? onTap : null,
      borderRadius: _borderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
  const _InspectorBreadcrumbData._(
    this.row,
    this.isSelected,
    this._alternativeText,
    this._alternativeIcon,
  );

  factory _InspectorBreadcrumbData.wrap(
          InspectorTreeRow row, bool isSelected) =>
      _InspectorBreadcrumbData._(row, isSelected, null, null);

  /// Construct a special item for showing '…' symbol between other items
  factory _InspectorBreadcrumbData.more() =>
      const _InspectorBreadcrumbData._(null, false, '…', null);

  factory _InspectorBreadcrumbData.chevron() {
    final icon = Icon(
      Icons.chevron_right,
      size: defaultIconSize,
    );
    return _InspectorBreadcrumbData._(null, false, null, icon);
  }

  final InspectorTreeRow row;
  final Widget _alternativeIcon;
  final String _alternativeText;
  final bool isSelected;

  String get text => _alternativeText ?? row?.node?.diagnostic?.description;

  Widget get icon => _alternativeIcon ?? row?.node?.diagnostic?.icon;

  bool get isChevron => row == null && _alternativeText == null;

  bool get isEllipsis => row == null && _alternativeIcon == null;

  bool get isClickable => !isSelected && !isEllipsis;
}
