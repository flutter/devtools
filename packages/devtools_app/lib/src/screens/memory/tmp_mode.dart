import '../../shared/globals.dart';

enum DevToolsMode {
  /// Not interacting with app or data from a previous session.
  disconnected,

  /// Interacting with a connected application.
  connected,

  /// Showing data saved from a previous session and ignoring connection status.
  offlineData,
}

DevToolsMode get devToolsMode {
  return offlineDataController.showingOfflineData.value
      ? DevToolsMode.offlineData
      : serviceConnection.serviceManager.hasConnection
          ? DevToolsMode.connected
          : DevToolsMode.disconnected;
}
