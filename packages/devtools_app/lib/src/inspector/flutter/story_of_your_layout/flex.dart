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
                color: theme.focusColor,
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

  Widget _visualizeMainAxisAndCrossAxis(Widget child, double length) {
    return Center(
      child: GridAddOns(
        child: child,
        top: Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: BidirectionalHorizontalArrowWrapper(
            child: Text(
              properties.horizontalDirectionDescription,
            ),
          ),
          width: length,
        ),
        left: Container(
          height: length,
          margin: const EdgeInsets.only(right: 16.0, left: 8.0),
          child: BidirectionalVerticalArrowWrapper(
            child: Text(
              properties.verticalDirectionDescription,
            ),
            height: length,
          ),
        ),
        right: Container(
          height: length,
          margin: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: BidirectionalVerticalArrowWrapper(
            child: Text(
              properties.verticalDirectionDescription,
            ),
            height: length,
          ),
        ),
        bottom: Container(
          margin: const EdgeInsets.only(top: 16.0),
          child: BidirectionalHorizontalArrowWrapper(
            child: Text(
              properties.horizontalDirectionDescription,
            ),
          ),
          width: length,
        ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 36.0),
            child: Text(
              'Story of the flex layout of your $flexType widget',
              style: theme.textTheme.headline,
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
                constraints.maxHeight * 0.75,
                constraints.maxWidth * 0.75,
              );
              final length = min(minDimension, 800.0);

              final flexVisualizerWidget = Container(
                width: length,
                height: length,
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
              );
            }),
          ),
        ],
      ),
    );
  }
}
