// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/globals.dart';
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

    return [
      if (data.timestamp != null)
        WhenMetaDataChip(
          data: data,
          maxWidth: maxWidth,
        ),
      KindMetaDataChip(
        data: data,
        maxWidth: maxWidth,
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

  static final _padding = scaleByFontFactor(8.0);

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
            padding: EdgeInsets.all(LoggingTableRow._padding),
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
    required this.icon,
    required this.text,
  });

  final LogDataV2 data;
  final double maxWidth;
  final IconData icon;
  final String text;

  static const padding = defaultSpacing;

  /// Estimates the size of this single metadata chip.
  ///
  /// If the [build] method is changed then this may need to be updated
  Size estimateSize() {
    final maxWidthInsidePadding = maxWidth - padding * 2;
    final iconSize = Size.square(tooltipIconSize);
    final textSize = calculateTextSpanSize(
      _buildValueText(),
      maxWidth: maxWidthInsidePadding,
    );
    return Size(
      iconSize.width + defaultSpacing + textSize.width + padding * 2,
      max(iconSize.height, textSize.height) + padding * 2,
    );
  }

  /// If this build method is changed then you may need to modify [estimateSize()]
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(padding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: tooltipIconSize,
          ),
          const SizedBox(width: defaultSpacing),
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
          icon: Icons.punch_clock,
          text: data.timestamp == null
              ? ''
              : loggingTableTimeFormat
                  .format(DateTime.fromMillisecondsSinceEpoch(data.timestamp!)),
        );
}

@visibleForTesting
class KindMetaDataChip extends MetadataChip {
  KindMetaDataChip({
    super.key,
    required super.data,
    required super.maxWidth,
  }) : super(icon: Icons.type_specimen, text: data.kind);
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
