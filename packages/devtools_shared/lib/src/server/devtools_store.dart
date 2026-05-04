// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'file_system.dart';

enum DevToolsStoreKeys {
  /// The key holding the value for whether Google Analytics (legacy) for
  /// DevTools have been enabled.
  @Deprecated(
    'Use unified_analytics instead; this key is for legacy analytics and will '
    'be removed.',
  )
  analyticsEnabled,

  /// The key holding the value for whether this is a user's first run of
  /// DevTools.
  @Deprecated(
    'This key was used for legacy analytics and will be removed.',
  )
  isFirstRun,

  /// The key holding the value for the last DevTools version that the user
  /// viewed release notes for.
  lastReleaseNotesVersion,

  /// The key holding the value for whether the user has taken action on the
  /// DevTools survey prompt.
  surveyActionTaken,

  /// The key holding the value for number of times the user has seen the
  /// DevTools survey prompt without taking action.
  surveyShownCount,
}

/// Provides access to the local DevTools store (~/.flutter-devtools/.devtools).
class DevToolsUsage {
  DevToolsUsage() {
    LocalFileSystem.maybeMoveLegacyDevToolsStore();
    properties = IOPersistentProperties(
      storeName,
      documentDirPath: LocalFileSystem.devToolsDir(),
    );
    _removeLegacyKeys();
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

  void _removeLegacyKeys() {
    // TODO(https://github.com/flutter/devtools/issues/9775): remove this logic
    // once legacy keys have been removed for ~1 year.
    properties
      ..remove(DevToolsStoreKeys.analyticsEnabled.name)
      ..remove(DevToolsStoreKeys.isFirstRun.name);
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
      DevToolsStoreKeys.surveyActionTaken.name: actionTaken,
      DevToolsStoreKeys.surveyShownCount.name: shownCount,
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
    return (properties[DevToolsStoreKeys.lastReleaseNotesVersion.name] ??= '')
        as String;
  }

  set lastReleaseNotesVersion(String value) {
    properties[DevToolsStoreKeys.lastReleaseNotesVersion.name] = value;
  }
}

extension type _ActiveSurveyJson(Map<String, Object?> json) {
  bool get surveyActionTaken =>
      json[DevToolsStoreKeys.surveyActionTaken.name] as bool;
  int? get surveyShownCount =>
      json[DevToolsStoreKeys.surveyShownCount.name] as int?;
}
