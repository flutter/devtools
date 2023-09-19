// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../devtools_app.dart';
import 'api/impl/dart_tooling_api.dart';
import 'vs_code/flutter_panel.dart';

/// "Screens" that are intended for standalone use only, likely for embedding
/// directly in an IDE.
///
/// A standalone screen is one that will only be available at a specific route,
/// meaning that this screen will not be part of DevTools' normal navigation.
/// The only way to access a standalone screen is directly from the url.
enum StandaloneScreenType {
  vsCodeFlutterPanel;

  // TODO(dantup): This seems unused, is it needed?
  static StandaloneScreenType? parse(String? id) {
    if (id == null) return null;

    for (final type in StandaloneScreenType.values) {
      if (type.name == id) return type;
    }
    return null;
  }

  Widget build(List<Screen> screens) {
    return switch (this) {
      StandaloneScreenType.vsCodeFlutterPanel =>
        VsCodeFlutterPanel(screens, DartToolingApiImpl.postMessage()),
    };
  }
}
