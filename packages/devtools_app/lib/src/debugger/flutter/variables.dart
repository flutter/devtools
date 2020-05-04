// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';

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
        // TODO(kenz): display variables in a tree view.
        return const Center(child: Text('TODO'));
      },
    );
  }
}
