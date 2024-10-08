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

  /// All of the metatadata chips that can be visible for this [data] entry.
  @visibleForTesting
  static List<MetadataChip> metadataChips(
    LogData data,
    double maxWidth, {
    required ColorScheme colorScheme,
  }) {
    String? elapsedFrameTimeAsString;
    try {
      final int micros = (jsonDecode(data.details!) as Map)['elapsed'];
      elapsedFrameTimeAsString = (micros * 3.0 / 1000.0).toString();
    } catch (e) {
      // Ignore exception; [elapsedFrameTimeAsString] will be null.
    }

    final kindIcon = KindMetaDataChip.generateIcon(data.kind);
    final kindColors = KindMetaDataChip.generateColors(data.kind, colorScheme);
    return [
      KindMetaDataChip(
        kind: data.kind,
        maxWidth: maxWidth,
        icon: kindIcon.icon,
        iconAsset: kindIcon.iconAsset,
        backgroundColor: kindColors.background,
        foregroundColor: kindColors.foreground,
      ),
      if (data.level != null)
        () {
          final logLevel = LogLevelMetadataChip.generateLogLevel(data.level!);
          final logLevelColors = LogLevelMetadataChip.generateColors(
            logLevel,
            colorScheme,
          );
          return LogLevelMetadataChip(
            level: logLevel,
            rawLevel: data.level!,
            maxWidth: maxWidth,
            backgroundColor: logLevelColors.background,
            foregroundColor: logLevelColors.foreground,
          );
        }(),
      if (elapsedFrameTimeAsString != null)
        FrameElapsedMetaDataChip(
          maxWidth: maxWidth,
          elapsedTimeDisplay: elapsedFrameTimeAsString,
        ),
    ];
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
    final hasDetails = !data.details.isNullOrEmpty;
    return ValueListenableBuilder<bool>(
      valueListenable: data.detailsComputed,
      builder: (context, detailsComputed, __) {
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
                      ...processAnsiTerminalCodes(
                        // TODO(helin24): Recompute summary length considering ansi codes.
                        //  The current summary is generally the first 200 chars of details.
                        data.summary!,
                        theme.regularTextStyle,
                      ),
                    if (hasSummary && hasDetails)
                      WidgetSpan(
                        child: Icon(
                          Icons.arrow_right,
                          size: defaultIconSize,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    if (hasDetails)
                      ...processAnsiTerminalCodes(
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
              padding: const EdgeInsets.only(
                top: borderPadding,
                bottom: densePadding,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    children: metadataChips(
                      data,
                      constraints.maxWidth,
                      colorScheme: theme.colorScheme,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
