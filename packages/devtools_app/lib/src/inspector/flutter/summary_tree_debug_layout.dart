// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import '../diagnostics_node.dart';
import 'inspector_data_models.dart';

class ConstraintsDescription extends AnimatedWidget {
  const ConstraintsDescription({
    this.diagnostic,
    AnimationController animationController,
    Key key,
  }) : super(key: key, listenable: animationController);

  final RemoteDiagnosticsNode diagnostic;

  String describeDimension(double min, double max, String dim) {
    if (min == max) return '$dim=${min.toStringAsFixed(1)}';
    return '${min.toStringAsFixed(1)}<=$dim<=${max.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    if (diagnostic?.constraints == null) {
      return const SizedBox();
    }
    final constraints = deserializeConstraints(diagnostic.constraints);
    if (constraints is BoxConstraints) {
      final textSpans = <TextSpan>[const TextSpan(text: 'BoxConstraints(')];
      if (!constraints.hasBoundedHeight && !constraints.hasBoundedWidth) {
        textSpans.add(
          TextSpan(
            text: 'unconstrained',
            style: inspector_text_styles.warning,
          ),
        );
      } else {
        textSpans.add(
          !constraints.hasBoundedWidth
              ? TextSpan(
                  text: 'width unconstrained',
                  style: inspector_text_styles.warning,
                )
              : TextSpan(
                  text: describeDimension(
                    constraints.minWidth,
                    constraints.maxWidth,
                    'w',
                  ),
                ),
        );
        textSpans.add(const TextSpan(text: ','));
        textSpans.add(
          !constraints.hasBoundedHeight
              ? TextSpan(
                  text: 'height unconstrained',
                  style: inspector_text_styles.warning,
                )
              : TextSpan(
                  text: describeDimension(
                    constraints.minHeight,
                    constraints.maxHeight,
                    'h',
                  ),
                ),
        );
      }
      textSpans.add(const TextSpan(text: ')'));
      final child = Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: RichText(
          text: TextSpan(
            style: inspector_text_styles.unimportantItalic,
            children: textSpans,
          ),
        ),
      );
      return FadeTransition(
        opacity: listenable,
        child: child,
      );
    } else {
      // TODO(albertusangga) Support SliverConstraint
      return const SizedBox();
    }
  }
}
