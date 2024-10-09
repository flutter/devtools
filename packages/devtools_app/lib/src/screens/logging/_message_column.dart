// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app_shared/service.dart' show FlutterEvent;
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import 'logging_controller.dart';

@visibleForTesting
class MessageColumn extends ColumnData<LogData>
    implements ColumnRenderer<LogData> {
  MessageColumn() : super.wide('Message');

  @override
  bool get supportsSorting => false;

  @override
  String getValue(LogData dataObject) =>
      dataObject.summary ?? dataObject.details ?? '';

  @override
  int compare(LogData a, LogData b) {
    final valueA = getValue(a);
    final valueB = getValue(b);
    // Matches frame descriptions (e.g. '#12  11.4ms ')
    final regex = RegExp(r'#(\d+)\s+\d+.\d+ms\s*');
    final valueAIsFrameLog = valueA.startsWith(regex);
    final valueBIsFrameLog = valueB.startsWith(regex);
    if (valueAIsFrameLog && valueBIsFrameLog) {
      final frameNumberA = regex.firstMatch(valueA)![1]!;
      final frameNumberB = regex.firstMatch(valueB)![1]!;
      return int.parse(frameNumberA).compareTo(int.parse(frameNumberB));
    } else if (valueAIsFrameLog && !valueBIsFrameLog) {
      return -1;
    } else if (!valueAIsFrameLog && valueBIsFrameLog) {
      return 1;
    }
    return valueA.compareTo(valueB);
  }

  @override
  Widget build(
    BuildContext context,
    LogData data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    final hasSummary = !data.summary.isNullOrEmpty;
    // This needs to be a function because the details may be computed after the
    // initial build.
    bool hasDetails() => !data.details.isNullOrEmpty;

    if (data.kind.caseInsensitiveEquals(FlutterEvent.frame)) {
      const color = Color.fromARGB(0xff, 0x00, 0x91, 0xea);
      final text = Text(
        getDisplayValue(data),
        overflow: TextOverflow.ellipsis,
      );

      double frameLength = 0.0;
      try {
        final int micros = (jsonDecode(data.details!) as Map)['elapsed'];
        frameLength = micros * 3.0 / 1000.0;
      } catch (e) {
        // ignore
      }

      return Row(
        children: <Widget>[
          text,
          Flexible(
            child: Container(
              height: 12.0,
              width: frameLength,
              decoration: const BoxDecoration(color: color),
            ),
          ),
        ],
      );
    } else {
      return ValueListenableBuilder<bool>(
        valueListenable: data.detailsComputed,
        builder: (context, detailsComputed, _) {
          return RichText(
            text: TextSpan(
              children: [
                if (hasSummary)
                  ...processAnsiTerminalCodes(
                    // TODO(helin24): Recompute summary length considering ansi codes.
                    //  The current summary is generally the first 200 chars of details.
                    data.summary!,
                    theme.regularTextStyle,
                  ),
                if (hasSummary && hasDetails())
                  WidgetSpan(
                    child: Icon(
                      Icons.arrow_right,
                      size: defaultIconSize,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                if (hasDetails())
                  ...processAnsiTerminalCodes(
                    detailsComputed ? data.details! : '<fetching>',
                    theme.subtleTextStyle,
                  ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          );
        },
      );
    }
  }
}
