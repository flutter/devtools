// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:dtd/dtd.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A record of a [StreamChannel] and a [Stream] of logs of protocol traffic
/// in both directions across it.
typedef LoggedChannel = ({StreamChannel<String> channel, Stream<String> log});

/// Connects to the websocket at [wsUri] and returns a [StreamSink<String>].
///
/// All traffic is logged into [sink].
Future<StreamChannel<String>> createLoggedWebSocketChannel(
  Uri wsUri,
  StreamSink<String> sink,
) async {
  final rawChannel = WebSocketChannel.connect(wsUri);
  await rawChannel.ready;
  final rawStringChannel = rawChannel.cast<String>();

  /// A helper to create a function that can be used in stream.map() to log
  /// traffic with a prefix.
  String Function(String) logTraffic(String prefix) {
    return (String s) {
      sink.add('$prefix $s'.trim());
      return s;
    };
  }

  // Create a channel that logs the data going through it.
  final loggedInput = rawStringChannel.stream.map(logTraffic('==>'));
  final loggedOutputController = StreamController<String>();
  unawaited(
    loggedOutputController.stream
        .map(logTraffic('<=='))
        .pipe(rawStringChannel.sink),
  );

  return StreamChannel<String>(loggedInput, loggedOutputController.sink);
}

/// An implementation of DTD Manager that logs traffic to [logSink] and can
/// optionally delay or fail connections to DTD for testing.
class TestingDTDManager extends DTDManager {
  TestingDTDManager(
    this.logSink, {
    this.failConnectionCount = 0,
    this.connectionDelay = const Duration(seconds: 1),
  });

  /// The number of connections to fail before connecting.
  var failConnectionCount = 0;

  /// The delay for each connection attempt.
  final Duration connectionDelay;

  /// The sink to write protocol traffic to.
  final StreamSink<String> logSink;

  @override
  Future<DartToolingDaemon> connectDtdImpl(Uri uri) async {
    await Future.delayed(connectionDelay);

    if (failConnectionCount > 0) {
      failConnectionCount--;
      throw 'Connection failed';
    }

    final channel = await createLoggedWebSocketChannel(uri, logSink);
    return DartToolingDaemon.fromStreamChannel(channel);
  }
}
