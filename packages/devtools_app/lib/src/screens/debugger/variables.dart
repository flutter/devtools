// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(https://github.com/flutter/devtools/issues/4717): migrate away from
// deprecated members.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart' hide Stack;

import '../../shared/console/widgets/display_provider.dart';
import '../../shared/diagnostics/dap_object_node.dart';
import '../../shared/diagnostics/dart_object_node.dart';
import '../../shared/diagnostics/tree_builder.dart';
import '../../shared/feature_flags.dart';
import '../../shared/globals.dart';
import '../../shared/tree.dart';

class Variables extends StatelessWidget {
  const Variables({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): preserve expanded state of tree on switching frames and
    // on stepping.
    if (FeatureFlags.dapDebugging) {
      return TreeView<DapObjectNode>(
        dataRootsListenable: serviceConnection.appState.dapVariables,
        dataDisplayProvider: (variable, onPressed) {
          return DapDisplayProvider(node: variable, onTap: onPressed);
        },
        onItemExpanded: onDapItemExpanded,
      );
    } else {
      return TreeView<DartObjectNode>(
        dataRootsListenable: serviceConnection.appState.variables,
        dataDisplayProvider: (variable, onPressed) => DisplayProvider(
          variable: variable,
          onTap: onPressed,
        ),
        onItemSelected: onItemPressed,
      );
    }
  }

  Future<void> onDapItemExpanded(
    DapObjectNode node,
  ) async {
    if (node.isExpanded) {
      for (final child in node.children) {
        await child.fetchChildren();
      }
    }
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
