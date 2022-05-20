// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../primitives/math_utils.dart';
import '../../../../primitives/utils.dart';
import '../../../../shared/theme.dart';
import '../../inspector_data_models.dart';
import 'arrow.dart';
import 'dimension.dart';
import 'theme.dart';
import 'utils.dart';

class VisualizeWidthAndHeightWithConstraints extends StatelessWidget {
  VisualizeWidthAndHeightWithConstraints({
    required this.properties,
    double? arrowHeadSize,
    required this.child,
    this.warnIfUnconstrained = true,
  }) : arrowHeadSize = arrowHeadSize ?? defaultIconSize;

  final Widget child;
  final LayoutProperties properties;
  final double arrowHeadSize;
  final bool warnIfUnconstrained;

  @override
  Widget build(BuildContext context) {
    final propertiesLocal = properties;
    final showChildrenWidthsSum = propertiesLocal is FlexLayoutProperties &&
        propertiesLocal.isOverflowWidth;
    final bottomHeight = widthAndConstraintIndicatorSize;
    final rightWidth = heightAndConstraintIndicatorSize;
    final colorScheme = Theme.of(context).colorScheme;

    final showOverflowHeight =
        properties is FlexLayoutProperties && propertiesLocal.isOverflowHeight;
    final heightDescription = RotatedBox(
      quarterTurns: 1,
      dimensionDescription(
        TextSpan(
          children: [
            TextSpan(
              text: '${propertiesLocal.describeHeight()}',
            ),
            if (propertiesLocal.constraints != null) ...[
              if (!showOverflowHeight) const TextSpan(text: '\n'),
              TextSpan(
                text: ' (${propertiesLocal.describeHeightConstraints()})',
                style: propertiesLocal.constraints!.hasBoundedHeight ||
                        !warnIfUnconstrained
                    ? null
                    : TextStyle(
                        color: colorScheme.unconstrainedColor,
                      ),
              )
            ],
            if (showOverflowHeight)
              TextSpan(
                text: '\nchildren take: '
                    '${toStringAsFixed(sum(propertiesLocal.childrenHeights.cast<double>()))}',
              ),
          ],
        ),
        propertiesLocal.isOverflowHeight,
        colorScheme,
      ),
    );
    final right = Container(
      margin: EdgeInsets.only(
        top: margin,
        left: margin,
        bottom: bottomHeight,
        right: minPadding, // custom margin for not sticking to the corner
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final displayHeightOutsideArrow =
              constraints.maxHeight < minHeightToDisplayHeightInsideArrow;
          return Row(
            [
              Truncateable(
                truncate: !displayHeightOutsideArrow,
                Container(
                  margin: EdgeInsets.symmetric(horizontal: arrowMargin),
                  ArrowWrapper.bidirectional(
                    arrowColor: heightIndicatorColor,
                    arrowStrokeWidth: arrowStrokeWidth,
                    arrowHeadSize: arrowHeadSize,
                    direction: Axis.vertical,
                    displayHeightOutsideArrow ? null : heightDescription,
                  ),
                ),
              ),
              if (displayHeightOutsideArrow)
                Flexible(
                  heightDescription,
                ),
            ],
          );
        },
      ),
    );

    final widthDescription = dimensionDescription(
      TextSpan(
        children: [
          TextSpan(text: '${propertiesLocal.describeWidth()}; '),
          if (propertiesLocal.constraints != null) ...[
            if (!showChildrenWidthsSum) const TextSpan(text: '\n'),
            TextSpan(
              text: '(${propertiesLocal.describeWidthConstraints()})',
              style: propertiesLocal.constraints!.hasBoundedWidth ||
                      !warnIfUnconstrained
                  ? null
                  : TextStyle(color: colorScheme.unconstrainedColor),
            )
          ],
          if (showChildrenWidthsSum)
            TextSpan(
              text: '\nchildren take '
                  '${toStringAsFixed(sum(propertiesLocal.childrenWidths.cast<double>()))}',
            )
        ],
      ),
      propertiesLocal.isOverflowWidth,
      colorScheme,
    );
    final bottom = Container(
      margin: EdgeInsets.only(
        top: margin,
        left: margin,
        right: rightWidth,
        bottom: minPadding,
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final displayWidthOutsideArrow =
              maxWidth < minWidthToDisplayWidthInsideArrow;
          return Column(
            [
              Truncateable(
                truncate: !displayWidthOutsideArrow,
                Container(
                  margin: EdgeInsets.symmetric(vertical: arrowMargin),
                  ArrowWrapper.bidirectional(
                    arrowColor: widthIndicatorColor,
                    arrowHeadSize: arrowHeadSize,
                    arrowStrokeWidth: arrowStrokeWidth,
                    direction: Axis.horizontal,
                    displayWidthOutsideArrow ? null : widthDescription,
                  ),
                ),
              ),
              if (displayWidthOutsideArrow)
                Flexible(
                  Container(
                    padding: const EdgeInsets.only(top: minPadding),
                    widthDescription,
                  ),
                ),
            ],
          );
        },
      ),
    );
    return BorderLayout(
      center: child,
      right: right,
      rightWidth: rightWidth,
      bottom: bottom,
      bottomHeight: bottomHeight,
    );
  }
}
