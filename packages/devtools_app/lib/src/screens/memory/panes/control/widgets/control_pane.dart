// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/framework/screen.dart';
import '../../../../../shared/ui/common_widgets.dart';
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
      controlsBuilder:
          (_) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const PrimaryControls(),
              const Spacer(),
              SecondaryControls(isGcing: isGcing, onGc: onGc, onSave: onSave),
            ],
          ),
      gaScreen: ScreenMetaData.memory.id,
    );
  }
}
