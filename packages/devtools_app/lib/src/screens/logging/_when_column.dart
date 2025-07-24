// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '../../shared/table/table_data.dart';
import 'logging_controller.dart';

class WhenColumn extends ColumnData<LogData> {
  const WhenColumn() : super('When', fixedWidthPx: 80);

  @override
  bool get supportsSorting => false;

  @override
  bool get numeric => true;

  @override
  int getValue(LogData dataObject) => dataObject.timestamp ?? -1;

  @override
  String getDisplayValue(LogData dataObject) => dataObject.timestamp == null
      ? ''
      : timeFormat.format(
          DateTime.fromMillisecondsSinceEpoch(dataObject.timestamp!),
        );

  @override
  String getTooltip(LogData dataObject) => dataObject.timestamp == null
      ? ''
      : dateTimeFormat.format(
          DateTime.fromMillisecondsSinceEpoch(dataObject.timestamp!),
        );
}
