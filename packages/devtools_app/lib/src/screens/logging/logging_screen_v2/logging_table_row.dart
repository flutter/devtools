// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../devtools_app.dart';
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
      Theme.of(DevToolsAppState.navigatorKey.currentContext!).subtleTextStyle;

  static TextStyle get detailsStyle =>
      Theme.of(DevToolsAppState.navigatorKey.currentContext!).regularTextStyle;

  @override
  State<LoggingTableRow> createState() => _LoggingTableRowState();

  static final _padding = scaleByFontFactor(8.0);

  static double calculateRowHeight(
    BuildContext context,
    LogDataV2 log,
    double width,
  ) {
    final text = log.asLogDetails();

    final row1Height = calculateTextSpanHeight(
      TextSpan(text: text, style: detailsStyle),
      maxWidth: width - _padding * 2,
    );

    // TODO(danchevalier): Improve row2 height by manually flowing metadas into another row
    // if theyoverflow.
    final row2Height = calculateTextSpanHeight(
      TextSpan(text: text, style: metadataStyle),
      maxWidth: width - _padding * 2,
    );
    return row1Height + row2Height + _padding * 2;
  }
}

class _LoggingTableRowState extends State<LoggingTableRow> {
  @override
  Widget build(BuildContext context) {
    var color = alternatingColorForIndex(
      widget.index,
      Theme.of(context).colorScheme,
    );

    if (widget.isSelected) {
      color = Colors.blueGrey;
    }

    return Container(
      color: color,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.data.detailsComputed,
        builder: (context, _, __) {
          return Padding(
            padding: EdgeInsets.all(LoggingTableRow._padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: widget.data.asLogDetails(),
                    style: Theme.of(context).regularTextStyle,
                  ),
                ),
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Some META data',
                        style: Theme.of(context).subtleTextStyle,
                      ),
                    ),
                    SizedBox(width: defaultSpacing),
                    RichText(
                      text: TextSpan(
                        text: 'Some OTHER META data',
                        style: Theme.of(context).subtleTextStyle,
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
