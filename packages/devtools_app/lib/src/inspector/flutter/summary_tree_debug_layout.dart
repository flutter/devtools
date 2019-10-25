// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import '../diagnostics_node.dart';
import '../inspector_controller.dart';

class ConstraintsDescription extends StatefulWidget {
  const ConstraintsDescription(
      this.diagnostics, this.isDebugLayoutSummaryEnabled,
      {Key key})
      : super(key: key);

  final RemoteDiagnosticsNode diagnostics;
  final ValueNotifier<bool> isDebugLayoutSummaryEnabled;

  @override
  _ConstraintsDescriptionState createState() => _ConstraintsDescriptionState();
}

class _ConstraintsDescriptionState extends State<ConstraintsDescription>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.diagnostics?.constraints == null) {
      return const SizedBox();
    }

    TextStyle textStyle = inspector_text_styles.unimportantItalic;

    if (widget.diagnostics?.shouldHighlightConstraints ?? false) {
      textStyle = textStyle.merge(textStyleForLevel(DiagnosticLevel.warning));
    }

    return ValueListenableBuilder<bool>(
      valueListenable: widget.isDebugLayoutSummaryEnabled,
      builder: (context, debugLayoutMode, child) {
        if (debugLayoutMode) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
        return child;
      },
      child: FadeTransition(
        opacity: _animation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '// constraints: ${widget.diagnostics.constraints}',
            style: textStyle,
          ),
        ),
      ),
    );
  }
}
