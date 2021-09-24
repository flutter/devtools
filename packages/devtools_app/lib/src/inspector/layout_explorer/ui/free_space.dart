import 'package:flutter/material.dart';

import '../../../common_widgets.dart';
import '../../../utils.dart';
import '../../inspector_data_models.dart';
import 'arrow.dart';
import 'dimension.dart';
import 'theme.dart';

class FreeSpaceVisualizerWidget extends StatelessWidget {
  const FreeSpaceVisualizerWidget(
    this.renderProperties, {
    Key key,
  }) : super(key: key);

  final RenderProperties renderProperties;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heightDescription =
        'h=${toStringAsFixed(renderProperties.realHeight)}';
    final widthDescription = 'w=${toStringAsFixed(renderProperties.realWidth)}';
    final showWidth = renderProperties.realWidth !=
        (renderProperties.layoutProperties?.width);
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
    final heightWidget = Container(
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
      child: Container(
        width: renderProperties.width,
        height: renderProperties.height,
        child: DevToolsTooltip(
          tooltip: '$widthDescription\n$heightDescription',
          child: showWidth ? widthWidget : heightWidget,
        ),
      ),
    );
  }
}

class PaddingVisualizerWidget extends StatelessWidget {
  const PaddingVisualizerWidget(
    this.renderProperties, {
    @required this.horizontal,
    Key key,
  }) : super(key: key);

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
    final heightWidget = Container(
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
      child: Container(
        width: safePositiveDouble(renderProperties.width),
        height: safePositiveDouble(renderProperties.height),
        child: horizontal ? widthWidget : heightWidget,
      ),
    );
  }
}
