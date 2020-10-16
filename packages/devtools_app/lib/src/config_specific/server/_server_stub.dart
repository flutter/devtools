const unsupportedMessage =
    'Unsupported RPC: The DevTools Server is not available on Desktop';

bool get isDevToolsServerAvailable => false;

Future<bool> get isFirstRun async {
  throw Exception(unsupportedMessage);
}

Future<bool> isAnalyticsEnabled() {
  throw Exception(unsupportedMessage);
}

Future<bool> setAnalyticsEnabled([bool value = true]) {
  throw Exception(unsupportedMessage);
}

Future<String> flutterGAClientID() async {
  throw Exception(unsupportedMessage);
}

Future<void> resetDevToolsFile() {
  throw Exception(unsupportedMessage);
}

void logWarning() {
  throw Exception(unsupportedMessage);
}
