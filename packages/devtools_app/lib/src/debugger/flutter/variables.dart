// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/tree.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

class Variables extends StatelessWidget {
  const Variables({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DebuggerController>(context);
    return ValueListenableBuilder<List<Variable>>(
      valueListenable: controller.variables,
      builder: (context, variables, _) {
        if (variables.isEmpty) return const SizedBox();
        // TODO(kenz): preserve expanded state of tree on switching frames and
        // on stepping.
        return TreeView<Variable>(
          dataRoots: variables,
          dataDisplayProvider: (variable) => displayProvider(context, variable),
          onItemPressed: (variable) => onItemPressed(variable, controller),
        );
      },
    );
  }

  Widget displayProvider(BuildContext context, Variable v) {
    final theme = Theme.of(context);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        text: '${v.boundVar.name} ',
        style: theme.regularTextStyle,
        children: [
          TextSpan(
            text: v.displayValue,
            style: theme.subtleTextStyle,
          ),
        ],
      ),
    );
  }

  void onItemPressed(Variable v, DebuggerController controller) {
    // On expansion, lazily build the variables tree for performance reasons.
    if (v.isExpanded) {
      v.children.forEach(controller.buildVariablesTree);
    }
  }
}
