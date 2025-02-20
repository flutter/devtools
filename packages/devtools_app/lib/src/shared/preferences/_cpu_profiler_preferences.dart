// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'preferences.dart';

class CpuProfilerPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  /// The active filter tag for the cpu profiler screen.
  ///
  /// This value caches the most recent filter settings.
  final filterTag = ValueNotifier<String>('');

  @visibleForTesting
  static const filterStorageId = 'cpuProfiler.filter';

  @override
  Future<void> init() async {
    filterTag.value = await storage.getValue(filterStorageId) ?? '';
    addAutoDisposeListener(
      filterTag,
      () => storage.setValue(filterStorageId, filterTag.value),
    );
  }
}
