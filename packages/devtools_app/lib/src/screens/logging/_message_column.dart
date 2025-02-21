// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import 'logging_controller.dart';
import 'metadata.dart';

class MessageColumn extends ColumnData<LogData>
    implements ColumnRenderer<LogData> {
  MessageColumn() : super.wide('Log');

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

    return FutureBuilder<bool>(
      future: data.detailsComputed.future,
      builder: (context, _) {
        final detailsComputed = data.detailsComputed.isCompleted;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: borderPadding),
              child: RichText(
                text: TextSpan(
                  children: [
                    if (hasSummary)
                      ...textSpansFromAnsi(
                        // TODO(helin24): Recompute summary length considering ansi codes.
                        //  The current summary is generally the first 200 chars of details.
                        data.summary!,
                        theme.regularTextStyle,
                      ),
                    if (hasSummary && hasDetails())
                      TextSpan(text: '  •  ', style: theme.subtleTextStyle),
                    if (hasDetails())
                      ...textSpansFromAnsi(
                        detailsComputed ? data.details! : '<fetching>',
                        theme.subtleTextStyle,
                      ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: densePadding),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return MetadataChips(data: data);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
