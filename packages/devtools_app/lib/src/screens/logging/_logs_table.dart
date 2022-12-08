// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '_kind_column.dart';
import '_message_column.dart';
import '_when_column.dart';
import 'logging_controller.dart';

class LogsTable extends StatelessWidget {
  const LogsTable({
    Key? key,
    required this.data,
    required this.selectionNotifier,
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
  }) : super(key: key);

  final List<LogData> data;
  final ValueNotifier<LogData?> selectionNotifier;
  final ValueListenable<List<LogData>> searchMatchesNotifier;
  final ValueListenable<LogData?> activeSearchMatchNotifier;

  static final ColumnData<LogData> when = WhenColumn();
  static final ColumnData<LogData> kind = KindColumn();
  static final ColumnData<LogData> message = MessageColumn();
  static final List<ColumnData<LogData>> columns = [when, kind, message];

  @override
  Widget build(BuildContext context) {
    return FlatTable<LogData>(
      keyFactory: (LogData data) => ValueKey<LogData>(data),
      data: data,
      dataKey: 'logs',
      autoScrollContent: true,
      searchMatchesNotifier: searchMatchesNotifier,
      activeSearchMatchNotifier: activeSearchMatchNotifier,
      columns: columns,
      selectionNotifier: selectionNotifier,
      defaultSortColumn: when,
      defaultSortDirection: SortDirection.ascending,
      secondarySortColumn: message,
    );
  }
}
