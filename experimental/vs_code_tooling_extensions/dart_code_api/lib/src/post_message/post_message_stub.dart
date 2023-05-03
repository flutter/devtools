import 'post_message.dart';

Stream<PostMessageEvent> get onPostMessage =>
    throw UnsupportedError('unsupported platform');

void postMessage(Map<String, Object?> message, String origin) =>
    throw UnsupportedError('unsupported platform');
