// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import '../diagnostics_node.dart';
import '../inspector_controller.dart';

class ConstraintsDescription extends AnimatedWidget {
  const ConstraintsDescription({
    this.diagnostic,
    AnimationController animationController,
    Key key,
  }) : super(key: key, listenable: animationController);

  final RemoteDiagnosticsNode diagnostic;

  @override
  Widget build(BuildContext context) {
    if (diagnostic?.constraints == null) {
      return const SizedBox();
    }
    var textStyle = inspector_text_styles.unimportantItalic;
    if (diagnostic?.shouldHighlightConstraints ?? false) {
      textStyle = textStyle.merge(textStyleForLevel(DiagnosticLevel.warning));
    }
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        '${diagnostic.constraints}',
        style: textStyle,
      ),
    );
    if (listenable == null) return child;
    return FadeTransition(
      opacity: listenable,
      child: child,
    );
  }
}
