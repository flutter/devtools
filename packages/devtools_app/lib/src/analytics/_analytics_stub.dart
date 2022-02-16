// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../primitives/utils.dart';
import 'analytics_common.dart';

Future<void> setAnalyticsEnabled(bool value) async {}

FutureOr<bool> isAnalyticsEnabled() => false;

void initializeGA() {}

void jsHookupListenerForGA() {}

Future<void> enableAnalytics() async {}

Future<void> disableAnalytics() async {}

void screen(
  String screenName, [
  int value = 0,
]) {}

void timeStart(String screenName, String timedOperation) {}

void timeEnd(
  String screenName,
  String timedOperation, {
  ScreenAnalyticsMetrics Function() screenMetricsProvider,
}) {}

void timeSync(
  String screenName,
  String timedOperation, {
  @required void Function() syncOperation,
  ScreenAnalyticsMetrics Function() screenMetricsProvider,
}) {
  // Execute the operation here so that the desktop app still functions without
  // the real analytics call.
  try {
    syncOperation();
  } on ProcessCancelledException catch (_) {
    // Do nothing for instances of [ProcessCancelledException].
  }
}

Future<void> timeAsync(
  String screenName,
  String timedOperation, {
  @required Future<void> Function() asyncOperation,
  ScreenAnalyticsMetrics Function() screenMetricsProvider,
}) async {
  // Execute the operation here so that the desktop app still functions without
  // the real analytics call.
  try {
    await asyncOperation();
  } on ProcessCancelledException catch (_) {
    // Do nothing for instances of [ProcessCancelledException].
  }
}

void select(
  String screenName,
  String selectedItem, {
  int value = 0,
  bool nonInteraction,
  ScreenAnalyticsMetrics Function() screenMetricsProvider,
}) {}

void reportError(
  String errorMessage, {
  bool fatal = false,
}) {}

Future<void> setupDimensions() async {}

Future<void> setupUserApplicationDimensions() async {}

Map<String, dynamic> generateSurveyQueryParameters() => {};
