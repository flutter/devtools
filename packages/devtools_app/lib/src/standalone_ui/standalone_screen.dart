// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'vs_code/flutter_panel.dart';

/// A "screen" that is intended for standalone use only, likely for embedding
/// directly in an IDE.
///
/// A standalone screen is one that will only be available at a specific route,
/// meaning that this screen will not be part of DevTools' normal navigation.
/// The only way to access a standalone screen is directly from the url.
class StandaloneScreen extends StatefulWidget {
  const StandaloneScreen({super.key, required this.id});

  final String? id;

  @override
  State<StandaloneScreen> createState() => _StandaloneScreenState();
}

class _StandaloneScreenState extends State<StandaloneScreen> {
  @override
  Widget build(BuildContext context) {
    final type = StandaloneScreenType.parse(widget.id);
    if (type == null) {
      return Text('Unknown view id: "${widget.id}"');
    }
    return type.screen;
  }
}

enum StandaloneScreenType {
  vsCodeFlutterPanel;

  static StandaloneScreenType? parse(String? id) {
    if (id == null) return null;

    for (final type in StandaloneScreenType.values) {
      if (type.name == id) return type;
    }
    return null;
  }

  Widget get screen {
    return switch (this) {
      StandaloneScreenType.vsCodeFlutterPanel => const VsCodeFlutterPanel(),
    };
  }
}
