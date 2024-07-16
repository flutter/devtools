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
    return Theme.of(navigatorKey.currentContext!).subtleTextStyle;
  }

  static TextStyle get detailsStyle =>
      Theme.of(navigatorKey.currentContext!).regularTextStyle;

  /// All of the metatadata chits that can be visible for this [data] entry.
  @visibleForTesting
  static List<MetadataChit> metadataChits(LogDataV2 data, double maxWidth) {
    final allChits = [
      WhenMetaDataChit(
        data: data,
        maxWidth: maxWidth,
      ),
      KindMetaDataChit(
        data: data,
        maxWidth: maxWidth,
      ),
      FrameElapsedMetaDataChit(
        data: data,
        maxWidth: maxWidth,
      ),
    ];
    return allChits.where((chit) => chit.isPresent()).toList();
  }

  @override
  State<LoggingTableRow> createState() => _LoggingTableRowState();

  static final _padding = scaleByFontFactor(8.0);

  /// Estimates the height of the row, including the details section and all of the metadatachits.
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

  /// Estimates the height that the [metadataChits] will occupy if they are
  /// the children of a [Wrap] widget with a parent of [maxWidth] width.
  @visibleForTesting
  static double estimateMetaDataWrapHeight(LogDataV2 data, double maxWidth) {
    double totalHeight = 0.0;
    double rowHeight = 0.0;
    double remainingWidth = maxWidth;

    for (final presentChit in LoggingTableRow.metadataChits(data, maxWidth)) {
      final chitSize = presentChit.estimateSize();
      if (chitSize.width > remainingWidth) {
        // The chit does not fit so add it to a new row
        totalHeight += rowHeight;
        rowHeight = 0.0;
        remainingWidth = maxWidth;
      }

      // The Chit fits so it will stay in this row.
      rowHeight = max(rowHeight, chitSize.height);
      remainingWidth -= chitSize.width;
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
                      children: LoggingTableRow.metadataChits(
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
abstract class MetadataChit extends StatelessWidget {
  const MetadataChit({
    super.key,
    required this.data,
    required this.maxWidth,
  });

  final LogDataV2 data;
  final double maxWidth;
  static const padding = defaultSpacing;

  /// The text value to be displayed for this chit.
  String getValue();

  /// Whether or not [data] has the information to display this chit.
  bool isPresent();

  /// The icon that will be shown with the chit.
  IconData getIcon();

  /// The textspan which will be displayed in the chit.
  TextSpan textSpan() {
    return TextSpan(
      text: getValue(),
      style: LoggingTableRow.metadataStyle,
    );
  }

  /// Estimates the size of this single metadata chit.
  ///
  /// If the [build] method is changed then this may need to be updated
  Size estimateSize() {
    final maxWidthInsidePadding = maxWidth - padding * 2;
    final iconSize = Size.square(tooltipIconSize);
    final textSize = calculateTextSpanSize(
      textSpan(),
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
            getIcon(),
            size: tooltipIconSize,
          ),
          const SizedBox(width: defaultSpacing),
          RichText(
            text: textSpan(),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class WhenMetaDataChit extends MetadataChit {
  const WhenMetaDataChit({
    super.key,
    required super.data,
    required super.maxWidth,
  });

  @override
  IconData getIcon() => Icons.punch_clock;

  @override
  String getValue() => data.timestamp == null
      ? ''
      : loggingTableTimeFormat
          .format(DateTime.fromMillisecondsSinceEpoch(data.timestamp!));

  @override
  bool isPresent() {
    return data.timestamp != null;
  }
}

@visibleForTesting
class KindMetaDataChit extends MetadataChit {
  const KindMetaDataChit({
    super.key,
    required super.data,
    required super.maxWidth,
  });

  @override
  IconData getIcon() => Icons.type_specimen;

  @override
  String getValue() => data.kind;

  @override
  bool isPresent() {
    return true;
  }
}

@visibleForTesting
class FrameElapsedMetaDataChit extends MetadataChit {
  const FrameElapsedMetaDataChit({
    super.key,
    required super.data,
    required super.maxWidth,
  });

  @override
  IconData getIcon() => Icons.timer;

  String? _getValue() {
    double? frameLength;
    try {
      final int micros = (jsonDecode(data.details!) as Map)['elapsed'];
      frameLength = micros * 3.0 / 1000.0;
    } catch (e) {
      // ignore
    }
    return frameLength?.toString();
  }

  @override
  String getValue() {
    return _getValue() ?? '';
  }

  @override
  bool isPresent() {
    return _getValue() != null;
  }
}
