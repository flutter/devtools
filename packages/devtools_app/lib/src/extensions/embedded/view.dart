// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '_view_desktop.dart' if (dart.library.html) '_view_web.dart';
import 'controller.dart';

/// A widget that displays a DevTools extension in an embedded iFrame.
///
/// A DevTools extension is provided by a pub package and is served by the
/// DevTools server when present for a connected application.
///
/// When DevTools is run on Desktop for development, this widget displays a
/// placeholder, since Flutter Desktop does not currently support web views.
class EmbeddedExtensionView extends StatelessWidget {
  const EmbeddedExtensionView({Key? key, required this.controller})
      : super(key: key);

  final EmbeddedExtensionController controller;

  @override
  Widget build(BuildContext context) {
    return EmbeddedExtension(controller: controller);
  }
}
