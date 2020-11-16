import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

class LocalFileSystem {
  static String userHomeDir() {
    final String envKey =
        Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
    final String value = Platform.environment[envKey];
    return value == null ? '.' : value;
  }

  static File file(String pathFromHomeDir) {
    final file = File('${userHomeDir()}/$pathFromHomeDir');
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  static String fileAsJson(String pathFromHomeDir) {
    final _file = file(pathFromHomeDir);
    if (_file == null) return null;

    final fileName = path.basename(_file.path);
    if (!fileName.endsWith('.json')) return null;

    final content = _file.readAsStringSync();
    final json = jsonDecode(content);
    json['lastModifiedTime'] = _file.lastModifiedSync().toString();
    return jsonEncode(json);
  }
}
