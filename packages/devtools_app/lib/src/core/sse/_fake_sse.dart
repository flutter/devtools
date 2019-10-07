import 'dart:async';

/// A shim that immitates the interface of SseClient from package:sse.
///
/// This allows us to run DevTools in environments that don't have dart:html
/// available, like the Flutter desktop embedder.
// TODO(https://github.com/flutter/devtools/issues/1122): Make SSE work without dart:html.
class SseClient {
  SseClient(String endpoint);
  Stream get stream => null;
  Stream get onOpen => null;
  StreamSink get sink => null;
}
