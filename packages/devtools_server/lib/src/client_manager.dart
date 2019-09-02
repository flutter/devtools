import 'package:sse/server/sse_handler.dart';

class ClientManager {
  final List<DevToolsClient> _clients = [];
  void acceptClient(SseConnection connection) {
    _clients.add(DevToolsClient(connection));

    // TODO(dantup): How do we know when a connection goes away to remove it?
  }

  /// Finds an active DevTools instance that is not already connecting to
  /// a VM service that we can reuse (for example if a user stopped debugging
  /// and it disconnected, then started debugging again, we want to reuse
  /// the open DevTools window).
  Future<DevToolsClient> findReusableClient() async {
    // TODO(dantup):
    return null;
  }
}

class DevToolsClient {
  DevToolsClient(this._connection) {
    // DEBU
    _connection.stream.listen((msg) {
      print(msg);
      _connection.sink.add('Server got $msg!');
    });
  }

  Future<void> connectToVmService(Uri uri) async {
    // TODO(dantup):
  }

  final SseConnection _connection;
}
