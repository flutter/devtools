// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'file_system.dart';

// Access the DevTools on disk store (~/.flutter-devtools/.devtools).
class DevToolsUsage {
  DevToolsUsage() {
    LocalFileSystem.maybeMoveLegacyDevToolsStore();

    properties = IOPersistentProperties(
      storeName,
      documentDirPath: LocalFileSystem.devToolsDir(),
    );
  }

  static const storeName = '.devtools';

  /// The activeSurvey is the property name of a top-level property
  /// existing or created in the file '~/.devtools'.
  ///
  /// If the property doesn't exist it is created with default survey values:
  ///
  ///     properties[activeSurvey]['surveyActionTaken'] = false;
  ///     properties[activeSurvey]['surveyShownCount'] = 0;
  ///
  /// It is a requirement that the API `apiSetActiveSurvey` must be called
  /// before calling any survey method on `DevToolsUsage` (`addSurvey`,
  /// `rewriteActiveSurvey`, `surveyShownCount`, `incrementSurveyShownCount`, or
  /// `surveyActionTaken`).
  String? _activeSurvey;

  late IOPersistentProperties properties;

  static const _surveyActionTaken = 'surveyActionTaken';
  static const _surveyShownCount = 'surveyShownCount';

  void reset() {
    // TODO(kenz): remove this in Feb 2022. See
    // https://github.com/flutter/devtools/issues/3264. The `firstRun` property
    // has been replaced by `isFirstRun`. This is to force all users to answer
    // the analytics dialog again. The 'enabled' property has been replaced by
    // 'analyticsEnabled' for better naming.
    properties.remove('firstRun');
    properties.remove('enabled');

    properties.remove('firstDevToolsRun');
    properties['analyticsEnabled'] = false;
  }

  bool get isFirstRun {
    // TODO(kenz): remove this in Feb 2022. See
    // https://github.com/flutter/devtools/issues/3264.The `firstRun` property
    // has been replaced by `isFirstRun`. This is to force all users to answer
    // the analytics dialog again.
    properties.remove('firstRun');

    return properties['isFirstRun'] = properties['isFirstRun'] == null;
  }

  bool get analyticsEnabled {
    // TODO(kenz): remove this in Feb 2022. See
    // https://github.com/flutter/devtools/issues/3264. The `enabled` property
    // has been replaced by `analyticsEnabled` for better naming.
    if (properties['enabled'] != null) {
      properties['analyticsEnabled'] = properties['enabled'];
      properties.remove('enabled');
    }

    return properties['analyticsEnabled'] =
        properties['analyticsEnabled'] == true;
  }

  set analyticsEnabled(bool value) {
    properties['analyticsEnabled'] = value;
  }

  bool surveyNameExists(String surveyName) => properties[surveyName] != null;

  void _addSurvey(String surveyName) {
    assert(activeSurvey != null);
    assert(activeSurvey == surveyName);
    rewriteActiveSurvey(false, 0);
  }

  String? get activeSurvey => _activeSurvey;

  set activeSurvey(String? surveyName) {
    assert(surveyName != null);
    _activeSurvey = surveyName;

    if (!surveyNameExists(activeSurvey!)) {
      // Create the survey if property is non-existent in ~/.devtools
      _addSurvey(activeSurvey!);
    }
  }

  /// Need to rewrite the entire survey structure for property to be persisted.
  void rewriteActiveSurvey(bool actionTaken, int shownCount) {
    assert(activeSurvey != null);
    properties[activeSurvey!] = {
      _surveyActionTaken: actionTaken,
      _surveyShownCount: shownCount,
    };
  }

  /// The active survey in [properties], as a [_ActiveSurveyJson].
  _ActiveSurveyJson get _activeSurveyFromProperties => _ActiveSurveyJson(
        (properties[activeSurvey!] as Map).cast<String, Object?>(),
      );

  int get surveyShownCount {
    assert(activeSurvey != null);
    final prop = _activeSurveyFromProperties;
    if (prop.surveyShownCount == null) {
      rewriteActiveSurvey(prop.surveyActionTaken, 0);
    }
    return _activeSurveyFromProperties.surveyShownCount!;
  }

  void incrementSurveyShownCount() {
    assert(activeSurvey != null);
    surveyShownCount; // Ensure surveyShownCount has been initialized.
    final prop = _activeSurveyFromProperties;
    rewriteActiveSurvey(
      prop.surveyActionTaken,
      prop.surveyShownCount! + 1,
    );
  }

  bool get surveyActionTaken {
    return _activeSurveyFromProperties.surveyActionTaken;
  }

  set surveyActionTaken(bool value) {
    rewriteActiveSurvey(
      value,
      _activeSurveyFromProperties.surveyShownCount!,
    );
  }

  String get lastReleaseNotesVersion {
    return (properties['lastReleaseNotesVersion'] ??= '') as String;
  }

  set lastReleaseNotesVersion(String value) {
    properties['lastReleaseNotesVersion'] = value;
  }
}

extension type _ActiveSurveyJson(Map<String, Object?> json) {
  bool get surveyActionTaken => json[DevToolsUsage._surveyActionTaken] as bool;
  int? get surveyShownCount => json[DevToolsUsage._surveyShownCount] as int?;
}

abstract class PersistentProperties {
  PersistentProperties(this.name);

  final String name;

  // ignore: avoid-dynamic, dynamic by design.
  dynamic operator [](String key);

  // ignore: avoid-dynamic, dynamic by design.
  void operator []=(String key, dynamic value);

  /// Re-read settings from the backing store.
  ///
  /// May be a no-op on some platforms.
  void syncSettings();
}

const _jsonEncoder = JsonEncoder.withIndent('  ');

class IOPersistentProperties extends PersistentProperties {
  IOPersistentProperties(
    String name, {
    String? documentDirPath,
  }) : super(name) {
    final fileName = name.replaceAll(' ', '_');
    documentDirPath ??= LocalFileSystem.devToolsDir();
    _file = File(path.join(documentDirPath, fileName));
    if (!_file.existsSync()) {
      _file.createSync(recursive: true);
    }
    syncSettings();
  }

  IOPersistentProperties.fromFile(File file) : super(path.basename(file.path)) {
    _file = file;
    if (!_file.existsSync()) {
      _file.createSync(recursive: true);
    }
    syncSettings();
  }

  late File _file;

  late Map<String, Object?> _map;

  @override
  // ignore: avoid-dynamic, necessary here.
  dynamic operator [](String key) => _map[key];

  @override
  void operator []=(String key, Object? value) {
    if (value == null && !_map.containsKey(key)) return;
    if (_map[key] == value) return;

    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }

    try {
      _file.writeAsStringSync('${_jsonEncoder.convert(_map)}\n');
    } catch (_) {}
  }

  @override
  void syncSettings() {
    try {
      String contents = _file.readAsStringSync();
      if (contents.isEmpty) contents = '{}';
      _map = (jsonDecode(contents) as Map).cast<String, Object>();
    } catch (_) {
      _map = {};
    }
  }

  void remove(String propertyName) {
    _map.remove(propertyName);
  }
}
