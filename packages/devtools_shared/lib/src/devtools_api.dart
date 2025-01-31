// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// All server APIs prefix:
const apiPrefix = 'api/';

/// Key used for any request or response to specify a value argument.
const apiParameterValueKey = 'value';

/// Notifies the DevTools server when a DevTools app client connects to a new
/// VM service.
const apiNotifyForVmServiceConnection =
    '${apiPrefix}notifyForVmServiceConnection';
const apiParameterVmServiceConnected = 'connected';

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

abstract class PreferencesApi {
  /// Returns the preference value in the DevTools store file for the key
  /// specified by the [preferenceKeyProperty] query parameter.
  static const getPreferenceValue = '${apiPrefix}getPreferenceValue';

  /// Sets the preference value in the DevTools store file for the key
  /// specified by the [preferenceKeyProperty] query parameter.
  ///
  /// The value must be specified by the [apiParameterValueKey] query parameter.
  static const setPreferenceValue = '${apiPrefix}setPreferenceValue';

  /// The property name for the query parameter passed along with the
  /// [getPreferenceValue] and [setPreferenceValue] requests that describes the
  /// preference key in the DevTools store file.
  static const preferenceKeyProperty = 'key';
}

abstract class SurveyApi {
  /// Sets the active survey value for the DevTools session.
  ///
  /// The active survey is used as a key to get and set values within the
  /// DevTools store file.
  static const setActiveSurvey = '${apiPrefix}setActiveSurvey';

  /// Returns the 'surveyActionTaken' value for the active survey set by
  /// [setActiveSurvey].
  static const getSurveyActionTaken = '${apiPrefix}getSurveyActionTaken';

  /// Sets the 'surveyActionTaken' value for the active survey set by
  /// [setActiveSurvey].
  static const setSurveyActionTaken = '${apiPrefix}setSurveyActionTaken';

  /// Returns the 'surveyShownCount' value for the active survey set by
  /// [setActiveSurvey].
  static const getSurveyShownCount = '${apiPrefix}getSurveyShownCount';

  /// Increments the 'surveyShownCount' value for the active survey set by
  /// [setActiveSurvey].
  static const incrementSurveyShownCount =
      '${apiPrefix}incrementSurveyShownCount';
}

abstract class ReleaseNotesApi {
  /// Returns the last DevTools version for which we have shown release notes.
  static const getLastReleaseNotesVersion =
      '${apiPrefix}getLastReleaseNotesVersion';

  /// Sets the last DevTools version for which we have shown release notes.
  static const setLastReleaseNotesVersion =
      '${apiPrefix}setLastReleaseNotesVersion';
}

abstract class AppSizeApi {
  /// Returns the base app size file, if present.
  static const getBaseAppSizeFile = '${apiPrefix}getBaseAppSizeFile';

  /// Returns the test app size file used for comparing two files in a diff, if
  /// present.
  static const getTestAppSizeFile = '${apiPrefix}getTestAppSizeFile';

  /// The property name for the query parameter passed along with the
  /// [getBaseAppSizeFile] request.
  static const baseAppSizeFilePropertyName = 'appSizeBase';

  /// The property name for the query parameter passed along with the
  /// [getTestAppSizeFile] request.
  static const testAppSizeFilePropertyName = 'appSizeTest';
}

abstract class DtdApi {
  /// Gets the DTD URI from the DevTools server.
  ///
  /// DTD is either started from the user's IDE and passed to the DevTools
  /// server, or it is started directly from the DevTools server.
  static const apiGetDtdUri = '${apiPrefix}getDtdUri';

  /// The property name for the response that the server sends back upon
  /// receiving an [apiGetDtdUri] request.
  static const uriPropertyName = 'dtdUri';
}

abstract class ExtensionsApi {
  /// Serves any available extensions and returns a list of their configurations
  /// to DevTools.
  static const apiServeAvailableExtensions =
      '${apiPrefix}serveAvailableExtensions';

  /// The property name for the query parameter passed along with
  /// extension-related requests to the server that describes the package root
  /// for the app whose extensions are being queried.
  ///
  /// This field is a `file://` URI string and NOT a path.
  static const packageRootUriPropertyName = 'packageRootUri';

  /// The property name for the query parameter, passed along with
  /// [apiExtensionEnabledState] requests, that specifies the location of the
  /// 'devtools_options.yaml' file that is responsible for storing extension
  /// enablement states.
  ///
  /// This field is a `file://` URI string and NOT a path.
  static const devtoolsOptionsUriPropertyName = 'devtoolsOptionsUri';

  /// The property name for the response that the server sends back upon
  /// receiving a [apiServeAvailableExtensions] request.
  static const extensionsResultPropertyName = 'extensions';

  /// The property name for an optional warning message field in the response
  /// that the server sends back upon receiving a [apiServeAvailableExtensions]
  /// request.
  static const extensionsResultWarningPropertyName = 'warning';

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

abstract class DeeplinkApi {
  /// Returns a list of available build variants of the android sub-project.
  ///
  /// The [deeplinkRootPathPropertyName] must be provided.
  static const androidBuildVariants = '${apiPrefix}androidBuildVariants';

  /// Returns app link settings of the android sub-project in json format.
  ///
  /// The [androidBuildVariantPropertyName] and [deeplinkRootPathPropertyName]
  /// must be provided.
  static const androidAppLinkSettings = '${apiPrefix}androidAppLinkSettings';

  /// The property name for the query parameter passed along with
  /// [androidAppLinkSettings] requests to the server that describes the
  /// build variant the api is targeting.
  static const androidBuildVariantPropertyName = 'buildVariant';

  /// Returns available build options of the ios sub-project in json format.
  ///
  /// The [deeplinkRootPathPropertyName] must be provided.
  static const iosBuildOptions = '${apiPrefix}iosBuildOptions';

  /// Returns universal link settings of the ios sub-project in json format.
  ///
  /// The [deeplinkRootPathPropertyName], [xcodeConfigurationPropertyName],
  /// and [xcodeTargetPropertyName] must be provided.
  static const iosUniversalLinkSettings =
      '${apiPrefix}iosUniversalLinkSettings';

  /// The property name for the query parameter passed along with
  /// [iosUniversalLinkSettings] requests to the server that describes the
  /// Xcode configuration the api is targeting.
  static const xcodeConfigurationPropertyName = 'configuration';

  /// The property name for the query parameter passed along with
  /// [iosUniversalLinkSettings] requests to the server that describes the
  /// Xcode `target` the api is targeting.
  static const xcodeTargetPropertyName = 'target';

  /// The property name for the query parameter passed along with
  /// deeplink-related requests to the server that describes the package root
  /// for the app.
  static const deeplinkRootPathPropertyName = 'rootPath';
}
