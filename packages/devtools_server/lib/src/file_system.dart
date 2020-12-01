import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'usage.dart';

class LocalFileSystem {
  static String _userHomeDir() {
    final String envKey =
        Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
    final String value = Platform.environment[envKey];
    return value == null ? '.' : value;
  }

  /// Returns the path to the DevTools storage directory.
  static String devToolsDir() {
    return path.join(_userHomeDir(), '.devtools');
  }

  /// Moves the .devtools file to ~/.devtools/.devtools if the .devtools file
  /// exists in the user's home directory.
  static void maybeMoveLegacyDevToolsStore() {
    final file = File(path.join(_userHomeDir(), DevToolsUsage.storeName));
    if (file.existsSync()) {
      // Store the existing .devtools file in a tmp file so that we can delete
      // the .devtools file before creating the .devtools directory. Otherwise,
      // we will get a naming conflict.
      final tmp = file.copySync(path.join(_userHomeDir(), '.tmp-devtools'));
      file.deleteSync();

      ensureDevToolsDirectory();

      tmp.copySync(path.join(devToolsDir(), DevToolsUsage.storeName));
      tmp.deleteSync();
    }
  }

  /// Creates the ~/.devtools directory if it does not already exist.
  static void ensureDevToolsDirectory() {
    Directory('${LocalFileSystem.devToolsDir()}').createSync();
  }

  /// Returns a DevTools file from the given path.
  ///
  /// Only files withing ~/.devtools/ can be accessed.
  static File devToolsFileFromPath(String pathFromDevToolsDir) {
    ensureDevToolsDirectory();
    final file = File(path.join(devToolsDir(), pathFromDevToolsDir));
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  /// Returns a DevTools file from the given path as encoded json.
  ///
  /// Only files withing ~/.devtools/ can be accessed.
  static String devToolsFileAsJson(String pathFromDevToolsDir) {
    final file = devToolsFileFromPath(pathFromDevToolsDir);
    if (file == null) return null;

    final fileName = path.basename(file.path);
    if (!fileName.endsWith('.json')) return null;

    final content = file.readAsStringSync();
    final json = jsonDecode(content);
    json['lastModifiedTime'] = file.lastModifiedSync().toString();
    return jsonEncode(json);
  }

  /// Whether the flutter store file exists.
  static bool flutterStoreExists() {
    final flutterStore = File('${_userHomeDir()}/.flutter');
    return flutterStore.existsSync();
  }
}
