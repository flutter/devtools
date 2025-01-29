// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A record of a [StreamChannel] and a [Stream] of logs of protocol traffic
/// in both directions across it.
typedef LoggedChannel = ({StreamChannel<String> channel, Stream<String> log});

/// Connects to the websocket at [wsUri] and returns a channel along with
/// a log stream that includes all protocol traffic.
Future<LoggedChannel> createLoggedWebSocketChannel(Uri wsUri) async {
  final logController = StreamController<String>();

  final rawChannel = WebSocketChannel.connect(wsUri);
  await rawChannel.ready;
  final rawStringChannel = rawChannel.cast<String>();

  /// A helper to create a function that can be used in stream.map() to log
  /// traffic with a prefix.
  String Function(String) logTraffic(String prefix) {
    return (String s) {
      logController.add('$prefix $s'.trim());
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

  return (
    channel: StreamChannel<String>(loggedInput, loggedOutputController.sink),
    log: logController.stream,
  );
}
