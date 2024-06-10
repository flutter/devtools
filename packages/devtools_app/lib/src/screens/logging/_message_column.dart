// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

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
    if (data.kind == 'flutter.frame') {
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
      return RichText(
        text: TextSpan(
          children: processAnsiTerminalCodes(
            // TODO(helin24): Recompute summary length considering ansi codes.
            //  The current summary is generally the first 200 chars of details.
            getDisplayValue(data),
            Theme.of(context).regularTextStyle,
          ),
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }
  }
}
