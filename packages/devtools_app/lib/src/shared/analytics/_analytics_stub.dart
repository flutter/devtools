// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Avoid unused parameters does not play well with conditional imports.
// ignore_for_file: avoid-unused-parameters
// ignore_for_file: avoid-redundant-async

import 'dart:async';

import 'package:logging/logging.dart';

import 'analytics_common.dart';

final _log = Logger('_analytics_stub');

/// The IDE that DevTools was launched from.
///
/// This is just a stub value so that we can access the [ideLaunched] field on
/// both web and desktop, and manipulate this value for tests running on the VM.
String ideLaunched = '';

Future<void> setAnalyticsEnabled(bool value) async {}

FutureOr<bool> isAnalyticsEnabled() => false;

void initializeGA() {}

void jsHookupListenerForGA() {}

Future<void> enableAnalytics() async {}

Future<void> disableAnalytics() async {}

Future<String> fetchAnalyticsConsentMessage() async =>
    'stubbed consent message';

Future<void> markConsentMessageAsShown() async {}

void screen(
  String screenName, [
  int value = 0,
]) {
  _log.fine('Event: screen(screenName:$screenName, value:$value)');
}

void timeStart(String screenName, String timedOperation) {}

void timeEnd(
  String screenName,
  String timedOperation, {
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {}

void cancelTimingOperation(String screenName, String timedOperation) {}

void timeSync(
  String screenName,
  String timedOperation, {
  required void Function() syncOperation,
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {
  // Execute the operation here so that the desktop app still functions without
  // the real analytics call.
  syncOperation();
}

Future<void> timeAsync(
  String screenName,
  String timedOperation, {
  required Future<void> Function() asyncOperation,
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) async {
  // Execute the operation here so that the desktop app still functions without
  // the real analytics call.
  await asyncOperation();
}

void select(
  String screenName,
  String selectedItem, {
  int value = 0,
  bool nonInteraction = false,
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {
  _log.fine(
    'Event: select('
    'screenName:$screenName, '
    'selectedItem:$selectedItem, '
    'value:$value, '
    'nonInteraction:$nonInteraction)',
  );
}

void impression(
  String screenName,
  String item, {
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {
  _log.fine(
    'Event: impression('
    'screenName:$screenName, '
    'item:$item)',
  );
}

void reportError(
  String errorMessage, {
  bool fatal = false,
  ScreenAnalyticsMetrics Function()? screenMetricsProvider,
}) {}

Future<void> setupDimensions() async {}

void setupUserApplicationDimensions() {}

Map<String, dynamic> generateSurveyQueryParameters() => {};
