// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import '../../ui/colors.dart';
import '../../ui/fake_flutter/_real_flutter.dart';

const double rowPadding = 2.0;
const double rowHeight = 25.0;
const double rowHeightWithPadding = rowHeight + rowPadding;
const double sectionSpacing = 15.0;
const double topOffset = rowHeightWithPadding;
const double sideInset = 70.0;

class FlameChartRow {
  const FlameChartRow({
    @required this.nodes,
    @required this.index,
  });

  final List<FlameChartNode> nodes;
  final int index;
}

class FlameChartNode<T> extends StatelessWidget {
  const FlameChartNode({
    Key key,
    @required this.text,
    @required this.tooltip,
    @required this.rect,
    @required this.backgroundColor,
    @required this.textColor,
    @required this.data,
    @required this.selected,
    @required this.onSelected,
  }) : super(key: key);

  FlameChartNode.sectionLabel({
    Key key,
    @required this.text,
    @required this.textColor,
    @required this.backgroundColor,
    @required double top,
    @required double width,
  })  : rect = Rect.fromLTRB(rowPadding, top, width, top + rowHeight),
        tooltip = '',
        data = null,
        selected = false,
        onSelected = ((_) {});

  static const _selectedNodeColor = mainUiColorSelectedLight;

  final Rect rect;
  final String text;
  final String tooltip;
  final Color backgroundColor;
  final Color textColor;
  final T data;
  final bool selected;
  final void Function(T) onSelected;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Tooltip(
        message: tooltip,
        waitDuration: tooltipWait,
        preferBelow: false,
        child: InkWell(
          onTap: () => onSelected(data),
          child: Container(
            padding: const EdgeInsets.only(left: 6.0),
            alignment: Alignment.centerLeft,
            color: selected ? _selectedNodeColor : backgroundColor,
            child: Text(
              text,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.black : textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
