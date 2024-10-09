// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/ui/icons.dart';
import '../../shared/ui/utils.dart';
import 'logging_screen_v2/logging_table_row.dart';
import 'shared/constants.dart';

// TODO(kenz): remove dependency on Logging V2 references.

abstract class MetadataChip extends StatelessWidget {
  const MetadataChip({
    super.key,
    required this.maxWidth,
    required this.text,
    this.icon,
    this.iconAsset,
    this.includeLeadingPadding = true,
  });

  final double maxWidth;
  final IconData? icon;
  final String? iconAsset;
  final String text;
  final bool includeLeadingPadding;

  static const horizontalPadding = denseSpacing;
  static const verticalPadding = densePadding;
  static const iconPadding = densePadding;

  /// Estimates the size of this single metadata chip.
  ///
  /// If the [build] method is changed then this may need to be updated
  Size estimateSize() {
    final horizontalPaddingCount = includeLeadingPadding ? 2 : 1;
    final maxWidthInsidePadding =
        max(0.0, maxWidth - horizontalPadding * horizontalPaddingCount);
    final iconSize = Size.square(defaultIconSize);
    final textSize = calculateTextSpanSize(
      _buildValueText(),
      maxWidth: maxWidthInsidePadding,
    );
    return Size(
      ((icon != null || iconAsset != null)
              ? iconSize.width + iconPadding
              : 0.0) +
          textSize.width +
          horizontalPadding * horizontalPaddingCount,
      max(iconSize.height, textSize.height) + verticalPadding * 2,
    );
  }

  /// If this build method is changed then you may need to modify [estimateSize()]
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: EdgeInsets.fromLTRB(
        includeLeadingPadding ? horizontalPadding : 0,
        verticalPadding,
        horizontalPadding,
        verticalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null || iconAsset != null) ...[
            DevToolsIcon(
              icon: icon,
              iconAsset: iconAsset,
              size: defaultIconSize,
              color: Theme.of(context).colorScheme.subtleTextColor,
            ),
            const SizedBox(width: iconPadding),
          ] else
            // Include an empty SizedBox to ensure a consistent height for the
            // chips, regardless of whether the chip includes an icon.
            SizedBox(height: defaultIconSize),
          RichText(
            text: _buildValueText(),
          ),
        ],
      ),
    );
  }

  TextSpan _buildValueText() {
    return TextSpan(
      text: text,
      style: LoggingTableRow.metadataStyle,
    );
  }
}

@visibleForTesting
class WhenMetaDataChip extends MetadataChip {
  WhenMetaDataChip({
    super.key,
    required int? timestamp,
    required super.maxWidth,
  }) : super(
          icon: null,
          text: timestamp == null
              ? ''
              : loggingTableTimeFormat
                  .format(DateTime.fromMillisecondsSinceEpoch(timestamp)),
          includeLeadingPadding: false,
        );
}

class KindMetaDataChip extends MetadataChip {
  const KindMetaDataChip({
    super.key,
    required String kind,
    required super.maxWidth,
    super.icon,
    super.iconAsset,
  }) : super(text: kind);

  static ({IconData? icon, String? iconAsset}) generateIcon(String kind) {
    IconData? kindIcon = Icons.list_rounded;
    String? kindIconAsset;
    if (kind == 'stdout' || kind == 'stderr') {
      kindIcon = Icons.terminal_rounded;
    } else if (RegExp(r'^flutter\..*$').hasMatch(kind)) {
      kindIconAsset = 'icons/flutter.png';
      kindIcon = null;
    }
    return (icon: kindIcon, iconAsset: kindIconAsset);
  }
}

@visibleForTesting
class FrameElapsedMetaDataChip extends MetadataChip {
  const FrameElapsedMetaDataChip({
    super.key,
    required super.maxWidth,
    required String elapsedTimeDisplay,
  }) : super(icon: Icons.timer, text: elapsedTimeDisplay);
}
