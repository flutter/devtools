// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../shared/common_widgets.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/icons.dart';

abstract class MetadataChip extends StatelessWidget {
  const MetadataChip({
    super.key,
    required this.maxWidth,
    required this.text,
    this.icon,
    this.iconAsset,
    this.backgroundColor,
    this.foregroundColor,
    this.includeLeadingMargin = true,
  });

  final double maxWidth;
  final IconData? icon;
  final String? iconAsset;
  final String text;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool includeLeadingMargin;

  static const horizontalPadding = densePadding;
  static const verticalPadding = borderPadding;
  static const iconPadding = densePadding;
  static final height = scaleByFontFactor(18.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        this.backgroundColor ?? theme.colorScheme.secondaryContainer;
    final foregroundColor =
        this.foregroundColor ?? theme.colorScheme.onSecondaryContainer;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4.0),
      ),
      margin: includeLeadingMargin
          ? const EdgeInsets.only(left: denseSpacing)
          : null,
      padding: const EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null || iconAsset != null) ...[
            DevToolsIcon(
              icon: icon,
              iconAsset: iconAsset,
              size: defaultIconSize,
              color: foregroundColor,
            ),
            const SizedBox(width: iconPadding),
          ] else
            // Include an empty SizedBox to ensure a consistent height for the
            // chips, regardless of whether the chip includes an icon.
            SizedBox(height: defaultIconSize),
          RichText(
            text: TextSpan(
              text: text,
              style: theme.regularTextStyleWithColor(foregroundColor),
            ),
          ),
        ],
      ),
    );
  }
}

class KindMetaDataChip extends MetadataChip {
  const KindMetaDataChip({
    super.key,
    required String kind,
    required super.maxWidth,
    super.icon,
    super.iconAsset,
    super.backgroundColor,
    super.foregroundColor,
  }) : super(text: kind, includeLeadingMargin: false);

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

  static ({Color background, Color foreground}) generateColors(
    String kind,
    ColorScheme colorScheme,
  ) {
    Color background, foreground;
    if (kind == 'stderr' || kind.caseInsensitiveEquals(FlutterEvent.error)) {
      background = colorScheme.errorContainer;
      foreground = colorScheme.onErrorContainer;
    } else if (kind == 'stdout') {
      background = colorScheme.surfaceContainerHighest;
      foreground = colorScheme.onSurfaceVariant;
    } else if (kind.startsWith('flutter')) {
      background = colorScheme.primaryContainer;
      foreground = colorScheme.onPrimaryContainer;
    } else {
      background = colorScheme.secondaryContainer;
      foreground = colorScheme.onSecondaryContainer;
    }
    return (background: background, foreground: foreground);
  }
}

class FrameElapsedMetaDataChip extends MetadataChip {
  const FrameElapsedMetaDataChip({
    super.key,
    required super.maxWidth,
    required String elapsedTimeDisplay,
  }) : super(icon: Icons.timer, text: elapsedTimeDisplay);
}

class LogLevelMetadataChip extends MetadataChip {
  LogLevelMetadataChip({
    super.key,
    required Level level,
    required int rawLevel,
    required super.maxWidth,
    super.backgroundColor,
    super.foregroundColor,
  }) : super(text: 'Level.${level.name} ($rawLevel)');

  static Level generateLogLevel(int rawLevel) {
    var level = Level.FINEST;
    for (final l in Level.LEVELS) {
      if (rawLevel >= l.value) {
        level = l;
      }
    }
    return level;
  }

  static ({Color background, Color foreground}) generateColors(
    Level level,
    ColorScheme colorScheme,
  ) {
    Color background, foreground;
    if (level >= Level.SHOUT) {
      background = colorScheme.errorContainer.darken(0.2);
      foreground = colorScheme.onErrorContainer;
    } else if (level >= Level.SEVERE) {
      background = colorScheme.errorContainer;
      foreground = colorScheme.onErrorContainer;
    } else if (level >= Level.WARNING) {
      background = colorScheme.warningContainer;
      foreground = colorScheme.onWarningContainer;
    } else if (level >= Level.INFO) {
      background = colorScheme.secondaryContainer;
      foreground = colorScheme.onSecondaryContainer;
    } else {
      // This includes Level.CONFIG, Level.FINE, Level.FINER, Level.FINEST.
      background = colorScheme.surfaceContainerHighest;
      foreground = colorScheme.onSurfaceVariant;
    }
    return (background: background, foreground: foreground);
  }
}
