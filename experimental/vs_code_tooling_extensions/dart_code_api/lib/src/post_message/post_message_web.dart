import 'dart:html' as html;

import 'post_message.dart';

Stream<PostMessageEvent> get onPostMessage {
  return html.window.onMessage.map(
    (message) => PostMessageEvent(
      origin: message.origin,
      data: message.data,
    ),
  );
}

void postMessage(Map<String, Object?> message, String origin) =>
    html.window.parent?.postMessage(message, origin);
