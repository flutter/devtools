// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// All server APIs prefix:
const apiPrefix = 'api/';

/// Flutter GA properties APIs:
const apiGetFlutterGAEnabled = '${apiPrefix}getFlutterGAEnabled';
const apiGetFlutterGAClientId = '${apiPrefix}getFlutterGAClientId';

/// DevTools GA properties APIs:
const apiResetDevTools = '${apiPrefix}resetDevTools';
const apiGetDevToolsFirstRun = '${apiPrefix}getDevToolsFirstRun';
const apiGetDevToolsEnabled = '${apiPrefix}getDevToolsEnabled';
const apiSetDevToolsEnabled = '${apiPrefix}setDevToolsEnabled';

/// Property name to apiSetDevToolsEnabled the DevToolsEnabled is the name used
/// in queryParameter:
const devToolsEnabledPropertyName = 'enabled';

/// Survey properties APIs:
/// setActiveSurvey sets the survey property to fetch and save JSON values e.g., Q1-2020
const apiSetActiveSurvey = '${apiPrefix}setActiveSurvey';

/// Survey name passed in apiSetActiveSurvey, the activeSurveyName is the property name
/// passed as a queryParameter and is the property in ~/.devtools too.
const activeSurveyName = 'activeSurveyName';

/// Returns the surveyActionTaken of the activeSurvey (apiSetActiveSurvey).
const apiGetSurveyActionTaken = '${apiPrefix}getSurveyActionTaken';

/// Sets the surveyActionTaken of the of the activeSurvey (apiSetActiveSurvey).
const apiSetSurveyActionTaken = '${apiPrefix}setSurveyActionTaken';

/// Property name to apiSetSurveyActionTaken the surveyActionTaken is the name
/// passed in queryParameter:
const surveyActionTakenPropertyName = 'surveyActionTaken';

/// Returns the surveyShownCount of the of the activeSurvey (apiSetActiveSurvey).
const apiGetSurveyShownCount = '${apiPrefix}getSurveyShownCount';

/// Increments the surveyShownCount of the of the activeSurvey (apiSetActiveSurvey).
const apiIncrementSurveyShownCount = '${apiPrefix}incrementSurveyShownCount';

const lastReleaseNotesVersionPropertyName = 'lastReleaseNotesVersion';

/// Returns the last DevTools version for which we have shown release notes.
const apiGetLastReleaseNotesVersion = '${apiPrefix}getLastReleaseNotesVersion';

/// Sets the last DevTools version for which we have shown release notes.
const apiSetLastReleaseNotesVersion = '${apiPrefix}setLastReleaseNotesVersion';

/// Returns the base app size file, if present.
const apiGetBaseAppSizeFile = '${apiPrefix}getBaseAppSizeFile';

/// Returns the test app size file used for comparing two files in a diff, if
/// present.
const apiGetTestAppSizeFile = '${apiPrefix}getTestAppSizeFile';

const baseAppSizeFilePropertyName = 'appSizeBase';

const testAppSizeFilePropertyName = 'appSizeTest';

abstract class ExtensionsApi {
  /// Serves any available extensions and returns a list of their configurations
  /// to DevTools.
  static const apiServeAvailableExtensions =
      '${apiPrefix}serveAvailableExtensions';

  /// The property name for the query parameter passed along with
  /// extension-related requests to the server that describes the package root
  /// for the app whose extensions are being queried.
  static const extensionRootPathPropertyName = 'rootPath';

  /// The property name for the response that the server sends back upon
  /// receiving a [apiServeAvailableExtensions] request.
  static const extensionsResultPropertyName = 'extensions';

  /// Returns and optionally sets the enabled state for a DevTools extension.
  static const apiExtensionEnabledState = '${apiPrefix}extensionEnabledState';

  /// The property name for the query parameter passed along with
  /// [apiExtensionEnabledState] requests to the server that describes the
  /// name of the extension whose state is being queried.
  static const extensionNamePropertyName = 'name';

  /// The property name for the query parameter that is optionally passed along
  /// with [apiExtensionEnabledState] requests to the server to set the
  /// enabled state for the extension.
  static const enabledStatePropertyName = 'enable';
}
