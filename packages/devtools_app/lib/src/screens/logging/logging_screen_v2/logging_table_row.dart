// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/globals.dart';
import '../../../shared/ui/utils.dart';
import 'logging_controller_v2.dart';

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

    // TODO(danchevalier): Improve row2 height by manually flowing metadas into another row
    // if theyoverflow.
    final row2Height = calculateTextSpanHeight(
      TextSpan(text: 'short text for now', style: metadataStyle),
      maxWidth: maxWidth,
    );

    return row1Height + row2Height + _padding * 2;
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
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Some META data',
                        style: LoggingTableRow.metadataStyle,
                      ),
                    ),
                    const SizedBox(width: defaultSpacing),
                    RichText(
                      text: TextSpan(
                        text: 'Some OTHER META data',
                        style: LoggingTableRow.metadataStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
