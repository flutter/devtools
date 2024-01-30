// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc_2;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../../shared/config_specific/logger/logger_helpers.dart';
import '../../../shared/config_specific/post_message/post_message.dart';
import '../../../shared/constants.dart';
import '../dart_tooling_api.dart';
import '../vs_code_api.dart';
import 'vs_code_api.dart';

// TODO(https://github.com/flutter/devtools/issues/7055): migrate away from
// postMessage and use the Dart Tooling Daemon to communicate between Dart
// tooling surfaces.

/// Whether to enable verbose logging for postMessage communication.
///
/// This is useful for debugging when running inside VS Code.
///
/// TODO(dantup): Make a way for this to be enabled by users at runtime for
///  troubleshooting. This could be via a message from VS Code, or something
///  that passes a query param.
const _enablePostMessageVerboseLogging = false;

final _log = Logger('tooling_api');

/// An API used by Dart tooling surfaces to interact with Dart tools that expose
/// APIs such as Dart-Code and the LSP server.
class DartToolingApiImpl implements DartToolingApi {
  DartToolingApiImpl.rpc(this._rpc) {
    unawaited(_rpc.listen());
  }

  /// Connects the API using 'postMessage'. This is only available when running
  /// on web and hosted inside an iframe (such as inside a VS Code webview).
  factory DartToolingApiImpl.postMessage() {
    if (_enablePostMessageVerboseLogging) {
      setDevToolsLoggingLevel(verboseLoggingLevel);
    }
    final postMessageController = StreamController<Object?>();
    postMessageController.stream.listen((message) {
      // TODO(dantup): Using fine here doesn't work even though the
      // `setDevToolsLoggingLevel` call above seems like it should show finest
      // logs. For now, use info (which always logs) with a condition here
      // and below.
      if (_enablePostMessageVerboseLogging) {
        _log.info('==> $message');
      }
      postMessage(message, '*');
    });
    final channel = StreamChannel(
      onPostMessage.map((event) {
        if (_enablePostMessageVerboseLogging) {
          _log.info('<== ${jsonEncode(event.data)}');
        }
        return event.data;
      }),
      postMessageController,
    );
    return DartToolingApiImpl.rpc(json_rpc_2.Peer.withoutJson(channel));
  }

  final json_rpc_2.Peer _rpc;

  /// An API that provides Access to APIs related to VS Code, such as executing
  /// VS Code commands or interacting with the Dart/Flutter extensions.
  ///
  /// Lazy-initialized and completes with `null` if VS Code is not available.
  @override
  late final Future<VsCodeApi?> vsCode = VsCodeApiImpl.tryConnect(_rpc);

  void dispose() {
    unawaited(_rpc.close());
  }
}

/// Base class for the different APIs that may be available.
abstract base class ToolApiImpl {
  ToolApiImpl(this.rpc);

  static Future<Map<String, Object?>?> tryGetCapabilities(
    json_rpc_2.Peer rpc,
    String apiName,
  ) async {
    try {
      final response = await rpc.sendRequest('$apiName.getCapabilities')
          as Map<Object?, Object?>;
      return response.cast<String, Object?>();
    } catch (_) {
      // Any error initializing should disable this functionality.
      return null;
    }
  }

  @protected
  final json_rpc_2.Peer rpc;

  @protected
  String get apiName;

  @protected
  Future<T> sendRequest<T>(String method, [Object? parameters]) async {
    return (await rpc.sendRequest('$apiName.$method', parameters)) as T;
  }

  /// Listens for an event '[apiName].[name]' that has a Map for parameters.
  @protected
  Stream<Map<String, Object?>> events(String name) {
    final streamController = StreamController<Map<String, Object?>>.broadcast();
    unawaited(rpc.done.then((_) => streamController.close()));
    rpc.registerMethod('$apiName.$name', (json_rpc_2.Parameters parameters) {
      streamController.add(parameters.asMap.cast<String, Object?>());
    });
    return streamController.stream;
  }
}
