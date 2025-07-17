// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '_message_column.dart';
import '_when_column.dart';
import 'logging_controller.dart';

class LogsTable extends StatelessWidget {
  const LogsTable({
    super.key,
    required this.controller,
    required this.data,
    required this.selectionNotifier,
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
  });

  static const _logRowHeight = 45.0;

  final LoggingController controller;
  final List<LogData> data;
  final ValueNotifier<LogData?> selectionNotifier;
  final ValueListenable<List<LogData>> searchMatchesNotifier;
  final ValueListenable<LogData?> activeSearchMatchNotifier;

  static const whenColumn = WhenColumn();
  static const messageColumn = MessageColumn();
  static final columns = [whenColumn, messageColumn];

  @override
  Widget build(BuildContext context) {
    return SearchableFlatTable<LogData>(
      searchController: controller,
      keyFactory: (LogData data) => ValueKey<LogData>(data),
      data: data,
      dataKey: 'logs',
      autoScrollContent: true,
      startScrolledAtBottom: true,
      columns: columns,
      selectionNotifier: selectionNotifier,
      defaultSortColumn: whenColumn,
      defaultSortDirection: SortDirection.ascending,
      secondarySortColumn: messageColumn,
      rowHeight: _logRowHeight,
    );
  }
}
