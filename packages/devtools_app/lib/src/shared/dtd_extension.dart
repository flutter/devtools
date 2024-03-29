// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service.dart';
import 'package:dtd/dtd.dart';
import 'package:logging/logging.dart';
import 'package:unified_analytics/unified_analytics.dart';

final _log = Logger('dtd_manager');

/// Extension methods for the [DTDManager] class from
/// package:devtools_app_shared.
///
/// Any method that shouldn't be easily exposed from DTDManager for all clients
/// (like methods related to interacting with unified_analytics, for example)
/// should live here. These extension methods can also include anything that is
/// specific to DevTools app and not for use by other clients using the
/// [DTDManager] class (e.g. DevTools extensions).
extension DevToolsDTDExtension on DTDManager {
  DartToolingDaemon get _dtd => connection.value!;

  /// Gets the Dart and Flutter unified analytics consent message to prompt
  /// users with on first run or when the message has been updated.
  Future<String> analyticsConsentMessage() async {
    if (!hasConnection) return '';
    try {
      final response = await _dtd.getAnalyticsConsentMessage(DashTool.devtools);
      return response.value! as String;
    } catch (e) {
      _log.fine('Error calling getAnalyticsConsentMessage: $e');
      return '';
    }
  }

  /// Whether the unified analytics client for DevTools, which lives in the
  /// connected Dart Tooling Daemon, should display the consent message.
  Future<bool> shouldShowAnalyticsConsentMessage() async {
    if (!hasConnection) return false;
    try {
      final response =
          await _dtd.shouldShowAnalyticsConsentMessage(DashTool.devtools);
      return response.value! as bool;
    } catch (e) {
      _log.fine('Error calling shouldShowAnalyticsConsentMessage: $e');
      return false;
    }
  }

  /// Marks the analytics consent message as shown for DevTools.
  Future<void> analyticsClientShowedMessage() async {
    if (!hasConnection) return;
    try {
      await _dtd.analyticsClientShowedMessage(DashTool.devtools);
    } catch (e) {
      _log.fine('Error calling analyticsClientShowedMessage: $e');
    }
  }

  /// Whether the unified analytics telemetry is enabled for DevTools.
  Future<bool> analyticsTelemetryEnabled() async {
    if (!hasConnection) return false;
    try {
      final response = await _dtd.analyticsTelemetryEnabled(DashTool.devtools);
      return response.value! as bool;
    } catch (e) {
      _log.fine('Error calling analyticsTelemetryEnabled: $e');
      return false;
    }
  }

  /// Sets the unified analytics telemetry for DevTools to enabled or disabled
  /// based on the value of [enabled].
  Future<void> setAnalyticsTelemetry(bool enabled) async {
    if (!hasConnection) return;
    try {
      await _dtd.setAnalyticsTelemetry(DashTool.devtools, enabled: enabled);
    } catch (e) {
      _log.fine('Error calling analyticsTelemetryEnabled: $e');
    }
  }
}
