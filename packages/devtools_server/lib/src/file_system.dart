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

  static File fileFromPath(String pathFromHomeDir) {
    final file = File('${userHomeDir()}/$pathFromHomeDir');
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  static String fileAsJson(String pathFromHomeDir) {
    final file = fileFromPath(pathFromHomeDir);
    if (file == null) return null;

    final fileName = path.basename(file.path);
    if (!fileName.endsWith('.json')) return null;

    final content = file.readAsStringSync();
    final json = jsonDecode(content);
    json['lastModifiedTime'] = file.lastModifiedSync().toString();
    return jsonEncode(json);
  }
}
