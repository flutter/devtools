// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:devtools_app_shared/service.dart';
import 'package:intl/intl.dart';

import '../../framework/screen.dart';
import '../../globals.dart';
import '../../primitives/encoding.dart';
import '../../primitives/utils.dart';
import '../../utils/utils.dart';
import '_export_desktop.dart' if (dart.library.js_interop) '_export_web.dart';

const nonDevToolsFileMessage =
    'The imported file is not a Dart DevTools file.'
    ' At this time, DevTools only supports importing files that were originally'
    ' exported from DevTools.';

String attemptingToImportMessage(String devToolsScreen) {
  return 'Attempting to import file for screen with id "$devToolsScreen".';
}

String successfulExportMessage(String exportedFile) {
  return 'Successfully exported $exportedFile to ~/Downloads directory';
}

enum DevToolsExportKeys {
  devToolsSnapshot,
  devToolsVersion,
  connectedApp,
  activeScreenId,
}

class ImportController {
  ImportController(this._pushSnapshotScreenForImport);

  static const repeatImportTimeBufferMs = 500;

  final void Function(String screenId) _pushSnapshotScreenForImport;

  DateTime? previousImportTime;

  // TODO(kenz): improve error handling here or in snapshot_screen.dart.
  void importData(DevToolsJsonFile jsonFile, {String? expectedScreenId}) {
    // Do not allow two different imports within 500 ms of each other. This is a
    // workaround for the fact that we get two drop events for the same file.
    final now = DateTime.now();
    if (previousImportTime != null &&
        (now.millisecondsSinceEpoch -
                    previousImportTime!.millisecondsSinceEpoch)
                .abs() <
            repeatImportTimeBufferMs) {
      return;
    }
    previousImportTime = now;

    final json = jsonFile.data;
    final isDevToolsSnapshot =
        json is Map<String, Object?> &&
        json[DevToolsExportKeys.devToolsSnapshot.name] == true;
    if (!isDevToolsSnapshot) {
      notificationService.push(nonDevToolsFileMessage);
      return;
    }

    final devToolsOfflineData = _DevToolsOfflineData(json);
    // TODO(kenz): support imports for more than one screen at a time.
    final activeScreenId = devToolsOfflineData.activeScreenId;
    if (expectedScreenId != null && activeScreenId != expectedScreenId) {
      notificationService.push(
        'Expected a data file for screen \'$expectedScreenId\' but received one'
        ' for screen \'$activeScreenId\'. Please open a file for screen \'$expectedScreenId\'.',
      );
      return;
    }

    if (activeScreenId == ScreenMetaData.performance.id) {
      if (devToolsOfflineData.json.containsKey('traceEvents')) {
        notificationService.push(
          'It looks like you are trying to load data that was saved from an '
          'old version of DevTools. This data uses a legacy format that is no '
          'longer supported. To load this file in DevTools, you will need to '
          'downgrade your Flutter version to < 3.22.',
        );
        return;
      }
    }

    final connectedApp = OfflineConnectedApp.parse(
      devToolsOfflineData.connectedApp,
    );
    offlineDataController
      ..startShowingOfflineData(offlineApp: connectedApp)
      ..offlineDataJson = devToolsOfflineData.json;
    notificationService.push(attemptingToImportMessage(activeScreenId));
    _pushSnapshotScreenForImport(activeScreenId);
  }
}

extension type _DevToolsOfflineData(Map<String, Object?> json) {
  Map<String, Object?> get connectedApp {
    final connectedApp = json[DevToolsExportKeys.connectedApp.name] as Map?;
    return connectedApp == null ? {} : connectedApp.cast<String, Object?>();
  }

  String get activeScreenId =>
      json[DevToolsExportKeys.activeScreenId.name] as String;
}

enum ExportFileType {
  json,
  csv,
  yaml,
  data,
  har;

  @override
  String toString() => name;
}

abstract class ExportController {
  factory ExportController() {
    return createExportController();
  }

  const ExportController.impl();

  static String generateFileName({
    String prefix = 'dart_devtools',
    String postfix = '',
    required ExportFileType type,
    DateTime? time,
  }) {
    time ??= DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd_HH:mm:ss.SSS').format(time);
    return '${prefix}_$timestamp$postfix.$type';
  }

  /// Downloads a file with [content]
  /// and pushes notification about success if [notify] is true.
  String downloadFile<T>(
    T content, {
    String? fileName,
    ExportFileType type = ExportFileType.json,
    bool notify = true,
  }) {
    fileName ??= ExportController.generateFileName(type: type);
    saveFile<T>(content: content, fileName: fileName);
    notificationService.push(successfulExportMessage(fileName));
    return fileName;
  }

  /// Saves [content] to the [fileName].
  void saveFile<T>({required T content, required String fileName});

  Map<String, Object?> generateDataForExport({
    required Map<String, Object?> offlineScreenData,
    ConnectedApp? connectedApp,
  }) {
    final contents = {
      DevToolsExportKeys.devToolsSnapshot.name: true,
      DevToolsExportKeys.devToolsVersion.name: devToolsVersion,
      DevToolsExportKeys.connectedApp.name:
          connectedApp?.toJson() ??
          serviceConnection.serviceManager.connectedApp!.toJson(),
      ...offlineScreenData,
    };
    // TODO(kenz): ensure that performance page exports can be loaded properly
    // into the Perfetto UI (ui.perfetto.dev).
    return contents;
  }

  String encode(Map<String, Object?> offlineScreenData) {
    final data = generateDataForExport(offlineScreenData: offlineScreenData);
    return jsonEncode(data, toEncodable: toEncodable);
  }
}
