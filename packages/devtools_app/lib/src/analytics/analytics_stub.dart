// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

ValueNotifier<bool> gaEnabledNotifier;

Future<void> setAnalyticsEnabled([bool value = true]) async {}

void screen(
  String screenName, [
  int value = 0,
]) {}

void timing(
  String screenName,
  String timedOperation, {
  @required Duration duration,
  int cpuSampleCount,
  int cpuStackDepth,
  int traceEventCount,
}) {}

void select(
  String screenName,
  String selectedItem, [
  int value = 0,
]) {}

void selectFrame(
  String screenName, {
  @required Duration rasterDuration, // Custom metric
  @required Duration uiDuration, // Custom metric
  Duration shaderCompilationDuration, // Custom metric
}) {}

void reportError(
  String errorMessage, {
  bool fatal = false,
}) {}

Future<void> setupDimensions() async {}

Future<void> setupUserApplicationDimensions() async {}

Map<String, dynamic> generateSurveyQueryParameters() => {};
