// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Controller provider that [DevToolsScreen] instances can provide.
///
/// Flutter UI components with this [ControllerProvider] as an ancestor can
/// access the provided controller via `Provider.of<T>(context)`.
class ControllerProvider<T> extends StatelessWidget {
  const ControllerProvider({Key key, this.child, this.controller})
      : super(key: key);

  final Widget child;

  final T controller;

  @override
  Widget build(BuildContext context) {
    return Provider<T>(
      create: (_) => controller,
      child: child,
    );
  }
}
