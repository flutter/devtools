// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';

/// Fake that simplifies writing UI tests that depend on the
/// ServiceExtensionManager.
// TODO(jacobr): refactor ServiceExtensionManager so this fake can reuse more
// code from ServiceExtensionManager instead of reimplementing it.
class FakeServiceExtensionManager extends Fake
    implements ServiceExtensionManager {
  bool _firstFrameEventReceived = false;

  final _serviceExtensionStateController =
      <String, ValueNotifier<ServiceExtensionState>>{};

  final _serviceExtensionAvailable = <String, ValueNotifier<bool>>{};

  /// All available service extensions.
  final _serviceExtensions = <String>{};

  /// All service extensions that are currently enabled.
  final _enabledServiceExtensions = <String, ServiceExtensionState>{};

  /// Temporarily stores service extensions that we need to add. We should not
  /// add extensions until the first frame event has been received
  /// [_firstFrameEventReceived].
  final _pendingServiceExtensions = <String>{};

  /// Hook to simulate receiving the first frame event.
  ///
  /// Service extensions are only reported once a frame has been received.
  void fakeFrame() async {
    await _onFrameEventReceived();
  }

  Map<String, dynamic> extensionValueOnDevice = {};

  @override
  ValueListenable<bool> hasServiceExtension(String name) {
    return _hasServiceExtension(name);
  }

  ValueNotifier<bool> _hasServiceExtension(String name) {
    return _serviceExtensionAvailable.putIfAbsent(
      name,
      () => ValueNotifier(_hasServiceExtensionNow(name)),
    );
  }

  bool _hasServiceExtensionNow(String name) {
    return _serviceExtensions.contains(name);
  }

  @override
  Future<bool> waitForServiceExtensionAvailable(String name) {
    return Future.value(true);
  }

  /// Hook for tests to call to simulate adding a service extension.
  Future<void> fakeAddServiceExtension(String name) async {
    if (_firstFrameEventReceived) {
      assert(_pendingServiceExtensions.isEmpty);
      await _addServiceExtension(name);
    } else {
      _pendingServiceExtensions.add(name);
    }
  }

  /// Hook for tests to call to fake changing the state of a service
  /// extension.
  void fakeServiceExtensionStateChanged(
    final String name,
    String valueFromJson,
  ) async {
    final extension = serviceExtensionsAllowlist[name];
    if (extension != null) {
      final dynamic value = _getExtensionValueFromJson(name, valueFromJson);

      final enabled = extension is ToggleableServiceExtensionDescription
          ? value == extension.enabledValue
          // For extensions that have more than two states
          // (enabled / disabled), we will always consider them to be
          // enabled with the current value.
          : true;

      await setServiceExtensionState(
        name,
        enabled: enabled,
        value: value,
        callExtension: false,
      );
    }
  }

  dynamic _getExtensionValueFromJson(String name, String valueFromJson) {
    final expectedValueType =
        serviceExtensionsAllowlist[name]!.values.first.runtimeType;
    switch (expectedValueType) {
      case bool:
        return valueFromJson == 'true' ? true : false;
      case int:
      case double:
        return num.parse(valueFromJson);
      default:
        return valueFromJson;
    }
  }

  Future<void> _onFrameEventReceived() async {
    if (_firstFrameEventReceived) {
      // The first frame event was already received.
      return;
    }
    _firstFrameEventReceived = true;

    for (String extension in _pendingServiceExtensions) {
      await _addServiceExtension(extension);
    }
    _pendingServiceExtensions.clear();
  }

  Future<void> _addServiceExtension(String name) {
    _hasServiceExtension(name).value = true;

    _serviceExtensions.add(name);

    if (_enabledServiceExtensions.containsKey(name)) {
      // Restore any previously enabled states by calling their service
      // extension. This will restore extension states on the device after a hot
      // restart. [_enabledServiceExtensions] will be empty on page refresh or
      // initial start.
      return callServiceExtension(name, _enabledServiceExtensions[name]!.value);
    } else {
      // Set any extensions that are already enabled on the device. This will
      // enable extension states in DevTools on page refresh or initial start.
      return _restoreExtensionFromDevice(name);
    }
  }

  @override
  ValueListenable<ServiceExtensionState> getServiceExtensionState(String name) {
    return _serviceExtensionState(name);
  }

  ValueNotifier<ServiceExtensionState> _serviceExtensionState(String name) {
    return _serviceExtensionStateController.putIfAbsent(
      name,
      () {
        return ValueNotifier<ServiceExtensionState>(
          _enabledServiceExtensions.containsKey(name)
              ? _enabledServiceExtensions[name]!
              : ServiceExtensionState(enabled: false, value: null),
        );
      },
    );
  }

  Future<void> _restoreExtensionFromDevice(String name) async {
    if (!serviceExtensionsAllowlist.containsKey(name)) {
      return;
    }
    final extensionDescription = serviceExtensionsAllowlist[name];
    final value = extensionValueOnDevice[name];
    if (extensionDescription is ToggleableServiceExtensionDescription) {
      if (value == extensionDescription.enabledValue) {
        await setServiceExtensionState(
          name,
          enabled: true,
          value: value,
          callExtension: false,
        );
      }
    } else {
      await setServiceExtensionState(
        name,
        enabled: true,
        value: value,
        callExtension: false,
      );
    }
  }

  Future<void> callServiceExtension(String name, dynamic value) async {
    extensionValueOnDevice[name] = value;
  }

  @override
  void vmServiceClosed() {
    _firstFrameEventReceived = false;
    _pendingServiceExtensions.clear();
    _serviceExtensions.clear();
    for (var listenable in _serviceExtensionAvailable.values) {
      listenable.value = false;
    }
  }

  /// Sets the state for a service extension and makes the call to the VMService.
  @override
  Future<void> setServiceExtensionState(
    String name, {
    required bool enabled,
    required dynamic value,
    bool callExtension = true,
  }) async {
    if (callExtension && _serviceExtensions.contains(name)) {
      await callServiceExtension(name, value);
    }

    _serviceExtensionState(name).value = ServiceExtensionState(
      enabled: enabled,
      value: value,
    );

    // Add or remove service extension from [enabledServiceExtensions].
    if (enabled) {
      _enabledServiceExtensions[name] = ServiceExtensionState(
        enabled: enabled,
        value: value,
      );
    } else {
      _enabledServiceExtensions.remove(name);
    }
  }

  @override
  bool isServiceExtensionAvailable(String name) {
    return _serviceExtensions.contains(name) ||
        _pendingServiceExtensions.contains(name);
  }
}
