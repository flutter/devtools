// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'preferences.dart';

class NetworkPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  /// The active filter tag for the network screen.
  ///
  /// This value caches the most recent filter settings.
  final filterTag = ValueNotifier<String>('');

  @visibleForTesting
  static const filterStorageId = 'network.filter';

  Future<void> init() async {
    filterTag.value = await storage.getValue(filterStorageId) ?? '';
    addAutoDisposeListener(
      filterTag,
      () => storage.setValue(filterStorageId, filterTag.value),
    );
  }
}
