// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../../screens/debugger/debugger_controller.dart';
import '../../../screens/debugger/variables.dart';
import '../../../shared/common_widgets.dart';
import '../../../shared/globals.dart';
import '../../../shared/object_tree.dart';
import '../../../shared/primitives/listenable.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/routing.dart';
import '../../../shared/theme.dart';
import '../../../shared/tree.dart';
import 'display_provider.dart';

class ExpandableVariable extends StatelessWidget {
  const ExpandableVariable({
    Key? key,
    this.variable,
    required this.debuggerController,
  }) : super(key: key);

  @visibleForTesting
  static const emptyExpandableVariableKey = Key('empty expandable variable');

  final DartObjectNode? variable;

  final DebuggerController debuggerController;

  @override
  Widget build(BuildContext context) {
    final variable = this.variable;
    if (variable == null)
      return const SizedBox(key: emptyExpandableVariableKey);
    // TODO(kenz): preserve expanded state of tree on switching frames and
    // on stepping.
    return TreeView<DartObjectNode>(
      dataRootsListenable:
          FixedValueListenable<List<DartObjectNode>>([variable]),
      shrinkWrap: true,
      dataDisplayProvider: (variable, onPressed) =>
          displayProvider(context, variable, onPressed, debuggerController),
      onItemSelected: onItemPressed,
    );
  }

  Future<void> onItemPressed(
    DartObjectNode v,
  ) async {
    // On expansion, lazily build the variables tree for performance reasons.
    if (v.isExpanded) {
      await Future.wait(v.children.map(buildVariablesTree));
    }
  }
}
