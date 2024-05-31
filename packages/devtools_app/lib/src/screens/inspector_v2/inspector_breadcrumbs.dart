// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/console/eval/inspector_tree.dart';
import '../../shared/diagnostics_text_styles.dart';
import '../../shared/primitives/utils.dart';

class InspectorBreadcrumbNavigator extends StatelessWidget {
  const InspectorBreadcrumbNavigator({
    super.key,
    required this.items,
    required this.onTap,
  });

  /// Max number of visible breadcrumbs including root item but not 'more' item.
  /// E.g. value 5 means root and 4 breadcrumbs can be displayed, other
  /// breadcrumbs (if any) will be replaced by '...' item.
  static const _maxNumberOfBreadcrumbs = 5;

  final List<InspectorTreeNode> items;
  final void Function(InspectorTreeNode?) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox();
    }

    final breadcrumbs = _generateBreadcrumbs(items);
    return SizedBox(
      height: Breadcrumb.height,
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
                onTap: () => onTap(item.node),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<_InspectorBreadcrumbData> _generateBreadcrumbs(
    List<InspectorTreeNode> nodes,
  ) {
    final lastNode = nodes.safeLast;
    final List<_InspectorBreadcrumbData> items = nodes.map((node) {
      return _InspectorBreadcrumbData.wrap(
        node: node,
        isSelected: node == lastNode,
      );
    }).toList();
    List<_InspectorBreadcrumbData> breadcrumbs;
    breadcrumbs = items.length > _maxNumberOfBreadcrumbs
        ? [
            items[0],
            _InspectorBreadcrumbData.more(),
            ...items.sublist(
              items.length - _maxNumberOfBreadcrumbs + 1,
              items.length,
            ),
          ]
        : items;

    return breadcrumbs.joinWith(_InspectorBreadcrumbData.chevron());
  }
}

class _InspectorBreadcrumb extends StatelessWidget {
  const _InspectorBreadcrumb({
    required this.data,
    required this.onTap,
  });

  static const _iconScale = 0.75;

  final _InspectorBreadcrumbData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      data.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DiagnosticsTextStyles.regular(Theme.of(context).colorScheme)
          .copyWith(fontSize: scaleByFontFactor(11)),
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
      borderRadius: defaultBorderRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: densePadding,
          vertical: borderPadding,
        ),
        decoration: BoxDecoration(
          borderRadius: defaultBorderRadius,
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
    required this.node,
    required this.isSelected,
    required this.alternativeText,
    required this.alternativeIcon,
  });

  factory _InspectorBreadcrumbData.wrap({
    required InspectorTreeNode node,
    required bool isSelected,
  }) {
    return _InspectorBreadcrumbData._(
      node: node,
      isSelected: isSelected,
      alternativeText: null,
      alternativeIcon: null,
    );
  }

  /// Construct a special item for showing '…' symbol between other items
  factory _InspectorBreadcrumbData.more() {
    return const _InspectorBreadcrumbData._(
      node: null,
      isSelected: false,
      alternativeText: _ellipsisValue,
      alternativeIcon: null,
    );
  }

  factory _InspectorBreadcrumbData.chevron() {
    return const _InspectorBreadcrumbData._(
      node: null,
      isSelected: false,
      alternativeText: null,
      alternativeIcon: _breadcrumbSeparatorIcon,
    );
  }

  static const _ellipsisValue = '…';
  static const _breadcrumbSeparatorIcon = Icons.chevron_right;

  final InspectorTreeNode? node;
  final IconData? alternativeIcon;
  final String? alternativeText;
  final bool isSelected;

  String get text => alternativeText ?? node?.diagnostic?.description ?? '';

  Widget? get icon {
    if (alternativeIcon != null) {
      return Icon(
        _breadcrumbSeparatorIcon,
        size: defaultIconSize,
      );
    }

    return node?.diagnostic?.icon;
  }

  bool get isChevron =>
      node == null && alternativeIcon == _breadcrumbSeparatorIcon;

  bool get isEllipsis => node == null && alternativeText == _ellipsisValue;

  bool get isClickable => !isSelected && !isEllipsis;
}
