// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// All server APIs prefix:
const String apiPrefix = 'api/';

// Flutter GA properties APIs:
const String apiGetFlutterGAEnabled = '${apiPrefix}getFlutterGAEnabled';
const String apiGetFlutterGAClientId = '${apiPrefix}getFlutterGAClientId';

// DevTools GA properties APIs:
const String apiResetDevTools = '${apiPrefix}resetDevTools';
const String apiGetDevToolsFirstRun = '${apiPrefix}getDevToolsFirstRun';
const String apiGetDevToolsEnabled = '${apiPrefix}getDevToolsEnabled';
const String apiSetDevToolsEnabled = '${apiPrefix}setDevToolsEnabled';
// Property name to apiSetDevToolsEnabled the DevToolsEnabled is the name used
// in queryParameter:
const String devToolsEnabledPropertyName = 'enabled';

// Survey properties APIs:
const String apiGetSurveyActionTaken = '${apiPrefix}getSurveyActionTaken';
const String apiSetSurveyActionTaken = '${apiPrefix}setSurveyActionTaken';
// Property name to apiSetSurveyActionTaken the surveyActionTaken is the name
// used in queryParameter:
const String surveyActionTakenPropertyName = 'surveyActionTaken';

const String apiGetSurveyShownCount = '${apiPrefix}getSurveyShownCount';
const String apiIncrementSurveyShownCount =
    '${apiPrefix}incrementSurveyShownCount';
