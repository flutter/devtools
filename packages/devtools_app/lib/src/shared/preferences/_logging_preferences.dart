// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'preferences.dart';

class LoggingPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final retentionLimitTitle = 'Limit for the number of logs retained.';

  /// The number of logs to retain on the logging table.
  final retentionLimit = ValueNotifier<int>(_defaultRetentionLimit);

  /// The [LoggingDetailsFormat] to use when displaying a log in the log details
  /// view.
  final detailsFormat = ValueNotifier<LoggingDetailsFormat>(
    _defaultDetailsFormat,
  );

  /// The active filter tag for the logging screen.
  ///
  /// This value caches the most recent filter settings.
  final filterTag = ValueNotifier<String>('');

  static const _defaultRetentionLimit = 5000;
  static const _defaultDetailsFormat = LoggingDetailsFormat.text;

  static const _retentionLimitStorageId = 'logging.retentionLimit';

  @visibleForTesting
  static const detailsFormatStorageId = 'logging.detailsFormat';

  @visibleForTesting
  static const filterStorageId = 'logging.filter';

  @override
  Future<void> init() async {
    retentionLimit.value =
        int.tryParse(await storage.getValue(_retentionLimitStorageId) ?? '') ??
        _defaultRetentionLimit;
    addAutoDisposeListener(retentionLimit, () {
      storage.setValue(
        _retentionLimitStorageId,
        retentionLimit.value.toString(),
      );
      ga.select(
        gac.logging,
        gac.LoggingEvents.changeRetentionLimit.name,
        value: retentionLimit.value,
      );
    });

    final detailsFormatValueFromStorage = await storage.getValue(
      detailsFormatStorageId,
    );
    detailsFormat.value =
        LoggingDetailsFormat.values.firstWhereOrNull(
          (value) => detailsFormatValueFromStorage == value.name,
        ) ??
        _defaultDetailsFormat;
    addAutoDisposeListener(detailsFormat, () {
      storage.setValue(detailsFormatStorageId, detailsFormat.value.name);
      ga.select(
        gac.logging,
        gac.LoggingEvents.changeDetailsFormat.name,
        value: detailsFormat.value.index,
      );
    });

    filterTag.value = await storage.getValue(filterStorageId) ?? '';
    addAutoDisposeListener(
      filterTag,
      () => storage.setValue(filterStorageId, filterTag.value),
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
