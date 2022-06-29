// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer';

import '_app_config.dart';
import '_reporter.dart';
import '_tracker.dart';
import 'model.dart';

Timer? _timer;

/// Name of extension that enables leak tracking for applications.
const memoryLeakTrackingExtensionName = 'ext.dart.memoryLeakTracking';

/// Starts leak tracking in the application, for instrumented objects.
///
/// If [detailsProvider] provided, it will be used to collect location
/// for the leaked objects.
/// If [checkPeriod] is not null, the leaks summary will be regularly calculated
/// and, in case of new leaks, output to the console.
/// If [logger] is provided, it will be used for log output, otherwise new
/// logger will be configured.
void startAppLeakTracking({
  ObjectDetailsProvider? detailsProvider,
  Duration? checkPeriod = const Duration(seconds: 1),
}) {
  objectDetailsProvider = detailsProvider ?? (_) => null;

  if (checkPeriod != null) {
    _timer?.cancel();
    _timer = Timer.periodic(
      checkPeriod,
      (_) {
        reportLeaksSummary(leakTracker.collectLeaksSummary());
      },
    );
  }

  try {
    registerExtension(memoryLeakTrackingExtensionName,
        (method, parameters) async {
      final isGC = parameters.containsKey('gc');
      if (isGC) leakTracker.registerOldGCEvent();
      return ServiceExtensionResponse.result('{}');
    });
  } on ArgumentError catch (ex) {
    // Skipping error about already registered extension.
    final isAlreadyRegisteredError = ex.toString().contains('registered');
    if (!isAlreadyRegisteredError) rethrow;
  }

  leakTrackingEnabled = true;
}

void stopAppLeakTracking() {
  leakTrackingEnabled = false;
  _timer?.cancel();
}

void startObjectLeakTracking(Object object, {Object? token}) {
  if (leakTrackingEnabled) leakTracker.startTracking(object, token);
}

void registerDisposal(Object object, {Object? token}) {
  if (leakTrackingEnabled) leakTracker.registerDisposal(object, token);
}
