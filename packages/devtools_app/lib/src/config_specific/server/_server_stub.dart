import 'dart:async';

const unsupportedMessage =
    'Unsupported RPC: The DevTools Server is not available on Desktop';

bool get isDevToolsServerAvailable => false;

Future<bool> isFirstRun() async {
  throw Exception(unsupportedMessage);
}

Future<bool> isAnalyticsEnabled() async {
  throw Exception(unsupportedMessage);
}

Future<bool> setAnalyticsEnabled([bool value = true]) async {
  throw Exception(unsupportedMessage);
}

Future<String> flutterGAClientID() async {
  throw Exception(unsupportedMessage);
}

Future<void> resetDevToolsFile() async {
  throw Exception(unsupportedMessage);
}

void logWarning() {
  throw Exception(unsupportedMessage);
}
