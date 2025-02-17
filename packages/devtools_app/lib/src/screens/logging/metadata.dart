// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../shared/primitives/utils.dart';
import 'logging_controller.dart';

class MetadataChips extends StatelessWidget {
  const MetadataChips({super.key, required this.data});

  final LogData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Prepare kind chip.
    final kindIcon = KindMetaDataChip.generateIcon(data.kind);
    final kindColors = KindMetaDataChip.generateColors(data.kind, colorScheme);

    // Prepare log level chip.
    final logLevel = LogLevelMetadataChip.generateLogLevel(data.level);
    final logLevelColors = LogLevelMetadataChip.generateColors(
      logLevel,
      colorScheme,
    );
    final logLevelChip = LogLevelMetadataChip(
      level: logLevel,
      rawLevel: data.level,
      backgroundColor: logLevelColors.background,
      foregroundColor: logLevelColors.foreground,
    );

    // Prepare the isolate chip.
    Widget? isolateChip;
    final isolateName = data.isolateRef?.name;
    if (isolateName != null) {
      isolateChip = IsolateChip(
        name: isolateName,
        id: data.isolateRef?.id,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        outlined: true,
      );
    }

    // Prepare the zone chip.
    Widget? zoneChip;
    final zone = data.zone;
    final zoneName = zone?.name;
    if (zoneName != null && !zoneName.caseInsensitiveEquals('null')) {
      zoneChip = ZoneChip(
        name: zoneName,
        identityHashCode: zone!.identityHashCode,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        outlined: true,
      );
    }

    // Prepare frame time chip.
    String? elapsedFrameTimeAsString;
    try {
      if (data.details != null) {
        final int? micros = (jsonDecode(data.details!) as Map)['elapsed'];
        if (micros != null) {
          elapsedFrameTimeAsString = durationText(
            Duration(microseconds: micros),
            unit: DurationDisplayUnit.milliseconds,
            fractionDigits: 2,
          );
        }
      }
    } catch (e) {
      // Ignore exception; [elapsedFrameTimeAsString] will be null.
    }

    return Wrap(
      children: [
        KindMetaDataChip(
          kind: data.kind,
          icon: kindIcon.icon,
          iconAsset: kindIcon.iconAsset,
          backgroundColor: kindColors.background,
          foregroundColor: kindColors.foreground,
        ),
        logLevelChip,
        if (elapsedFrameTimeAsString != null)
          FrameElapsedMetaDataChip(
            elapsedTimeDisplay: elapsedFrameTimeAsString,
          ),
        if (isolateChip != null) isolateChip,
        if (zoneChip != null) zoneChip,
      ],
    );
  }
}

abstract class MetadataChip extends StatelessWidget {
  const MetadataChip({
    super.key,
    required this.text,
    this.tooltip,
    this.icon,
    this.iconAsset,
    this.backgroundColor,
    this.foregroundColor,
    this.outlined = false,
    this.includeLeadingMargin = true,
  });

  final IconData? icon;
  final String? iconAsset;
  final String text;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool outlined;
  final bool includeLeadingMargin;

  static const horizontalPadding = densePadding;
  static const verticalPadding = borderPadding;
  static const iconPadding = densePadding;
  static const _borderRadius = 4.0;
  static final _metadataIconSize = scaleByFontFactor(12.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        this.backgroundColor ?? theme.colorScheme.secondaryContainer;
    final foregroundColor =
        this.foregroundColor ?? theme.colorScheme.onSecondaryContainer;

    return maybeWrapWithTooltip(
      tooltip: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(_borderRadius),
          border:
              outlined
                  ? Border.all(color: theme.colorScheme.subtleTextColor)
                  : null,
        ),
        margin:
            includeLeadingMargin
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
                size: _metadataIconSize,
                color: foregroundColor,
              ),
              const SizedBox(width: iconPadding),
            ] else
              // Include an empty SizedBox to ensure a consistent height for the
              // chips, regardless of whether the chip includes an icon.
              SizedBox(height: _metadataIconSize),
            RichText(
              text: TextSpan(
                text: text,
                style: theme
                    .regularTextStyleWithColor(foregroundColor)
                    .copyWith(fontSize: smallFontSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KindMetaDataChip extends MetadataChip {
  const KindMetaDataChip({
    super.key,
    required String kind,
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
    required String elapsedTimeDisplay,
  }) : super(icon: Icons.timer, text: elapsedTimeDisplay);
}

class LogLevelMetadataChip extends MetadataChip {
  LogLevelMetadataChip({
    super.key,
    required Level level,
    required int rawLevel,
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

class IsolateChip extends MetadataChip {
  const IsolateChip({
    super.key,
    required String name,
    required String? id,
    super.backgroundColor,
    super.foregroundColor,
    super.outlined = false,
  }) : super(text: 'isolate: $name', tooltip: id);
}

class ZoneChip extends MetadataChip {
  const ZoneChip({
    super.key,
    required String name,
    required int? identityHashCode,
    super.backgroundColor,
    super.foregroundColor,
    super.outlined = false,
  }) : super(
         text: name,
         tooltip:
             identityHashCode != null
                 ? 'Zone identityHashCode: $identityHashCode'
                 : null,
       );
}
