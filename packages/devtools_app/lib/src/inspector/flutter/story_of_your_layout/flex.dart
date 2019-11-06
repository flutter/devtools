// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/ui/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../diagnostics_node.dart';
import '../inspector_data_models.dart';
import 'arrow.dart';
import 'utils.dart';

@immutable
class StoryOfYourFlexWidget extends StatelessWidget {
  const StoryOfYourFlexWidget({
    @required this.diagnostic,
    @required this.properties,
    @required this.size,
    @required this.constraints,
    Key key,
  }) : super(key: key);

  final RemoteDiagnosticsNode diagnostic;
  final Constraints constraints;
  final Size size;
  final RenderFlexProperties properties;

  Widget _visualizeFlex(BuildContext context) {
    if (!diagnostic.hasChildren)
      return const Center(child: Text('No Children'));
    final theme = Theme.of(context);
    final children = diagnostic.childrenNow;
    return AspectRatio(
      aspectRatio: size.width / size.height,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth * 0.95;
        final height = constraints.maxHeight * 0.95;
        final widget = Container(
          width: width,
          height: height,
          child: Flex(
            mainAxisSize: MainAxisSize.min,
            direction: properties.direction,
            mainAxisAlignment: properties.mainAxisAlignment,
            crossAxisAlignment: properties.crossAxisAlignment,
            children: [
              for (var i = 0; i < children.length; i++)
                FlexChildVisualizer(
                  node: children[i],
                  borderColor: i.isOdd ? mainUiColor : mainGpuColor,
                  backgroundColor: i.isOdd ? mainGpuColor : mainUiColor,
                  parentSize: size,
                  screenSize: Size(width * 0.99, height * 0.99),
                )
            ],
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.accentColor,
              width: 2.0,
            ),
          ),
        );
        return _visualizeMainAxisAndCrossAxis(
          child: widget,
          width: width,
          height: height,
          theme: theme,
        );
      }),
    );
  }

  Widget _visualizeMainAxisAndCrossAxis({
    Widget child,
    double width,
    double height,
    ThemeData theme,
  }) {
    return BorderLayout(
      center: child,
      right: Container(
        child: ArrowWrapper.bidirectional(
          arrowColor: theme.splashColor,
          arrowStrokeWidth: 1.0,
          child: RotatedBox(
            quarterTurns: 1,
            child: Text(
              'height: ${size.height} px',
              textAlign: TextAlign.center,
            ),
          ),
          direction: Axis.vertical,
        ),
        height: height,
        width: width * 0.05,
      ),
      bottom: Container(
        margin: const EdgeInsets.only(top: 16.0),
        child: ArrowWrapper.bidirectional(
          arrowColor: theme.splashColor,
          arrowStrokeWidth: 1.0,
          child: Text(
            'width: ${size.width} px',
            textAlign: TextAlign.center,
          ),
          direction: Axis.horizontal,
        ),
        width: width,
        height: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flexType = properties.type.toString();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(top: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              'Story of the flex layout of your $flexType widget',
              style: theme.textTheme.headline,
              textAlign: TextAlign.center,
            ),
          ),
          Flexible(
            child: LayoutBuilder(builder: (context, constraints) {
              final maxHeight = constraints.maxHeight * 0.95;
              final maxWidth = constraints.maxWidth * 0.95;
              const topArrowIndicatorHeight = 32.0;
              const leftArrowIndicatorWidth = 32.0;
              return Container(
                constraints:
                    BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
                child: Stack(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(
                          top: topArrowIndicatorHeight,
                          left: leftArrowIndicatorWidth + 8.0,
                        ),
                        child: WidgetVisualizer(
                          widgetName: flexType,
                          borderColor: theme.accentColor,
                          backgroundColor: theme.primaryColor,
                          child: _visualizeFlex(context),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        height: double.infinity,
                        width: leftArrowIndicatorWidth,
                        child: ArrowWrapper.unidirectional(
                          child: Text(
                            properties.verticalDirectionDescription,
                            textAlign: TextAlign.center,
                          ),
                          type: ArrowType.down,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: topArrowIndicatorHeight,
                        child: ArrowWrapper.unidirectional(
                          child: Text(
                            properties.horizontalDirectionDescription,
                            textAlign: TextAlign.center,
                          ),
                          type: ArrowType.right,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class WidgetVisualizer extends StatelessWidget {
  const WidgetVisualizer({
    Key key,
    @required this.widgetName,
    @required this.borderColor,
    @required this.backgroundColor,
    this.child,
  })  : assert(widgetName != null),
        assert(borderColor != null),
        assert(backgroundColor != null),
        super(key: key);

  final String widgetName;
  final Color borderColor;
  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            child: Text(widgetName),
            decoration: BoxDecoration(
              color: borderColor,
            ),
            padding: const EdgeInsets.all(4.0),
          ),
          if (child != null)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(
                  left: 16.0,
                  top: 16.0,
                ),
                child: child,
              ),
            ),
        ],
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
        ),
        color: backgroundColor,
      ),
    );
    ;
  }
}

class FlexChildVisualizer extends StatelessWidget {
  const FlexChildVisualizer({
    Key key,
    this.node,
    this.borderColor,
    this.backgroundColor,
    this.parentSize,
    this.screenSize,
  }) : super(key: key);

  final RemoteDiagnosticsNode node;
  final Color borderColor;
  final Color backgroundColor;

  final Size parentSize;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    final size = deserializeSize(node.size);
    return Container(
      width: (size.width / parentSize.width) * screenSize.width,
      height: (size.height / parentSize.height) * screenSize.height,
      child: WidgetVisualizer(
        widgetName: node.description,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
      ),
    );
  }
}
