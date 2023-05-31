// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'vs_code/flutter_panel.dart';

/// A "screen" that is intended for embedded ide use only.
///
/// An embedded screen is one that will be available at a "tabless" route,
/// meaning that this screen will not be part of DevTools' normal navigation.
/// The only way to access an embedded screen is directly from the url.
class EmbeddedScreen extends StatefulWidget {
  const EmbeddedScreen({super.key, required this.id});

  final String? id;

  @override
  State<EmbeddedScreen> createState() => _EmbeddedScreenState();
}

class _EmbeddedScreenState extends State<EmbeddedScreen> {
  @override
  Widget build(BuildContext context) {
    final type = EmbeddedScreenType.parse(widget.id);
    if (type == null) {
      return Text('Unknown embedded screen id: "${widget.id}"');
    }
    return type.screen;
  }
}

enum EmbeddedScreenType {
  vsCodeFlutterPanel;

  static EmbeddedScreenType? parse(String? id) {
    if (id == null) return null;

    for (final type in EmbeddedScreenType.values) {
      if (type.name == id) return type;
    }
    return null;
  }

  Widget get screen {
    return switch (this) {
      EmbeddedScreenType.vsCodeFlutterPanel => const VsCodeFlutterPanel(),
    };
  }
}
