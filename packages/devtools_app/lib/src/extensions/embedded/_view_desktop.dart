// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import 'controller.dart';

class EmbeddedExtension extends StatelessWidget {
  const EmbeddedExtension({super.key, required this.controller});

  final EmbeddedExtensionController controller;

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): if web view support for desktop is ever added, use that here.
    return const Center(
      child: Text(
        'Cannot display the DevTools extension.'
        ' IFrames are not supported on desktop platforms.',
      ),
    );
  }
}
