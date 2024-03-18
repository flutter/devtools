// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'preferences.dart';

class MemoryPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  /// If true, android chart will be shown in addition to
  /// dart chart.
  final androidCollectionEnabled = ValueNotifier<bool>(false);
  static const _androidCollectionEnabledStorageId =
      'memory.androidCollectionEnabled';

  /// If false, mamory chart will be collapsed.
  final showChart = ValueNotifier<bool>(true);
  static const _showChartStorageId = 'memory.showChart';

  /// Number of references to request from vm service,
  /// when browsing references in console.
  final refLimitTitle = 'Limit for number of requested live instances.';
  final refLimit = ValueNotifier<int>(_defaultRefLimit);
  static const _defaultRefLimit = 100000;
  static const _refLimitStorageId = 'memory.refLimit';

  Future<void> init() async {
    addAutoDisposeListener(
      androidCollectionEnabled,
      () {
        storage.setValue(
          _androidCollectionEnabledStorageId,
          androidCollectionEnabled.value.toString(),
        );
        if (androidCollectionEnabled.value) {
          ga.select(
            gac.memory,
            gac.MemoryEvent.chartAndroid,
          );
        }
      },
    );
    androidCollectionEnabled.value = await boolValueFromStorage(
      _androidCollectionEnabledStorageId,
      defaultsTo: false,
    );

    addAutoDisposeListener(
      showChart,
      () {
        storage.setValue(
          _showChartStorageId,
          showChart.value.toString(),
        );

        ga.select(
          gac.memory,
          showChart.value
              ? gac.MemoryEvent.showChart
              : gac.MemoryEvent.hideChart,
        );
      },
    );
    showChart.value = await boolValueFromStorage(
      _showChartStorageId,
      defaultsTo: true,
    );

    addAutoDisposeListener(
      refLimit,
      () {
        storage.setValue(
          _refLimitStorageId,
          refLimit.value.toString(),
        );

        ga.select(
          gac.memory,
          gac.MemoryEvent.browseRefLimit,
        );
      },
    );
    refLimit.value =
        int.tryParse(await storage.getValue(_refLimitStorageId) ?? '') ??
            _defaultRefLimit;
  }
}
