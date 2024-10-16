// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'preferences.dart';

class LoggingPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final retentionLimitTitle = 'Limit for the number of logs retained.';

  // TODO(kenz): remove the retention limit setting if we cannot apply this
  // functionality to the existing logging page, since the logging V2 code may
  // be removed.
  /// The number of logs to retain on the logging table.
  final retentionLimit = ValueNotifier<int>(_defaultRetentionLimit);

  /// The [LoggingDetailsFormat] to use when displaying a log in the log details
  /// view.
  final detailsFormat =
      ValueNotifier<LoggingDetailsFormat>(_defaultDetailsFormat);

  static const _defaultRetentionLimit = 3000;
  static const _defaultDetailsFormat = LoggingDetailsFormat.text;

  static const _retentionLimitStorageId = 'logging.retentionLimit';
  static const _detailsFormatStorageId = 'logging.detailsFormat';

  Future<void> init() async {
    retentionLimit.value =
        int.tryParse(await storage.getValue(_retentionLimitStorageId) ?? '') ??
            _defaultRetentionLimit;

    addAutoDisposeListener(
      retentionLimit,
      () {
        storage.setValue(
          _retentionLimitStorageId,
          retentionLimit.value.toString(),
        );
        ga.select(
          gac.logging,
          gac.LoggingEvents.changeRetentionLimit.name,
          value: retentionLimit.value,
        );
      },
    );

    final detailsFormatValueFromStorage =
        await storage.getValue(_detailsFormatStorageId);
    detailsFormat.value = LoggingDetailsFormat.values.firstWhereOrNull(
          (value) => detailsFormatValueFromStorage == value.name,
        ) ??
        _defaultDetailsFormat;

    addAutoDisposeListener(
      detailsFormat,
      () {
        storage.setValue(_detailsFormatStorageId, detailsFormat.value.name);
        ga.select(
          gac.logging,
          gac.LoggingEvents.changeDetailsFormat.name,
          value: detailsFormat.value.index,
        );
      },
    );
  }
}

enum LoggingDetailsFormat {
  json,
  text;

  LoggingDetailsFormat opposite() {
    switch (this) {
      case LoggingDetailsFormat.json:
        return LoggingDetailsFormat.text;
      case LoggingDetailsFormat.text:
        return LoggingDetailsFormat.json;
    }
  }
}
