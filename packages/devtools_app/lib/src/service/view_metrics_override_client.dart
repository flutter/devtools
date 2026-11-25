// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:vm_service/vm_service.dart';

import '../shared/globals.dart';
import 'service_registrations.dart' as registrations;

final _log = Logger('view_metrics_override_client');

/// A client for the `ext.flutter.viewMetricsOverride` service extension, which
/// makes a debug Flutter app behave as though the platform reported different
/// view metrics, such as a larger text scale or bold text.
///
/// The app keeps the overrides in a registry keyed by view ID. Every reply of
/// the extension, and every `Flutter.ServiceExtensionStateChanged` event that
/// it posts, carries the whole registry. This client takes [overrides] from
/// the latest of them, so a call that fails leaves [overrides] as the app last
/// reported it.
///
/// The extension cannot list view IDs yet, so this client only acts on the
/// implicit view, whose ID is 0.
///
/// The registry lives in the main isolate of the app, so a hot restart empties
/// it. This client then reads the registry of the new isolate.
///
/// See `FoundationServiceExtensions.viewMetricsOverride` in
/// `package:flutter/foundation.dart` for the protocol.
class ViewMetricsOverrideClient extends DisposableController
    with AutoDisposeControllerMixin {
  /// Creates a client for the app that DevTools is connected to.
  ///
  /// The client listens to the extension events of the VM service connection
  /// that is open when it is created, so, like a screen controller, it has to
  /// be created again for a new connection. Create only one client per
  /// connection: like two tools, two clients can overwrite each other's
  /// changes.
  ViewMetricsOverrideClient() {
    final serviceManager = serviceConnection.serviceManager;
    addAutoDisposeListener(
      serviceManager.isolateManager.mainIsolate,
      _onMainIsolateChanged,
    );
    final service = serviceManager.service;
    if (service != null) {
      autoDisposeStreamSubscription(
        service.onExtensionEvent.listen(_onExtensionEvent),
      );
    }
    _onMainIsolateChanged();
  }

  static const _implicitViewId = '0';

  /// Whether the main isolate of the connected app has registered the
  /// extension, which only debug builds of recent Flutter versions do.
  ValueListenable<bool> get available => _available;
  final _available = ValueNotifier<bool>(false);

  /// The overrides that the app has for the implicit view, as it last reported
  /// them, such as `{'boldText': true}`.
  ///
  /// The map has the JSON format of `DebugViewMetricsOverride` in
  /// `package:flutter/foundation.dart`. It is empty until the current main
  /// isolate first reports its overrides.
  ValueListenable<Map<String, Object?>> get overrides => _overrides;
  final _overrides = ValueNotifier<Map<String, Object?>>(const {});

  /// Whether the current main isolate has reported its overrides.
  bool _overridesReported = false;

  /// Incremented when the main isolate changes, to drop the calls and replies
  /// of the isolates that are gone.
  int _isolateGeneration = 0;

  /// [ServiceExtensionManager.hasServiceExtension] for the current main
  /// isolate, looked up again for every main isolate because it stops updating
  /// once its isolate exits.
  ValueListenable<bool>? _hasExtension;

  /// Completes when the last call queued for the current main isolate is done.
  ///
  /// Calls run one at a time, so that every write starts from the reply to the
  /// call before it.
  Future<void> _lastCall = Future<void>.value();

  /// Completes at the next change of the main isolate, or when this client is
  /// disposed.
  ///
  /// The VM service never answers a call that is in flight when its isolate
  /// exits, so the futures that [_queue] returns also complete when this does.
  Completer<void> _nextMainIsolateChange = Completer<void>();

  /// Overrides the metrics in [metrics] for the implicit view, and keeps the
  /// other [overrides] that the view has.
  ///
  /// The keys and values of [metrics] have the format of [overrides]. A null
  /// value stops overriding the metric, so that the app uses the value that
  /// the platform reports.
  ///
  /// The app only reports the changes that go through the extension, so a
  /// change that app code makes with `debugSetViewMetricsOverride` is lost at
  /// the next call. A change that another client makes after this client last
  /// heard from the app, and before the app receives this call, is lost too.
  ///
  /// Does nothing while the extension is not [available]. A call that fails is
  /// logged, and leaves [overrides] as the app last reported them. The
  /// returned future completes once the app answers, or once a hot restart
  /// interrupts the call.
  Future<void> updateOverrides(Map<String, Object?> metrics) =>
      _queue(() => _write(metrics));

  /// Runs [call] after the calls queued before it, unless the main isolate has
  /// changed or the extension is not [available] by then.
  ///
  /// Logs what [call] throws, so that the calls after it still run. The
  /// returned future completes when [call] is done, or at the next change of
  /// the main isolate, whichever comes first.
  Future<void> _queue(Future<void> Function() call) {
    final isolateGeneration = _isolateGeneration;
    _lastCall = _lastCall.then((_) async {
      if (disposed ||
          isolateGeneration != _isolateGeneration ||
          !_available.value) {
        return;
      }
      try {
        await call();
      } catch (e, st) {
        _log.warning(
          'Failed to call ${registrations.viewMetricsOverride}: $e',
          e,
          st,
        );
      }
    });
    return Future.any<void>([_lastCall, _nextMainIsolateChange.future]);
  }

  Future<void> _read() => _call(const {});

  /// Writes [metrics] over the overrides that the app last reported.
  Future<void> _write(Map<String, Object?> metrics) async {
    final isolateGeneration = _isolateGeneration;
    // A write that does not start from the overrides of the app could remove
    // the overrides that other clients set, so read them first if needed.
    if (!_overridesReported) await _read();
    if (!_overridesReported || isolateGeneration != _isolateGeneration) return;
    final viewOverrides = {..._overrides.value, ...metrics}
      ..removeWhere((_, value) => value == null);
    await _call({
      'viewId': _implicitViewId,
      'overrides': jsonEncode(viewOverrides),
    });
  }

  /// Calls the extension with [parameters], and takes [overrides] from the
  /// reply.
  Future<void> _call(Map<String, String> parameters) async {
    final isolateGeneration = _isolateGeneration;
    try {
      final response = await serviceConnection.serviceManager
          .callServiceExtensionOnMainIsolate(
            registrations.viewMetricsOverride,
            args: parameters,
          );
      if (disposed || isolateGeneration != _isolateGeneration) return;
      _takeOverridesFrom(response.json?['overrides']);
    } catch (e, st) {
      _log.warning(
        'Failed to call ${registrations.viewMetricsOverride}: $e',
        e,
        st,
      );
    }
  }

  /// Takes [overrides] from [registry], which is the `overrides` of a reply or
  /// the `value` of an event.
  void _takeOverridesFrom(Object? registry) {
    final viewOverrides = registry is Map
        ? registry[_implicitViewId] ?? const <String, Object?>{}
        : null;
    if (viewOverrides is! Map<String, Object?>) {
      _log.warning(
        'Unexpected overrides from ${registrations.viewMetricsOverride}: '
        '$registry',
      );
      return;
    }
    _overridesReported = true;
    // Replies, and events about other views, often carry unchanged overrides
    // for this view, so notify only when they differ.
    if (!const DeepCollectionEquality().equals(
      viewOverrides,
      _overrides.value,
    )) {
      _overrides.value = Map.unmodifiable(viewOverrides);
    }
  }

  void _onExtensionEvent(Event event) {
    if (event.extensionKind != FlutterEvent.serviceExtensionStateChanged) {
      return;
    }
    final data = event.extensionData?.data;
    if (data == null ||
        data['extension'] != registrations.viewMetricsOverride) {
      return;
    }
    // An isolate that a hot restart replaced can still post an event, which
    // describes a registry that is gone.
    final mainIsolate =
        serviceConnection.serviceManager.isolateManager.mainIsolate.value;
    if (mainIsolate == null || event.isolate?.id != mainIsolate.id) return;
    // Unlike the other extensions, this one posts its state as a JSON object,
    // which ServiceExtensionManager would turn into a string.
    _takeOverridesFrom(data['value']);
  }

  void _onMainIsolateChanged() {
    _isolateGeneration++;
    // The VM service never answers a call that is in flight when its isolate
    // exits, so the calls for the new main isolate do not wait for older ones,
    // and neither do the callers of the older ones.
    _lastCall = Future<void>.value();
    _nextMainIsolateChange.complete();
    _nextMainIsolateChange = Completer<void>();
    _overridesReported = false;
    // The registry that the overrides describe is gone with its isolate.
    _overrides.value = const {};

    final serviceManager = serviceConnection.serviceManager;
    cancelListener(_onAvailabilityChanged);
    // ServiceExtensionManager can report the extensions of a new isolate
    // before it becomes the main isolate, so wait for a main isolate.
    _hasExtension = serviceManager.isolateManager.mainIsolate.value == null
        ? null
        : serviceManager.serviceExtensionManager.hasServiceExtension(
            registrations.viewMetricsOverride,
          );
    addAutoDisposeListener(_hasExtension, _onAvailabilityChanged);
    _onAvailabilityChanged();
  }

  void _onAvailabilityChanged() {
    final available = _hasExtension?.value ?? false;
    if (available == _available.value) return;
    _available.value = available;
    if (available) unawaited(_queue(_read));
  }

  @override
  void dispose() {
    _nextMainIsolateChange.complete();
    _available.dispose();
    _overrides.dispose();
    super.dispose();
  }
}
