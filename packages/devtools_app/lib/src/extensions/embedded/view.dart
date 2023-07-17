// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '_view_desktop.dart' if (dart.library.html) '_view_web.dart';
import 'controller.dart';

class EmbeddedExtensionView extends StatelessWidget {
  const EmbeddedExtensionView({Key? key, required this.controller})
      : super(key: key);

  final EmbeddedExtensionController controller;

  @override
  Widget build(BuildContext context) {
    return EmbeddedExtension(controller: controller);
  }
}
