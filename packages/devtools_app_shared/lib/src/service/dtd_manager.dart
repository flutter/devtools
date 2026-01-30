// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:math' as math;

import 'package:dtd/dtd.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'dtd_manager_connection_state.dart';

final _log = Logger('dtd_manager');

/// Manages a connection to the Dart Tooling Daemon.
class DTDManager {
  ValueListenable<DartToolingDaemon?> get connection => _connection;
  final _connection = ValueNotifier<DartToolingDaemon?>(null);

  DartToolingDaemon get _dtd => _connection.value!;

  /// Whether the [DTDManager] is connected to a running instance of the DTD.
  bool get hasConnection => connection.value != null;

  /// The current state of the connection.
  ValueListenable<DTDConnectionState> get connectionState => _connectionState;
  final _connectionState =
      ValueNotifier<DTDConnectionState>(NotConnectedDTDState());

  /// The URI of the current DTD connection.
  Uri? get uri => _uri;
  Uri? _uri;

  /// A stream of [CoreDtdServiceConstants.serviceRegisteredKind] and
  /// [CoreDtdServiceConstants.serviceUnregisteredKind] events.
  ///
  /// Since this is a broadcast stream, it supports multiple subscribers.
  Stream<DTDEvent> get serviceRegistrationBroadcastStream =>
      _serviceRegistrationController.stream;
  final _serviceRegistrationController = StreamController<DTDEvent>.broadcast();

  /// The subscription to the current service registration stream.
  ///
  /// This is canceled and reset with the DTD connection changes.
  StreamSubscription<DTDEvent>? _currentServiceRegistrationSubscription;

  /// Whether or not to automatically reconnect if disconnected.
  ///
  /// This will happen by default as long as the disconnect wasn't
  /// explicitly requested.
  bool _automaticallyReconnect = true;

  Timer? _periodicConnectionCheck;
  static const _periodicConnectionCheckInterval = Duration(minutes: 1);

  /// A function that replays the last connection attempt.
  ///
  /// This is used by [reconnect] to reconnect to the last server with the same
  /// settings if the connection was dropped and failed to reconnect within the
  /// specified retry period.
  Future<void> Function()? _lastConnectFunc;

  /// A wrapper around connecting to DTD to allow tests to intercept the
  /// connection.
  @visibleForTesting
  Future<DartToolingDaemon> connectDtdImpl(Uri uri) async {
    // Cancel any previous timer.
    _periodicConnectionCheck?.cancel();

    final dtd = await DartToolingDaemon.connect(uri);

    // Set up a periodic connection check to detect if the connection has
    // dropped even if `done` doesn't fire.
    //
    // If this happens, just disconnect (without disabling reconnect) so the
    // done event fires and then the usual handling occurs.
    _periodicConnectionCheck =
        Timer.periodic(_periodicConnectionCheckInterval, (timer) async {
      if (_dtd.isClosed) {
        _log.warning('The DTD connection has dropped');
        await disconnectImpl(allowReconnect: true);
      }
    });

    return dtd;
  }

  /// Triggers a reconnect to the last connected URI if the current state is
  /// [ConnectionFailedDTDState] (and there was a previous connection).
  Future<void> reconnect() {
    final reconnectFunc = _lastConnectFunc;
    if (_connectionState.value is! ConnectionFailedDTDState ||
        reconnectFunc == null) {
      return Future.value();
    }

    return reconnectFunc();
  }

