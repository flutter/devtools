// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of 'preferences.dart';

class ExtensionsPreferencesController extends DisposableController
    with AutoDisposeControllerMixin {
  final showOnlyEnabledExtensions = ValueNotifier<bool>(false);

  static final _showOnlyEnabledExtensionsId =
      '${gac.DevToolsExtensionEvents.extensionScreenId}.'
      '${gac.DevToolsExtensionEvents.showOnlyEnabledExtensionsSetting.name}';

  @override
  Future<void> init() async {
    addAutoDisposeListener(showOnlyEnabledExtensions, () {
      storage.setValue(
        _showOnlyEnabledExtensionsId,
        showOnlyEnabledExtensions.value.toString(),
      );
      ga.select(
        gac.DevToolsExtensionEvents.extensionScreenId.name,
        gac.DevToolsExtensionEvents.showOnlyEnabledExtensionsSetting.name,
        value: showOnlyEnabledExtensions.value ? 1 : 0,
      );
    });
    showOnlyEnabledExtensions.value = await boolValueFromStorage(
      _showOnlyEnabledExtensionsId,
      defaultsTo: false,
    );
  }
}
