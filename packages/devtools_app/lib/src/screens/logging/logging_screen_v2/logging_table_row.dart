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

  static TextStyle get metadataStyle =>
      Theme.of(navigatorKey.currentContext!).subtleTextStyle;

  static TextStyle get detailsStyle =>
      Theme.of(navigatorKey.currentContext!).regularTextStyle;

  static List<_MetadataChit> _metadataChits(LogDataV2 data, double maxWidth) {
    //TODO: maxwidth - prevWidget on Line
    final allChits = [
      _WhenMetaDataChit(
        data: data,
        maxWidth: maxWidth,
      ),
      _KindMetaDataChit(
        data: data,
        maxWidth: maxWidth,
      ),
      _FrameElapsedMetaDataChit(
        data: data,
        maxWidth: maxWidth,
      ),
    ];
    return allChits.where((chit) => chit.isPresent()).toList();
  }

  @override
  State<LoggingTableRow> createState() => _LoggingTableRowState();

  static final _padding = scaleByFontFactor(8.0);

  static double calculateRowHeight(
    LogDataV2 log,
    double width,
  ) {
    final text = log.asLogDetails();
    final maxWidth = max(0.0, width - _padding * 2);

    final row1Height = calculateTextSpanHeight(
      TextSpan(text: text, style: detailsStyle),
      maxWidth: maxWidth,
    );
    print('bef rowHeight');
    final row2Height = _calculateMetaDataHeight(log, width);
    print('row2height: ${row2Height}');

    return row1Height + row2Height + _padding * 2;
  }

  static double _calculateMetaDataHeight(LogDataV2 data, double maxWidth) {
    double totalHeight = 0.0;
    double rowHeight = 0.0;
    double remainingWidth = maxWidth;
    print('------------------------\nSTATS:${[
      totalHeight,
      rowHeight,
      remainingWidth
    ]}');
    for (final presentChit in LoggingTableRow._metadataChits(data, maxWidth)) {
      final chitSize = presentChit.getSize();
      print('chitSize: ${chitSize}');
      if (chitSize.width > remainingWidth) {
        print('O1');
        // The chit does not fit so add it to a new row
        totalHeight += rowHeight;
        rowHeight = 0.0;
        remainingWidth = maxWidth;
      }

      print('O2');
      // The Chit fits so it will stay in this row.
      rowHeight = max(rowHeight, chitSize.height);
      remainingWidth -= chitSize.width;
      print('STATS:${[totalHeight, rowHeight, remainingWidth]}');
    }
    totalHeight += rowHeight;
    print('STATS:${[totalHeight, rowHeight, remainingWidth]}');
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
                      children: LoggingTableRow._metadataChits(
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

abstract class _MetadataChit extends StatelessWidget {
  const _MetadataChit({
    required this.data,
    required this.maxWidth,
  });

  final LogDataV2 data;
  final double maxWidth;
  static const padding = defaultSpacing;

  String getValue();
  bool isPresent();
  IconData getIcon();

  TextSpan textSpan() {
    return TextSpan(
      text: getValue(),
      style: LoggingTableRow.metadataStyle,
    );
  }

  Size getSize() {
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

  @override
  Widget build(BuildContext context) {
    print('maxWidth: $maxWidth');
    //TODO: tooltip ?
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

class _WhenMetaDataChit extends _MetadataChit {
  const _WhenMetaDataChit({required super.data, required super.maxWidth});

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

class _KindMetaDataChit extends _MetadataChit {
  const _KindMetaDataChit({required super.data, required super.maxWidth});

  @override
  IconData getIcon() => Icons.type_specimen;

  @override
  String getValue() => data.kind;

  @override
  bool isPresent() {
    return true;
  }
}

class _FrameElapsedMetaDataChit extends _MetadataChit {
  const _FrameElapsedMetaDataChit({
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
