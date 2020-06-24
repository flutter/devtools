import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../utils.dart';
import '../../inspector_data_models.dart';
import 'arrow.dart';
import 'flex.dart';

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
          margin: const EdgeInsets.symmetric(vertical: arrowMargin),
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
            margin: const EdgeInsets.symmetric(horizontal: arrowMargin),
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
        child: Tooltip(
          message: '$widthDescription\n$heightDescription',
          child: showWidth ? widthWidget : heightWidget,
        ),
      ),
    );
  }
}
