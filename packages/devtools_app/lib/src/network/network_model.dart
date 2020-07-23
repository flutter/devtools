import 'package:vm_service/vm_service.dart';

import '../http/http_request_data.dart';
import '../utils.dart';

abstract class NetworkRequest {
  NetworkRequest(this._timelineMicrosBase);

  final int _timelineMicrosBase;

  String get method;

  String get uri;

  String get contentType;

  String get type;

  Duration get duration;

  DateTime get startTimestamp;

  DateTime get endTimestamp;

  String get status;

  int get port;

  String get durationDisplay =>
      'Duration: ${duration != null ? msText(duration) : 'Pending'}';

  int timelineMicrosecondsSinceEpoch(int micros) {
    return _timelineMicrosBase + micros;
  }
}

class WebSocket extends NetworkRequest {
  WebSocket(this._socket, int timelineMicrosBase) : super(timelineMicrosBase);

  final SocketStatistic _socket;

  int get id => _socket.id;

  @override
  Duration get duration {
    if (_socket.startTime == null || _socket.endTime == null) {
      return null;
    }
    return Duration(microseconds: _socket.endTime - _socket.startTime);
  }

  @override
  DateTime get startTimestamp => DateTime.fromMicrosecondsSinceEpoch(
      timelineMicrosecondsSinceEpoch(_socket.startTime));

  @override
  DateTime get endTimestamp => _socket.endTime != null
      ? DateTime.fromMicrosecondsSinceEpoch(
          timelineMicrosecondsSinceEpoch(_socket.endTime))
      : null;

  DateTime get lastReadTimestamp => _socket.lastReadTime != null
      ? DateTime.fromMicrosecondsSinceEpoch(
          timelineMicrosecondsSinceEpoch(_socket.lastReadTime))
      : null;

  DateTime get lastWriteTimestamp => _socket.lastWriteTime != null
      ? DateTime.fromMicrosecondsSinceEpoch(
          timelineMicrosecondsSinceEpoch(_socket.lastWriteTime))
      : null;

  @override
  String get contentType => 'websocket';

  @override
  String get type => 'ws';

  String get socketType => _socket.socketType;

  @override
  String get uri => _socket.address;

  @override
  int get port => _socket.port;

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
  })  : assert(requests != null),
        assert(invalidHttpRequests != null),
        assert(outstandingHttpRequests != null);

  /// A list of network requests.
  ///
  /// Individual requests in this list can be either completed or in-progress.
  List<NetworkRequest> requests;

  /// A list of invalid HTTP requests received.
  ///
  /// These are requests that have completed but do not contain all the required
  /// information to display normally in the UI.
  List<HttpRequestData> invalidHttpRequests;

  /// A mapping of timeline IDs to instances of HttpRequestData which are
  /// currently in-progress.
  Map<String, HttpRequestData> outstandingHttpRequests;

  void clear() {
    requests.clear();
    outstandingHttpRequests.clear();
  }
}
