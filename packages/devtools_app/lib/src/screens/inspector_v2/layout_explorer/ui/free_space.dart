// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/primitives/utils.dart';
import '../../inspector_data_models.dart';
import 'arrow.dart';
import 'dimension.dart';
import 'theme.dart';

class FreeSpaceVisualizerWidget extends StatelessWidget {
  const FreeSpaceVisualizerWidget(
    this.renderProperties, {
    super.key,
  });

  final RenderProperties renderProperties;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heightDescription =
        'h=${toStringAsFixed(renderProperties.realHeight)}';
    final widthDescription = 'w=${toStringAsFixed(renderProperties.realWidth)}';
    final showWidth =
        renderProperties.realWidth != renderProperties.layoutProperties?.width;
    final widthWidget = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: dimensionDescription(
            TextSpan(
              text: widthDescription,
            ),
            false,
            colorScheme,
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(vertical: arrowMargin),
          child: ArrowWrapper.bidirectional(
            arrowColor: widthIndicatorColor,
            direction: Axis.horizontal,
            arrowHeadSize: arrowHeadSize,
          ),
        ),
      ],
    );
    final heightWidget = SizedBox(
      width: heightOnlyIndicatorSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: dimensionDescription(
              TextSpan(text: heightDescription),
              false,
              colorScheme,
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: arrowMargin),
            child: ArrowWrapper.bidirectional(
              arrowColor: heightIndicatorColor,
              direction: Axis.vertical,
              arrowHeadSize: arrowHeadSize,
              childMarginFromArrow: 0.0,
            ),
          ),
        ],
      ),
    );
    return Positioned(
      top: renderProperties.offset.dy,
      left: renderProperties.offset.dx,
      child: SizedBox(
        width: renderProperties.width,
        height: renderProperties.height,
        child: DevToolsTooltip(
          message: '$widthDescription\n$heightDescription',
          child: showWidth ? widthWidget : heightWidget,
        ),
      ),
    );
  }
}

class PaddingVisualizerWidget extends StatelessWidget {
  const PaddingVisualizerWidget(
    this.renderProperties, {
    required this.horizontal,
    super.key,
  });

  final RenderProperties renderProperties;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heightDescription =
        'h=${toStringAsFixed(renderProperties.realHeight)}';
    final widthDescription = 'w=${toStringAsFixed(renderProperties.realWidth)}';
    final widthWidget = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: dimensionDescription(
            TextSpan(
              text: widthDescription,
            ),
            false,
            colorScheme,
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(vertical: arrowMargin),
          child: ArrowWrapper.bidirectional(
            arrowColor: widthIndicatorColor,
            direction: Axis.horizontal,
            arrowHeadSize: arrowHeadSize,
          ),
        ),
      ],
    );
    final heightWidget = SizedBox(
      width: heightOnlyIndicatorSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: dimensionDescription(
              TextSpan(text: heightDescription),
              false,
              colorScheme,
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: arrowMargin),
            child: ArrowWrapper.bidirectional(
              arrowColor: heightIndicatorColor,
              direction: Axis.vertical,
              arrowHeadSize: arrowHeadSize,
              childMarginFromArrow: 0.0,
            ),
          ),
        ],
      ),
    );
    return Positioned(
      top: renderProperties.offset.dy,
      left: renderProperties.offset.dx,
      child: SizedBox(
        width: safePositiveDouble(renderProperties.width),
        height: safePositiveDouble(renderProperties.height),
        child: horizontal ? widthWidget : heightWidget,
      ),
    );
  }
}