  /// Tries to connect to DTD at [uri] with automatic retries and exponential
  /// backoff.
  ///
  /// When a computer sleeps, the WebSocket connection may be dropped and it
  /// may take some time for a browser to allow network connections without
  /// ERR_NETWORK_IO_SUSPENDED.
  Future<DartToolingDaemon> _connectWithRetries(
    Uri uri, {
    required int maxRetries,
  }) async {
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _connectionState.value = ConnectingDTDState();
        // The await here is important so errors are handled by this catch!
        return await connectDtdImpl(uri);
      } catch (e, s) {
        // On last attempt, fail and propagate the error.
        if (attempt == maxRetries) {
          _connectionState.value = ConnectionFailedDTDState();
          _log.severe('Failed to connect to DTD after $attempt attempts', e, s);
          rethrow;
        }

        // Otherwise, retry after a delay.
        var delay = math.pow(2, attempt - 1).toInt();
        _log.info(
          'Failed to connect to DTD on attempt $attempt, '
          'will retry in ${delay}s',
        );
        while (delay > 0) {
          _connectionState.value = WaitingToRetryDTDState(delay);
          await Future.delayed(const Duration(seconds: 1));
          delay--;
        }
      }
    }

    // We can't get here because of the logic above, but the analyzer can't
    // tell that.
    _connectionState.value = NotConnectedDTDState();
    throw StateError('Failed to connect to DTD');
  }

  /// Connects Dart Tooling Daemon connection to [uri].
  ///
  /// Before connecting to [uri], unless [disconnectBeforeConnecting] is
  /// `false`, will call [disconnect] to disconnect any existing connection.
  ///
  /// If the connection fails, will retry with exponential backoff up to
  /// [maxRetries].
  Future<void> _connectImpl(
    Uri uri, {
    void Function(Object, StackTrace?)? onError,
    int maxRetries = 5,
    bool disconnectBeforeConnecting = true,
  }) async {
    if (disconnectBeforeConnecting) {
      await disconnect();
    }
    // Enable automatic reconnect on any new connection.
    _automaticallyReconnect = true;

    try {
      final connection = await _connectWithRetries(uri, maxRetries: maxRetries);
      await _listenForServiceRegistrationEvents(connection);

      // Save the previous connection so that we can close it after the new
      // connection is reestablished.
      final previousConnection = _connection.value;
      _uri = uri;
      // Set this after setting the value of [_uri] so that [_uri] can be used
      // by any listeners of the [_connection] notifier.
      _connection.value = connection;
      // Close the previous connection.
      if (previousConnection != null) {
        await previousConnection.close();
      }
      _connectionState.value = ConnectedDTDState();
      _log.info('Successfully connected to DTD at: $uri');

      // If a connection drops (and we hadn't disabled auto-reconnect, such
      // as by explicitly calling disconnect/dispose), we should attempt to
      // reconnect.
      unawaited(connection.done
          .then((_) => _reconnectAfterDroppedConnection(uri, onError: onError))
          .catchError((_) {
        // TODO(dantup): Create a devtools_app_shared version of safeUnawaited.
        // https://github.com/flutter/devtools/pull/9587#discussion_r2624306047
      }));
    } catch (e, st) {
      onError?.call(e, st);
    }
  }

  /// Triggers a reconnect without first disconnecting. This allows existing
  /// state to be retained in the background while reconnect is in progress so
  /// that the content the user could previously see is not hidden.
  Future<void> _reconnectAfterDroppedConnection(
    Uri uri, {
    void Function(Object, StackTrace?)? onError,
  }) async {
    // Trigger disconnect to ensure we emit a `null` connection to
    // listeners.
    await disconnectImpl(allowReconnect: true);
    if (_automaticallyReconnect) {
      await _connectImpl(
        uri,
        onError: onError,
        // We've already disconnected above, in a way that doesn't disable
        // reconnect and does not set connection to null (allowing screens
        // to remain visible under connection overlays).
        disconnectBeforeConnecting: false,
      );
    }
  }

  /// Sets the Dart Tooling Daemon connection to point to [uri].
  ///
  /// Before connecting to [uri], if a current connection exists, then
  /// [disconnect] is called to close it.
  ///
  /// If the connection fails, will retry with exponential backoff up to
  /// [maxRetries].
  Future<void> connect(
    Uri uri, {
    void Function(Object, StackTrace?)? onError,
    int maxRetries = 5,
  }) {
    // On explicit connections, we capture the connect function so that we
    // can call it again if [reconnect()] is called.
    final connectFunc = _lastConnectFunc =
        () => _connectImpl(uri, onError: onError, maxRetries: maxRetries);
    return connectFunc();
  }

  /// Closes and unsets the Dart Tooling Daemon connection, if one is set.
  Future<void> disconnect() => disconnectImpl();

  /// Closes and unsets the Dart Tooling Daemon connection, if one is set.
  ///
  /// [allowReconnect] controls whether reconnection is allowed. This is
  /// generally false for an explicit disconnect/dispose, but allowed if we
  /// are called as part of a dropped connection. Reconnecting being allowed
  /// does not necessarily mean it will happen, because there might have been
  /// an explicit disconnect (or dispose) call before we got here.
  @visibleForTesting
  Future<void> disconnectImpl({bool allowReconnect = false}) async {
    if (!allowReconnect) {
      // If we're not allowed to reconnect, disable this. `allowReconnect` being
      // true does NOT mean we can enable this, because we might get here after
      // an explicit disconnect.
      _automaticallyReconnect = false;

      // We only close and clear the connection if we are explicitly
      // disconnecting.
      //
      // In the case where the connection just dropped, we leave it so
      // that we can continue to render a page (usually with an overlay), then
      // only close it once the new connection is established.
      if (_connection.value case final connection?) {
        await connection.close();
      }
      _connection.value = null;
    }

    _periodicConnectionCheck?.cancel();

    _connectionState.value = NotConnectedDTDState();
    _uri = null;
    _workspaceRoots = null;
    _projectRoots = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _currentServiceRegistrationSubscription?.cancel();
    await _serviceRegistrationController.close();
    _connection.dispose();
  }

  /// Listens for service registration events on the [dtd] connection.
  Future<void> _listenForServiceRegistrationEvents(
      DartToolingDaemon dtd) async {
    // We immediately begin listening for service registration events on the new
    // DTD connection before canceling the previous subscription. This
    // guarantees that we don't miss any events across reconnects.
    // ignore: cancel_subscriptions, false positive, it is canceled below.
    final nextServiceRegistrationSubscription = dtd
        .onEvent(CoreDtdServiceConstants.servicesStreamId)
        .listen(_forwardServiceRegistrationEvents,
            onError: _logServiceStreamError);
    await dtd.streamListen(CoreDtdServiceConstants.servicesStreamId);

    // Cancel the previous subscription.
    await _currentServiceRegistrationSubscription?.cancel();
    _currentServiceRegistrationSubscription =
        nextServiceRegistrationSubscription;
  }

  /// Forwards service registration events to the
  /// [_serviceRegistrationController].
  void _forwardServiceRegistrationEvents(DTDEvent event) {
    final kind = event.kind;
    final isRegistrationEvent =
        kind == CoreDtdServiceConstants.serviceRegisteredKind ||
            kind == CoreDtdServiceConstants.serviceUnregisteredKind;

    if (isRegistrationEvent) {
      _serviceRegistrationController.add(event);
    }
  }

  void _logServiceStreamError(Object error) {
    _log.warning('Error in DTD service stream', error);
  }

  /// Returns the workspace roots for the Dart Tooling Daemon connection.
  ///
  /// These roots are set by the tool that started DTD, which may be the IDE,
  /// DevTools server, or DDS (the Dart Development Service managed by the Dart
  /// or Flutter CLI tools).
  ///
  /// A workspace root is considered any directory that is at the root of the
  /// IDE's open project or workspace, or in the case where the Dart Tooling
  /// Daemon was started from the DevTools server or DDS (e.g. an app ran from
  /// the CLI), a workspace root is the root directory for the Dart or Flutter
  /// program connected to DevTools.
  ///
  /// By default, the cached value [_workspaceRoots] will be returned when
  /// available. When [forceRefresh] is true, the cached value will be cleared
  /// and recomputed.
  Future<IDEWorkspaceRoots?> workspaceRoots({bool forceRefresh = false}) async {
    if (!hasConnection) return null;
    if (_workspaceRoots != null && forceRefresh) {
      _workspaceRoots = null;
    }
    try {
      return _workspaceRoots ??= await _dtd.getIDEWorkspaceRoots();
    } catch (e) {
      _log.fine('Error fetching IDE workspaceRoots: $e');
      return null;
    }
  }

  IDEWorkspaceRoots? _workspaceRoots;

  /// Returns the project roots for the Dart Tooling Daemon connection.
  ///
  /// A project root is any directory, contained within the current set of
  /// [workspaceRoots], that contains a 'pubspec.yaml' file.
  ///
  /// By default, the cached value [_projectRoots] will be returned when
  /// available. When [forceRefresh] is true, the cached value will be cleared
  /// and recomputed.
  ///
  /// [depth] is the maximum depth that each workspace root directory tree will
  /// will be searched for project roots. Setting [depth] to a large number
  /// may have performance implications when traversing large trees.
  Future<UriList?> projectRoots({
    int? depth = defaultGetProjectRootsDepth,
    bool forceRefresh = false,
  }) async {
    if (!hasConnection) return null;
    if (_projectRoots != null && forceRefresh) {
      _projectRoots = null;
    }
    try {
      return _projectRoots ??= await _dtd.getProjectRoots(depth: depth!);
    } catch (e) {
      _log.fine('Error fetching project roots: $e');
      return null;
    }
  }

  UriList? _projectRoots;
}
