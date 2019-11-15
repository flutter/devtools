// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app/src/connected_app.dart';
import 'package:devtools_app/src/flutter/controllers.dart';
import 'package:devtools_app/src/logging/logging_controller.dart';
import 'package:devtools_app/src/service_extensions.dart' as extensions;
import 'package:devtools_app/src/service_manager.dart';
import 'package:devtools_app/src/stream_value_listenable.dart';
import 'package:devtools_app/src/timeline/timeline_controller.dart';
import 'package:devtools_app/src/timeline/timeline_model.dart';
import 'package:devtools_app/src/ui/fake_flutter/fake_flutter.dart';
import 'package:devtools_app/src/vm_service_wrapper.dart';
import 'package:meta/meta.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

class FakeServiceManager extends Fake implements ServiceConnectionManager {
  FakeServiceManager({bool useFakeService = false, this.hasConnection = true})
      : service = useFakeService ? FakeVmService() : MockVmService();

  @override
  final VmServiceWrapper service;

  @override
  final Completer serviceAvailable = Completer()..complete();

  @override
  final ConnectedApp connectedApp = MockConnectedApp();

  @override
  Stream<VmServiceWrapper> get onConnectionClosed => const Stream.empty();

  @override
  Stream<VmServiceWrapper> get onConnectionAvailable => Stream.value(service);

  @override
  final bool hasConnection;

  @override
  final IsolateManager isolateManager = MockIsolateManager();

  @override
  final FakeServiceExtensionManager serviceExtensionManager =
      FakeServiceExtensionManager();

  @override
  StreamSubscription<bool> hasRegisteredService(
    String name,
    void onData(bool value),
  ) {
    return Stream.value(false).listen(onData);
  }

  @override
  Stream<bool> get onStateChange => const Stream.empty();
}

class FakeVmService extends Fake implements VmServiceWrapper {
  final _flags = <String, dynamic>{
    'flags': <Flag>[],
  };

  @override
  Future<Success> setFlag(String name, String value) {
    final List<Flag> flags = _flags['flags'];
    final existingFlag =
        flags.firstWhere((f) => f.name == name, orElse: () => null);
    if (existingFlag != null) {
      existingFlag.valueAsString = value;
    } else {
      flags.add(Flag.parse({
        'name': name,
        'comment': 'Mock Flag',
        'modified': true,
        'valueAsString': value,
      }));
    }
    return Future.value(Success());
  }

  @override
  Future<FlagList> getFlagList() => Future.value(FlagList.parse(_flags));

  final _vmTimelineFlags = <String, dynamic>{
    'type': 'TimelineFlags',
    'recordedStreams': [],
  };

  @override
  Future<Success> setVMTimelineFlags(List<String> recordedStreams) async {
    _vmTimelineFlags['recordedStreams'] = recordedStreams;
    return Future.value(Success());
  }

  @override
  Future<TimelineFlags> getVMTimelineFlags() =>
      Future.value(TimelineFlags.parse(_vmTimelineFlags));

  @override
  Stream<Event> onEvent(String streamName) => const Stream.empty();

  @override
  Stream<Event> get onStdoutEvent => const Stream.empty();

  @override
  Stream<Event> get onStderrEvent => const Stream.empty();

  @override
  Stream<Event> get onGCEvent => const Stream.empty();

  @override
  Stream<Event> get onLoggingEvent => const Stream.empty();

  @override
  Stream<Event> get onExtensionEvent => const Stream.empty();
}

class MockIsolateManager extends Mock implements IsolateManager {}

class MockServiceManager extends Mock implements ServiceConnectionManager {}

class MockVmService extends Mock implements VmServiceWrapper {}

class MockConnectedApp extends Mock implements ConnectedApp {}

class MockLoggingController extends Mock implements LoggingController {}

class MockTimelineController extends Mock implements TimelineController {}

class MockFrameBasedTimelineData extends Mock
    implements FrameBasedTimelineData {}

