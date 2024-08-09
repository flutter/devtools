// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/screen.dart';
import 'primary_controls.dart';
import 'secondary_controls.dart';

class MemoryControlPane extends StatelessWidget {
  const MemoryControlPane({
    super.key,
    required this.isGcing,
    required this.onGc,
    required this.onSave,
  });

  final VoidCallback onGc;
  final VoidCallback onSave;
  final ValueListenable<bool> isGcing;

  @override
  Widget build(BuildContext context) {
    // OfflineAwareControls are here to enable button to exit offline mode.
    return OfflineAwareControls(
      controlsBuilder: (_) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const PrimaryControls(),
          const Spacer(),
          SecondaryControls(
            isGcing: isGcing,
            onGc: onGc,
            onSave: onSave,
          ),
        ],
      ),
      gaScreen: ScreenMetaData.memory.id,
    );
  }
}
