import 'dart:async';
import 'dart:html' hide Event;
import 'dart:typed_data';

import 'package:vm_service_lib/vm_service_lib.dart';

Future<VmService> connect(
    String host, int port, Completer<Null> finishedCompleter) {
  final WebSocket ws = new WebSocket('ws://$host:$port/ws');

  final Completer<VmService> connectedCompleter = new Completer<VmService>();

  ws.onOpen.listen((_) {
    final Stream<dynamic> inStream =
        convertBroadcastToSingleSubscriber(ws.onMessage)
            .asyncMap<dynamic>((MessageEvent e) {
      if (e.data is String) {
        return e.data;
      } else {
        final FileReader fileReader = new FileReader();
        fileReader.readAsArrayBuffer(e.data);
        return fileReader.onLoadEnd.first.then<ByteData>((ProgressEvent _) {
          final Uint8List list = fileReader.result;
          return new ByteData.view(list.buffer);
        });
      }
    });

    final VmService service = new VmService(
      inStream,
      (String message) => ws.send(message),
    );

    ws.onClose.listen((_) {
      finishedCompleter.complete();
      service.dispose();
    });

    connectedCompleter.complete(service);
  });

  ws.onError.listen((dynamic e) {
    //_logger.fine('Unable to connect to observatory, port ${port}', e);
    if (!connectedCompleter.isCompleted) {
      connectedCompleter.completeError(e);
    }
  });

  return connectedCompleter.future;
}

/// Wraps a broadcast stream as a single-subscription stream to workaround
/// events being dropped for DOM/WebSocket broadcast streams when paused
/// (such as in an asyncMap).
/// https://github.com/dart-lang/sdk/issues/34656
Stream<T> convertBroadcastToSingleSubscriber<T>(Stream<T> stream) {
  final StreamController<T> controller = new StreamController<T>();
  StreamSubscription<T> subscription;
  controller.onListen =
      () => subscription = stream.listen((T e) => controller.add(e));
  controller.onCancel = () => subscription.cancel();
  return controller.stream;
}
