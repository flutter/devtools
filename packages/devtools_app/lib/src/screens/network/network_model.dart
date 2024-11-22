// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/ui/search.dart';

abstract class NetworkRequest
    with ChangeNotifier, SearchableDataMixin, Serializable {
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

  String get id;

  String get durationDisplay {
    final duration = this.duration;
    final text =
        duration != null
            ? durationText(duration, unit: DurationDisplayUnit.milliseconds)
            : 'Pending';
    return 'Duration: $text';
  }

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return uri.caseInsensitiveContains(regExpSearch);
  }

  @override
  String toString() => '$method $uri';

  @override
  bool operator ==(Object other) {
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
  int get hashCode =>
      Object.hash(method, uri, contentType, type, port, startTimestamp);
}

class Socket extends NetworkRequest {
  Socket(this._socket, this._timelineMicrosBase);

  factory Socket.fromJson(Map<String, Object?> json) {
    return Socket(
      SocketStatistic.parse(
        json[SocketJsonKey.socket.name] as Map<String, Object?>,
      )!,
      json[SocketJsonKey.timelineMicrosBase.name] as int,
    );
  }

  int _timelineMicrosBase;

  SocketStatistic _socket;

  int timelineMicrosecondsSinceEpoch(int micros) {
    return _timelineMicrosBase + micros;
  }

  void update(Socket other) {
    _socket = other._socket;
    _timelineMicrosBase = other._timelineMicrosBase;
    notifyListeners();
  }

  @override
  String get id => _socket.id;

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
    timelineMicrosecondsSinceEpoch(_socket.startTime),
  );

  @override
  DateTime? get endTimestamp {
    final endTime = _socket.endTime;
    return endTime != null
        ? DateTime.fromMicrosecondsSinceEpoch(
          timelineMicrosecondsSinceEpoch(endTime),
        )
        : null;
  }

  DateTime? get lastReadTimestamp {
    final lastReadTime = _socket.lastReadTime;
    return lastReadTime != null
        ? DateTime.fromMicrosecondsSinceEpoch(
          timelineMicrosecondsSinceEpoch(lastReadTime),
        )
        : null;
  }

  DateTime? get lastWriteTimestamp {
    final lastWriteTime = _socket.lastWriteTime;
    return lastWriteTime != null
        ? DateTime.fromMicrosecondsSinceEpoch(
          timelineMicrosecondsSinceEpoch(lastWriteTime),
        )
        : null;
  }

  @override
  String get contentType => 'socket';

  @override
  String get type => _socket.socketType;

  String get socketType => _socket.socketType;

  @override
  String get uri => '${_socket.address}:$port';

  @override
  int get port => _socket.port;

  // TODO(kenz): what determines a web socket request failure?
  @override
  bool get didFail => false;

  int get readBytes => _socket.readBytes;

  int get writeBytes => _socket.writeBytes;

  @override
  String get method => 'SOCKET';

  @override
  String get status => _socket.endTime == null ? 'Open' : 'Closed';

  @override
  bool get inProgress => false;

  @override
  bool operator ==(Object other) => other is Socket && id == other.id;

  @override
  int get hashCode => id.hashCode;

  SocketStatistic get socketData => _socket;

  @override
  Map<String, Object?> toJson() {
    return {
      SocketJsonKey.timelineMicrosBase.name: _timelineMicrosBase,
      SocketJsonKey.socket.name: _socket.toJson(),
    };
  }
}

extension on SocketStatistic {
  Map<String, Object?> toJson() {
    return {
      SocketJsonKey.id.name: id,
      SocketJsonKey.startTime.name: startTime,
      SocketJsonKey.endTime.name: endTime,
      //TODO verify if these timings are in correct format
      SocketJsonKey.lastReadTime.name: lastReadTime,
      SocketJsonKey.lastWriteTime.name: lastWriteTime,
      SocketJsonKey.socketType.name: socketType,
      SocketJsonKey.address.name: address,
      SocketJsonKey.port.name: port,
      SocketJsonKey.readBytes.name: readBytes,
      SocketJsonKey.writeBytes.name: writeBytes,
    };
  }
}

enum SocketJsonKey {
  id,
  startTime,
  endTime,
  lastReadTime,
  lastWriteTime,
  socketType,
  address,
  port,
  readBytes,
  writeBytes,
  timelineMicrosBase,
  socket,
}

extension SocketExtension on List<Socket> {
  List<SocketStatistic> get mapToSocketStatistics {
    return map((socket) => socket._socket).toList();
  }
}
