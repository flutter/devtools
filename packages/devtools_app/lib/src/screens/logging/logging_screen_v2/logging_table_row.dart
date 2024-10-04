// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/globals.dart';
import '../../../shared/ui/icons.dart';
import '../../../shared/ui/utils.dart';
import 'logging_controller_v2.dart';

final loggingTableTimeFormat = DateFormat('HH:mm:ss.SSS');

class LoggingTableRow extends StatefulWidget {
  const LoggingTableRow({
    super.key,
    required this.index,
    required this.data,
    required this.isSelected,
  });

  final int index;

  final LogDataV2 data;

  final bool isSelected;

  static TextStyle get metadataStyle {
    final currentContext = navigatorKey.currentContext;
    assert(
      currentContext != null,
      'LoggingTableRow.metadataStyle requires a valid navigatorKey to be set. If this assertion is hit in tests then make sure to `wrap()` the widget being pumped.',
    );
    return Theme.of(currentContext!).subtleTextStyle;
  }

  static TextStyle get detailsStyle =>
      Theme.of(navigatorKey.currentContext!).regularTextStyle;

  /// All of the metatadata chips that can be visible for this [data] entry.
  @visibleForTesting
  static List<MetadataChip> metadataChips(LogDataV2 data, double maxWidth) {
    String? elapsedFrameTimeAsString;
    try {
      final int micros = (jsonDecode(data.details!) as Map)['elapsed'];
      elapsedFrameTimeAsString = (micros * 3.0 / 1000.0).toString();
    } catch (e) {
      // Ignore exception; [elapsedFrameTimeAsString] will be null.
    }

    final kindIcon = KindMetaDataChip.generateIcon(data.kind);
    return [
      if (data.timestamp != null)
        WhenMetaDataChip(
          data: data,
          maxWidth: maxWidth,
        ),
      KindMetaDataChip(
        data: data,
        maxWidth: maxWidth,
        icon: kindIcon.icon,
        iconAsset: kindIcon.iconAsset,
      ),
      if (elapsedFrameTimeAsString != null)
        FrameElapsedMetaDataChip(
          data: data,
          maxWidth: maxWidth,
          elapsedTimeDisplay: elapsedFrameTimeAsString,
        ),
    ];
  }

  @override
  State<LoggingTableRow> createState() => _LoggingTableRowState();

  static const _padding = densePadding;

  /// Estimates the height of the row, including the details section and all of the metadata chips.
  static double estimateRowHeight(
    LogDataV2 log,
    double width,
  ) {
    final text = log.asLogDetails();
    final maxWidth = max(0.0, width - _padding * 2);

    final row1Height = calculateTextSpanHeight(
      TextSpan(text: text, style: detailsStyle),
      maxWidth: maxWidth,
    );

    final row2Height = estimateMetaDataWrapHeight(log, maxWidth);

    return row1Height + row2Height + _padding * 2;
  }

  /// Estimates the height that the [metadataChips] will occupy if they are
  /// the children of a [Wrap] widget with a parent of [maxWidth] width.
  @visibleForTesting
  static double estimateMetaDataWrapHeight(LogDataV2 data, double maxWidth) {
    var totalHeight = 0.0;
    var rowHeight = 0.0;
    var remainingWidth = maxWidth;

    for (final presentChip in LoggingTableRow.metadataChips(data, maxWidth)) {
      final chipSize = presentChip.estimateSize();
      if (chipSize.width > remainingWidth) {
        // The chip does not fit so add it to a new row
        totalHeight += rowHeight;
        rowHeight = 0.0;
        remainingWidth = maxWidth;
      }

      // The Chip fits so it will stay in this row.
      rowHeight = max(rowHeight, chipSize.height);
      remainingWidth -= chipSize.width;
    }

    totalHeight += rowHeight;
    return totalHeight;
  }
}

class _LoggingTableRowState extends State<LoggingTableRow> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = widget.isSelected
        ? colorScheme.selectedRowBackgroundColor
        : alternatingColorForIndex(
            widget.index,
            colorScheme,
          );

    return Container(
      color: color,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.data.detailsComputed,
        builder: (context, _, __) {
          return Padding(
            padding: const EdgeInsets.all(LoggingTableRow._padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    text: widget.data.asLogDetails(),
                    style: LoggingTableRow.detailsStyle,
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      children: LoggingTableRow.metadataChips(
                        widget.data,
                        constraints.maxWidth,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

@visibleForTesting
abstract class MetadataChip extends StatelessWidget {
  const MetadataChip({
    super.key,
    required this.data,
    required this.maxWidth,
    required this.text,
    this.icon,
    this.iconAsset,
    this.includeLeadingPadding = true,
  });

  final LogDataV2 data;
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
    required super.data,
    required super.maxWidth,
  }) : super(
          icon: null,
          text: data.timestamp == null
              ? ''
              : loggingTableTimeFormat
                  .format(DateTime.fromMillisecondsSinceEpoch(data.timestamp!)),
          includeLeadingPadding: false,
        );
}

@visibleForTesting
class KindMetaDataChip extends MetadataChip {
  KindMetaDataChip({
    super.key,
    required super.data,
    required super.maxWidth,
    super.icon,
    super.iconAsset,
  }) : super(text: data.kind);

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
    required super.data,
    required super.maxWidth,
    required String elapsedTimeDisplay,
  }) : super(icon: Icons.timer, text: elapsedTimeDisplay);
}
