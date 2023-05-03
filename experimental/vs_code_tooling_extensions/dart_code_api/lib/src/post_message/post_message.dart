export 'post_message_stub.dart' if (dart.library.html) 'post_message_web.dart';

class PostMessageEvent {
  PostMessageEvent({
    required this.origin,
    required this.data,
  });

  final String origin;
  final dynamic data;
}
