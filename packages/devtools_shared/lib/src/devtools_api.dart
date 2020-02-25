// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// All server APIs prefix:
const String apiPrefix = 'api/';

/// Flutter GA properties APIs:
const String apiGetFlutterGAEnabled = '${apiPrefix}getFlutterGAEnabled';
const String apiGetFlutterGAClientId = '${apiPrefix}getFlutterGAClientId';

/// DevTools GA properties APIs:
const String apiResetDevTools = '${apiPrefix}resetDevTools';
const String apiGetDevToolsFirstRun = '${apiPrefix}getDevToolsFirstRun';
const String apiGetDevToolsEnabled = '${apiPrefix}getDevToolsEnabled';
const String apiSetDevToolsEnabled = '${apiPrefix}setDevToolsEnabled';

/// Property name to apiSetDevToolsEnabled the DevToolsEnabled is the name used
/// in queryParameter:
const String devToolsEnabledPropertyName = 'enabled';

/// Survey properties APIs:
/// apiSetSurvey sets the survey property to fetch and save JSON values e.g., Q1-2020 
const String apiSetSurvey = '${apiPrefix}setSurvey';
/// Survey name passed in apiSetSurvey, the surveyName is the property name
/// passed in queryParameter:
const String surveyName = 'surveyName';

/// Returns the name of the active survey (apiSetSurvey) if not set returns empty
/// string.
const String apiGetSurvey = '${apiPrefix}getSurvey';

/// Returns the surveyActionTaken of the apiSetSurvey (if not set returns the old getSurveyActionTaken).
const String apiGetSurveyActionTaken = '${apiPrefix}getSurveyActionTaken';

/// Sets the surveyActionTaken of the apiSetSurvey (if not set sets the old getSurveyActionTaken).
const String apiSetSurveyActionTaken = '${apiPrefix}setSurveyActionTaken';
/// Property name to apiSetSurveyActionTaken the surveyActionTaken is the name
/// passed in queryParameter:
const String surveyActionTakenPropertyName = 'surveyActionTaken';

/// Returns the surveyShownCount of the apiSetSurvey (if not set sets the old surveyShownCount).
const String apiGetSurveyShownCount = '${apiPrefix}getSurveyShownCount';

/// Increments the surveyShownCount of the apiSetSurvey (if not set increments the old surveyShownCount).
const String apiIncrementSurveyShownCount =
    '${apiPrefix}incrementSurveyShownCount';
