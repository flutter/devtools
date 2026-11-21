// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/service.dart' show FlutterEvent;
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart' show DebugViewMetricsOverride;
import 'package:vm_service/vm_service.dart' hide Error;

/// A [FakeServiceConnectionManager] whose main isolate serves the
/// `ext.flutter.viewMetricsOverride` service extension through [extension].
class ViewMetricsOverrideServiceConnection
    extends FakeServiceConnectionManager {
  @override
  FakeServiceManager get serviceManager => _serviceManager;
  final _serviceManager = _ViewMetricsOverrideServiceManager();

  /// The fake extension that [serviceManager] calls.
  FakeViewMetricsOverrideExtension get extension => _serviceManager.extension;
}

// ignore: subtype_of_sealed_class, fake for testing.
class _ViewMetricsOverrideServiceManager extends FakeServiceManager {
  late final extension = FakeViewMetricsOverrideExtension._(this);

  @override
  Future<Response> callServiceExtensionOnMainIsolate(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    if (method != viewMetricsOverride) {
      return super.callServiceExtensionOnMainIsolate(method, args: args);
    }
    final parameters = Map<String, String>.from(args ?? const {});
    extension.calls.add(parameters);
    if (extension.holdCalls) return Completer<Response>().future;
    final isolate = isolateManager.mainIsolate.value;
    // Like the VM service, reply after the caller has moved on, and never
    // reply to a call whose isolate exits first.
    await Future<void>.delayed(Duration.zero);
    if (isolateManager.mainIsolate.value != isolate) {
      return Completer<Response>().future;
    }
    final error = extension.nextCallError;
    extension.nextCallError = null;
    if (error != null) throw error;
    try {
      return extension._handle(parameters);
    } on FormatException catch (e, st) {
      // The app answers a call that the extension rejects with an error.
      Error.throwWithStackTrace(
        RPCError(method, RPCErrorKind.kServerError.code, e.message),
        st,
      );
    }
  }
}

/// A fake of the `ext.flutter.viewMetricsOverride` service extension of a
/// debug Flutter app.
///
/// Like the app, it parses the overrides of a call with
/// [DebugViewMetricsOverride.fromJson], so a call that the app would reject
/// fails. It replies with the registry, and posts it in a
/// `Flutter.ServiceExtensionStateChanged` event when a call changes it.
class FakeViewMetricsOverrideExtension {
  FakeViewMetricsOverrideExtension._(this._serviceManager);

  final FakeServiceManager _serviceManager;

  /// The registry of the app, keyed by view ID.
  ///
  /// A test can fill it directly, without the checks that calls go through.
  final registry = <String, Map<String, Object?>>{};

  /// The parameters of the calls that DevTools made, in order.
  final calls = <Map<String, String>>[];

  /// An error that the next call from DevTools throws instead of being
  /// handled, such as an [RPCError].
  Object? nextCallError;

  /// Whether the app leaves the calls from DevTools unanswered, so that a test
  /// can hot restart the app while a call is in flight.
  bool holdCalls = false;

  int _restarts = 0;

  /// Registers the extension, as the binding of a debug Flutter app does, and
  /// sends the first frame.
  Future<void> register() async {
    final extensionManager = _serviceManager.serviceExtensionManager;
    await extensionManager.fakeAddServiceExtension(viewMetricsOverride);
    await extensionManager.fakeFrame();
  }

  /// Calls the extension as another client of the app would, such as an MCP
  /// server.
  ///
  /// Throws a [FormatException] if the app would reject the call.
  void callFromOtherClient(Map<String, String> parameters) {
    _handle(parameters);
  }

  /// Hot restarts the app, which replaces the main isolate and empties the
  /// registry.
  ///
  /// As a real app can, the new isolate registers the extension before it
  /// becomes the main isolate.
  Future<void> hotRestart() async {
    final isolateManager = _serviceManager.isolateManager as FakeIsolateManager;
    // ServiceExtensionManager starts listening to the main isolate when the VM
    // service opens, so it reacts to the old isolate exiting before others.
    _serviceManager.serviceExtensionManager.fakeMainIsolateClosed();
    isolateManager.setMainIsolate(null);
    registry.clear();
    await register();
    _restarts++;
    isolateManager.setMainIsolate(
      IsolateRef(id: 'restarted_isolate_$_restarts', name: 'main'),
    );
  }

  Response _handle(Map<String, String> parameters) {
    final viewId = parameters['viewId'];
    final overrides = parameters['overrides'];
    if (viewId != null && overrides != null) {
      final previous = registry[viewId];
      final next = _parse(overrides);
      if (next.isEmpty) {
        registry.remove(viewId);
      } else {
        registry[viewId] = next;
      }
      if (!const DeepCollectionEquality().equals(previous, registry[viewId])) {
        _postStateChangedEvent();
      }
    }
    return Response.parse({
      'type': '_extensionType',
      'method': viewMetricsOverride,
      'overrides': _encodedRegistry,
    })!;
  }

  /// Parses [overrides] as the app does, and returns the overrides that the
  /// app keeps, in the format of its replies.
  ///
  /// Throws a [FormatException] if the app would reject [overrides].
  static Map<String, Object?> _parse(String overrides) {
    return switch (jsonDecode(overrides)) {
      final Map<Object?, Object?> json => DebugViewMetricsOverride.fromJson(
        json,
      ).toJson(),
      _ => throw const FormatException('The overrides must be a JSON object.'),
    };
  }

  /// The registry as the app serializes it into a reply or an event.
  Object? get _encodedRegistry => jsonDecode(jsonEncode(registry));

  void _postStateChangedEvent() {
    (_serviceManager.service as FakeVmServiceWrapper).emitExtensionEvent(
      Event(
        kind: EventKind.kExtension,
        extensionKind: FlutterEvent.serviceExtensionStateChanged,
        extensionData: ExtensionData.parse({
          'extension': viewMetricsOverride,
          'value': _encodedRegistry,
        }),
        isolate: _serviceManager.isolateManager.mainIsolate.value,
        timestamp: 0,
      ),
    );
  }
}
