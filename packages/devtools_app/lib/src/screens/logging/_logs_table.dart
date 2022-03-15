// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../primitives/utils.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '_kind_column.dart';
import '_message_column.dart';
import '_when_column.dart';
import 'logging_controller.dart';

class LogsTable extends StatelessWidget {
  LogsTable({
    Key? key,
    required this.data,
    required this.onItemSelected,
    required this.selectionNotifier,
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
  }) : super(key: key);

  final List<LogData> data;
  final ItemCallback<LogData> onItemSelected;
  final ValueListenable<LogData?> selectionNotifier;
  final ValueListenable<List<LogData>> searchMatchesNotifier;
  final ValueListenable<LogData?> activeSearchMatchNotifier;

  final ColumnData<LogData> when = WhenColumn();
  final ColumnData<LogData> kind = KindColumn();
  final ColumnData<LogData> message = MessageColumn();

  List<ColumnData<LogData>> get columns => [when, kind, message];

  @override
  Widget build(BuildContext context) {
    return FlatTable<LogData>(
      columns: columns,
      data: data,
      autoScrollContent: true,
      keyFactory: (LogData data) => ValueKey<LogData>(data),
      onItemSelected: onItemSelected,
      selectionNotifier: selectionNotifier,
      sortColumn: when,
      secondarySortColumn: message,
      sortDirection: SortDirection.ascending,
      searchMatchesNotifier: searchMatchesNotifier,
      activeSearchMatchNotifier: activeSearchMatchNotifier,
    );
  }
}
