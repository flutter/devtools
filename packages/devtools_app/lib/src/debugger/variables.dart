// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';

import '../common_widgets.dart';
import '../theme.dart';
import '../tree.dart';
import '../utils.dart';
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
          dataDisplayProvider: (variable, onPressed) =>
              displayProvider(context, variable, onPressed),
          onItemPressed: (variable) => onItemPressed(variable, controller),
        );
      },
    );
  }

  void onItemPressed(Variable v, DebuggerController controller) {
    // On expansion, lazily build the variables tree for performance reasons.
    if (v.isExpanded) {
      v.children.forEach(controller.buildVariablesTree);
    }
  }
}

class VariablesList extends StatelessWidget {
  const VariablesList({Key key, this.lines}) : super(key: key);

  final List<Variable> lines;

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DebuggerController>(context);
    if (lines.isEmpty) return const SizedBox();
    // TODO(kenz): preserve expanded state of tree on switching frames and
    // on stepping.
    return TreeView<Variable>(
      dataRoots: lines,
      dataDisplayProvider: (variable, onPressed) =>
          displayProvider(context, variable, onPressed),
      onItemPressed: (variable) => onItemPressed(variable, controller),
    );
  }

  void onItemPressed(Variable v, DebuggerController controller) {
    // On expansion, lazily build the variables tree for performance reasons.
    if (v.isExpanded) {
      v.children.forEach(controller.buildVariablesTree);
    }
  }
}

class ExpandableVariable extends StatelessWidget {
  const ExpandableVariable({Key key, this.variable, this.debuggerController})
      : super(key: key);

  final ValueListenable<Variable> variable;
  final DebuggerController debuggerController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Variable>(
      valueListenable: variable,
      builder: (context, variable, _) {
        final controller =
            debuggerController ?? Provider.of<DebuggerController>(context);
        if (variable == null) return const SizedBox();
        // TODO(kenz): preserve expanded state of tree on switching frames and
        // on stepping.
        return TreeView<Variable>(
          dataRoots: [variable],
          shrinkWrap: true,
          dataDisplayProvider: (variable, onPressed) =>
              displayProvider(context, variable, onPressed),
          onItemPressed: (variable) => onItemPressed(variable, controller),
        );
      },
    );
  }

  void onItemPressed(Variable v, DebuggerController controller) {
    // On expansion, lazily build the variables tree for performance reasons.
    if (v.isExpanded) {
      v.children.forEach(controller.buildVariablesTree);
    }
  }
}

Widget displayProvider(
  BuildContext context,
  Variable variable,
  VoidCallback onTap,
) {
  final theme = Theme.of(context);

  // TODO(devoncarew): Here, we want to wait until the tooltip wants to show,
  // then call toString() on variable and render the result in a tooltip. We
  // should also include the type of the value in the tooltip if the variable
  // is not null.
  if (variable.text != null) {
    return SelectableText.rich(
      TextSpan(
        children: processAnsiTerminalCodes(
          variable.text,
          theme.fixedFontStyle,
        ),
      ),
      onTap: onTap,
    );
  }
  return Tooltip(
    message: variable.displayValue,
    waitDuration: tooltipWaitLong,
    child: SelectableText.rich(
      TextSpan(
        text: variable.boundVar.name.isNotEmpty ?? false
            ? '${variable.boundVar.name}: '
            : null,
        style: theme.fixedFontStyle,
        children: [
          TextSpan(
            text: variable.displayValue,
            style: theme.subtleFixedFontStyle,
          ),
        ],
      ),
      onTap: onTap,
    ),
  );
}
