// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_classes_with_only_static_members

part of '../server_api.dart';

abstract class _SurveyHandler {
  static shelf.Response setActiveSurvey(
    ServerApi api,
    Map<String, String> queryParams,
    DevToolsUsage devToolsStore,
  ) {
    final missingRequiredParams = ServerApi._checkRequiredParameters(
      [apiParameterValueKey],
      queryParams: queryParams,
      api: api,
      requestName: ReleaseNotesApi.setLastReleaseNotesVersion,
    );
    if (missingRequiredParams != null) return missingRequiredParams;

    final surveyName = queryParams[apiParameterValueKey]!;
    devToolsStore.activeSurvey = surveyName;
    return ServerApi._encodeResponse(true, api: api);
  }

  static shelf.Response getSurveyActionTaken(
    ServerApi api,
    DevToolsUsage devToolsStore,
  ) {
    final activeSurveySet = _checkActiveSurveySet(api, devToolsStore);
    if (activeSurveySet != null) return activeSurveySet;

    return ServerApi._encodeResponse(devToolsStore.surveyActionTaken, api: api);
  }

  static shelf.Response setSurveyActionTaken(
    ServerApi api,
    DevToolsUsage devToolsStore,
  ) {
    final activeSurveySet = _checkActiveSurveySet(api, devToolsStore);
    if (activeSurveySet != null) return activeSurveySet;

    devToolsStore.surveyActionTaken = true;
    return ServerApi._encodeResponse(devToolsStore.surveyActionTaken, api: api);
  }

  static shelf.Response getSurveyShownCount(
    ServerApi api,
    DevToolsUsage devToolsStore,
  ) {
    final activeSurveySet = _checkActiveSurveySet(api, devToolsStore);
    if (activeSurveySet != null) return activeSurveySet;

    return ServerApi._encodeResponse(devToolsStore.surveyShownCount, api: api);
  }

  static shelf.Response incrementSurveyShownCount(
    ServerApi api,
    DevToolsUsage devToolsStore,
  ) {
    final activeSurveySet = _checkActiveSurveySet(api, devToolsStore);
    if (activeSurveySet != null) return activeSurveySet;

    devToolsStore.incrementSurveyShownCount();
    return ServerApi._encodeResponse(devToolsStore.surveyShownCount, api: api);
  }

  static const _errorNoActiveSurvey = 'ERROR: setActiveSurvey not called.';

  static shelf.Response? _checkActiveSurveySet(
    ServerApi api,
    DevToolsUsage devToolsStore,
  ) {
    return devToolsStore.activeSurvey == null
        ? api.badRequest(
            '$_errorNoActiveSurvey '
            '- ${SurveyApi.getSurveyActionTaken}',
          )
        : null;
  }
}
