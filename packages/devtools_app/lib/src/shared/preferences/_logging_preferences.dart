// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'preferences.dart';

class LoggingPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final retentionLimitTitle = 'Limit for the number of logs retained.';

  /// The number of logs to retain on the logging table.
  final retentionLimit = ValueNotifier<int>(_defaultRetentionLimit);

  static const _defaultRetentionLimit = 3000;

  static const _retentionLimitStorageId = 'logging.retentionLimit';

  Future<void> init() async {
    addAutoDisposeListener(
      retentionLimit,
      () {
        storage.setValue(
          _retentionLimitStorageId,
          retentionLimit.value.toString(),
        );

        ga.select(
          gac.logging,
          gac.LoggingEvent.changeRetentionLimit,
          value: retentionLimit.value,
        );
      },
    );
    retentionLimit.value =
        int.tryParse(await storage.getValue(_retentionLimitStorageId) ?? '') ??
            _defaultRetentionLimit;
  }
}