/// Fake that simplifies writing UI tests that depend on the
/// ServiceExtensionManager.
// TODO(jacobr): refactor ServiceExtensionManager so this fake can reuse more
// code from ServiceExtensionManager instead of reimplementing it.
class FakeServiceExtensionManager extends Fake
    implements ServiceExtensionManager {
  bool _firstFrameEventReceived = false;

  final Map<String, StreamController<bool>> _serviceExtensionController = {};
  final Map<String, StreamController<ServiceExtensionState>>
      _serviceExtensionStateController = {};

  final Map<String, ValueListenable<bool>> _serviceExtensionListenables = {};

  /// All available service extensions.
  final _serviceExtensions = <String>{};

  /// All service extensions that are currently enabled.
  final Map<String, ServiceExtensionState> _enabledServiceExtensions = {};

  /// Temporarily stores service extensions that we need to add. We should not
  /// add extensions until the first frame event has been received
  /// [_firstFrameEventReceived].
  final Set<String> _pendingServiceExtensions = {};

  @override
  Completer<void> extensionStatesUpdated = Completer();

  /// Hook to simulate receiving the first frame event.
  ///
  /// Service extensions are only reported once a frame has been received.
  void fakeFrame() async {
    await _onFrameEventReceived();
  }

  Map<String, dynamic> extensionValueOnDevice = {};

  @override
  ValueListenable<bool> hasServiceExtensionListener(String name) {
    return _serviceExtensionListenables.putIfAbsent(
      name,
      () => StreamValueListenable<bool>(
        (notifier) {
          return hasServiceExtension(name, (value) {
            notifier.value = value;
          });
        },
        () => _hasServiceExtensionNow(name),
      ),
    );
  }

  bool _hasServiceExtensionNow(String name) {
    return _serviceExtensions.contains(name);
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
    final extension = extensions.serviceExtensionsWhitelist[name];
    if (extension != null) {
      final dynamic value = _getExtensionValueFromJson(name, valueFromJson);

      final enabled =
          extension is extensions.ToggleableServiceExtensionDescription
              ? value == extension.enabledValue
              // For extensions that have more than two states
              // (enabled / disabled), we will always consider them to be
              // enabled with the current value.
              : true;

      await setServiceExtensionState(
        name,
        enabled,
        value,
        callExtension: false,
      );
    }
  }

  dynamic _getExtensionValueFromJson(String name, String valueFromJson) {
    final expectedValueType =
        extensions.serviceExtensionsWhitelist[name].values.first.runtimeType;
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
    extensionStatesUpdated.complete();
    _pendingServiceExtensions.clear();
  }

  Future<void> _addServiceExtension(String name) async {
    final streamController = _getServiceExtensionController(name);

    _serviceExtensions.add(name);
    streamController.add(true);

    if (_enabledServiceExtensions.containsKey(name)) {
      // Restore any previously enabled states by calling their service
      // extension. This will restore extension states on the device after a hot
      // restart. [_enabledServiceExtensions] will be empty on page refresh or
      // initial start.
      await callServiceExtension(name, _enabledServiceExtensions[name].value);
    } else {
      // Set any extensions that are already enabled on the device. This will
      // enable extension states in DevTools on page refresh or initial start.
      await _restoreExtensionFromDevice(name);
    }
  }

  Future<void> _restoreExtensionFromDevice(String name) async {
    if (!extensions.serviceExtensionsWhitelist.containsKey(name)) {
      return;
    }
    final extensionDescription = extensions.serviceExtensionsWhitelist[name];
    final value = extensionValueOnDevice[name];
    if (extensionDescription
        is extensions.ToggleableServiceExtensionDescription) {
      if (value == extensionDescription.enabledValue) {
        await setServiceExtensionState(name, true, value, callExtension: false);
      }
    } else {
      await setServiceExtensionState(name, true, value, callExtension: false);
    }
  }

  Future<void> callServiceExtension(String name, dynamic value) async {
    extensionValueOnDevice[name] = value;
  }

  @override
  void resetAvailableExtensions() {
    extensionStatesUpdated = Completer();
    _firstFrameEventReceived = false;
    _pendingServiceExtensions.clear();
    _serviceExtensions.clear();
    _serviceExtensionController
        .forEach((String name, StreamController<bool> stream) {
      stream.add(false);
    });
  }

  /// Sets the state for a service extension and makes the call to the VMService.
  @override
  Future<void> setServiceExtensionState(
    String name,
    bool enabled,
    dynamic value, {
    bool callExtension = true,
  }) async {
    if (callExtension && _serviceExtensions.contains(name)) {
      await callServiceExtension(name, value);
    }

    final StreamController<ServiceExtensionState> streamController =
        _getServiceExtensionStateController(name);
    streamController.add(ServiceExtensionState(enabled, value));

    // Add or remove service extension from [enabledServiceExtensions].
    if (enabled) {
      _enabledServiceExtensions[name] = ServiceExtensionState(enabled, value);
    } else {
      _enabledServiceExtensions.remove(name);
    }
  }

  @override
  bool isServiceExtensionAvailable(String name) {
    return _serviceExtensions.contains(name) ||
        _pendingServiceExtensions.contains(name);
  }

  @override
  StreamSubscription<bool> hasServiceExtension(
    String name,
    void onData(bool value),
  ) {
    if (_serviceExtensions.contains(name) && onData != null) {
      onData(true);
    }
    final StreamController<bool> streamController =
        _getServiceExtensionController(name);
    return streamController.stream.listen(onData);
  }

  @override
  StreamSubscription<ServiceExtensionState> getServiceExtensionState(
    String name,
    void onData(ServiceExtensionState state),
  ) {
    if (_enabledServiceExtensions.containsKey(name) && onData != null) {
      onData(_enabledServiceExtensions[name]);
    }
    final StreamController<ServiceExtensionState> streamController =
        _getServiceExtensionStateController(name);
    return streamController.stream.listen(onData);
  }

  StreamController<bool> _getServiceExtensionController(String name) {
    return _getStreamController(
      name,
      _serviceExtensionController,
      onFirstListenerSubscribed: () {
        // If the service extension is in [_serviceExtensions], then we have been
        // waiting for a listener to add the initial true event. Otherwise, the
        // service extension is not available, so we should add a false event.
        _serviceExtensionController[name]
            .add(_serviceExtensions.contains(name));
      },
    );
  }

  StreamController<ServiceExtensionState> _getServiceExtensionStateController(
      String name) {
    return _getStreamController(
      name,
      _serviceExtensionStateController,
      onFirstListenerSubscribed: () {
        // If the service extension is enabled, add the current state as the first
        // event. Otherwise, add a disabled state as the first event.
        if (_enabledServiceExtensions.containsKey(name)) {
          assert(_enabledServiceExtensions[name].enabled);
          _serviceExtensionStateController[name]
              .add(_enabledServiceExtensions[name]);
        } else {
          _serviceExtensionStateController[name]
              .add(ServiceExtensionState(false, null));
        }
      },
    );
  }
}

/// Given a map of Strings to StreamControllers [streamControllers], get the
/// stream controller for the given name. If it does not exist, initialize a
/// generic stream controller and map it to the name.
StreamController<T> _getStreamController<T>(
    String name, Map<String, StreamController<T>> streamControllers,
    {@required void onFirstListenerSubscribed()}) {
  streamControllers.putIfAbsent(
    name,
    () => StreamController<T>.broadcast(onListen: onFirstListenerSubscribed),
  );
  return streamControllers[name];
}

class TestProvidedControllers extends Fake implements ProvidedControllers {
  TestProvidedControllers() {
    disposed[this] = false;
  }
  @override
  void dispose() {
    disposed[this] = true;
  }
}

final disposed = <TestProvidedControllers, bool>{};
