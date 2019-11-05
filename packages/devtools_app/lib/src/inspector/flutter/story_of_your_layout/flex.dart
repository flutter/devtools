// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

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
    this.diagnostic,
    this.properties,
    Key key,
  }) : super(key: key);

  final RemoteDiagnosticsNode diagnostic;
  final RenderFlexProperties properties;

  List<Widget> _visualizeChildren(BuildContext context) {
    if (!diagnostic.hasChildren) return [const SizedBox()];
    final theme = Theme.of(context);
    return [
      for (var child in diagnostic.childrenNow)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.secondaryHeaderColor,
                width: 1.0,
              ),
            ),
            child: Center(
              child: Text(child.description),
            ),
          ),
        ),
    ];
  }

  Widget _visualizeMainAxisAndCrossAxis(
    Widget child,
    double length,
    ThemeData theme,
  ) {
    return BorderLayout(
      center: child,
      top: Container(
        child: ArrowWrapper.unidirectional(
          arrowColor: theme.hintColor,
          child: Text(
            properties.horizontalDirectionDescription,
            textAlign: TextAlign.center,
          ),
          distanceToArrow: 4.0,
          type: ArrowType.right,
        ),
        margin: const EdgeInsets.only(bottom: 16.0),
        width: length,
      ),
      left: Container(
        child: ArrowWrapper.unidirectional(
          arrowColor: theme.hintColor,
          child: Text(
            properties.verticalDirectionDescription,
            textAlign: TextAlign.center,
          ),
          distanceToArrow: 4.0,
          type: ArrowType.down,
        ),
        height: length,
        width: length * 0.25,
      ),
      right: Container(
        child: ArrowWrapper.bidirectional(
          arrowColor: theme.splashColor,
          arrowStrokeWidth: 1.0,
          child: Column(
            children: <Widget>[
              Text(
                // TODO(albertusangga): Use real height
                '${length.round()} px',
                textAlign: TextAlign.center,
              ),
              const Text(
                'height',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          direction: Axis.vertical,
        ),
        height: length,
        width: length * 0.25,
      ),
      bottom: Container(
        margin: const EdgeInsets.only(top: 16.0),
        child: ArrowWrapper.bidirectional(
          arrowColor: theme.splashColor,
          arrowStrokeWidth: 1.0,
          child: Column(
            children: <Widget>[
              Text(
                // TODO(albertusangga): Use real width
                '${length.round()} px',
              ),
              const Text('width'),
            ],
          ),
          direction: Axis.horizontal,
        ),
        width: length,
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
            margin: const EdgeInsets.only(bottom: 36.0),
            child: Text(
              'Story of the flex layout of your $flexType widget',
              style: theme.textTheme.headline,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final children = _visualizeChildren(context);
              final flexDirectionWrapper = Flex(
                direction: properties.direction,
                children: children,
              );
              final childrenVisualizerWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Text(
                      properties.type.toString(),
                    ),
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                    ),
                    padding: const EdgeInsets.all(4.0),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                        top: 8.0,
                      ),
                      child: flexDirectionWrapper,
                    ),
                  ),
                ],
              );

              final minDimension = min(
                constraints.maxHeight * 0.5,
                constraints.maxWidth * 0.5,
              );
              final length = min(minDimension, 800.0);

              final flexVisualizerWidget = Container(
                constraints: BoxConstraints.tight(
                  Size(
                    length,
                    length,
                  ),
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.accentColor,
                  ),
                  color: theme.primaryColor,
                ),
                child: childrenVisualizerWidget,
              );

              return _visualizeMainAxisAndCrossAxis(
                flexVisualizerWidget,
                length,
                theme,
              );
            }),
          ),
        ],
      ),
    );
  }
}
