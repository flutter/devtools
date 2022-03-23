// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../http/http_request_data.dart';
import '../../primitives/utils.dart';
import '../../ui/search.dart';

abstract class NetworkRequest with DataSearchStateMixin {
  NetworkRequest(this._timelineMicrosBase);

  final int _timelineMicrosBase;

  String get method;

  String get uri;

  String? get contentType;

  String get type;

  Duration? get duration;

  DateTime? get startTimestamp;

  DateTime? get endTimestamp;

  String? get status;

  int? get port;

  bool get didFail;

  /// True if the request hasn't completed yet.
  bool get inProgress;

  String get durationDisplay {
    final duration = this.duration;
    return 'Duration: ${duration != null ? msText(duration) : 'Pending'}';
  }

  int timelineMicrosecondsSinceEpoch(int micros) {
    return _timelineMicrosBase + micros;
  }

  @override
  String toString() => '$method $uri';

  @override
  bool operator ==(other) {
    return other is NetworkRequest &&
        runtimeType == other.runtimeType &&
        startTimestamp == other.startTimestamp &&
        method == other.method &&
        uri == other.uri &&
        contentType == other.contentType &&
        type == other.type &&
        port == other.port &&
        (inProgress == other.inProgress
            ? (endTimestamp == other.endTimestamp &&
                duration == other.duration &&
                status == other.status &&
                didFail == other.didFail)
            : true);
  }

  @override
  int get hashCode => hashValues(
        method,
        uri,
        contentType,
        type,
        port,
        startTimestamp,
      );
}

class WebSocket extends NetworkRequest {
  WebSocket(this._socket, int timelineMicrosBase) : super(timelineMicrosBase);

  final SocketStatistic _socket;

  int get id => _socket.id;

  @override
  Duration? get duration {
    final endTime = _socket.endTime;
    if (endTime == null) {
      return null;
    }
    return Duration(microseconds: endTime - _socket.startTime);
  }

  @override
  DateTime get startTimestamp => DateTime.fromMicrosecondsSinceEpoch(
      timelineMicrosecondsSinceEpoch(_socket.startTime));

  @override
  DateTime? get endTimestamp {
    final endTime = _socket.endTime;
    return endTime != null
        ? DateTime.fromMicrosecondsSinceEpoch(
            timelineMicrosecondsSinceEpoch(endTime))
        : null;
  }

  DateTime? get lastReadTimestamp {
    final lastReadTime = _socket.lastReadTime;
    return lastReadTime != null
        ? DateTime.fromMicrosecondsSinceEpoch(
            timelineMicrosecondsSinceEpoch(lastReadTime))
        : null;
  }

  DateTime? get lastWriteTimestamp {
    final lastWriteTime = _socket.lastWriteTime;
    return lastWriteTime != null
        ? DateTime.fromMicrosecondsSinceEpoch(
            timelineMicrosecondsSinceEpoch(lastWriteTime))
        : null;
  }

  @override
  String get contentType => 'websocket';

  @override
  String get type => 'ws';

  String get socketType => _socket.socketType;

  @override
  String get uri => _socket.address;

  @override
  int get port => _socket.port;

  // TODO(kenz): what determines a web socket request failure?
  @override
  bool get didFail => false;

  int get readBytes => _socket.readBytes;

  int get writeBytes => _socket.writeBytes;

  // TODO(kenz): is this always GET? Chrome DevTools shows GET in the response
  // headers for web socket traffic.
  @override
  String get method => 'GET';

  // TODO(kenz): is this always 101? Chrome DevTools lists "101" for WS status
  // codes with a tooltip of "101 Web Socket Protocol Handshake"
  @override
  String get status => '101';

  @override
  bool get inProgress => false;

  @override
  bool operator ==(other) => other is WebSocket && id == other.id;

  @override
  int get hashCode => id;
}

/// Contains all state relevant to completed and in-progress network requests.
class NetworkRequests {
  NetworkRequests({
    this.requests = const [],
    this.invalidHttpRequests = const [],
    this.outstandingHttpRequests = const {},
  });

  /// A list of network requests.
  ///
  /// Individual requests in this list can be either completed or in-progress.
  List<NetworkRequest> requests;

  /// A list of invalid HTTP requests received.
  ///
  /// These are requests that have completed but do not contain all the required
  /// information to display normally in the UI.
  List<DartIOHttpRequestData> invalidHttpRequests;

  /// A mapping of timeline IDs to instances of HttpRequestData which are
  /// currently in-progress.
  Map<String, DartIOHttpRequestData> outstandingHttpRequests;

  void clear() {
    requests.clear();
    outstandingHttpRequests.clear();
  }
}
