// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/service.dart';
import 'package:dtd/dtd.dart';
// ignore: implementation_imports, intentional use of extension methods in DTD
import 'package:dtd/src/unified_analytics_service.dart';
import 'package:logging/logging.dart';
import 'package:unified_analytics/unified_analytics.dart' as ua;

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

  /// Gets the package:unified_analytics consent message to prompt users with on
  /// first run or when the message has been updated.
  Future<String> analyticsConsentMessage() async {
    if (!hasConnection) return '';
    try {
      final response =
          await _dtd.analyticsGetConsentMessage(ua.DashTool.devtools);
      _log.finer('DTDManager.analyticsConsentMessage success');
      return response.value!;
    } catch (e) {
      _log.fine('Error calling getAnalyticsConsentMessage: $e');
      return '';
    }
  }

  /// Whether the package:unified_analytics consent message should be shown for
  /// DevTools.
  Future<bool> shouldShowAnalyticsConsentMessage() async {
    if (!hasConnection) return false;
    try {
      final response =
          await _dtd.analyticsShouldShowConsentMessage(ua.DashTool.devtools);
      final shouldShow = response.value!;
      _log.finer(
        'DTDManager.shouldShowAnalyticsConsentMessage result: $shouldShow',
      );
      return shouldShow;
    } catch (e) {
      _log.fine('Error calling shouldShowAnalyticsConsentMessage: $e');
      return false;
    }
  }

  /// Marks the package:unified_analytics consent message as shown for DevTools.
  Future<void> analyticsClientShowedMessage() async {
    if (!hasConnection) return;
    try {
      await _dtd.analyticsClientShowedMessage(ua.DashTool.devtools);
      _log.finer('DTDManager.analyticsClientShowedMessage success');
    } catch (e) {
      _log.fine('Error calling analyticsClientShowedMessage: $e');
    }
  }

  /// Whether the package:unified_analytics telemetry is enabled for DevTools.
  Future<bool> analyticsTelemetryEnabled() async {
    if (!hasConnection) return false;
    try {
      final response =
          await _dtd.analyticsTelemetryEnabled(ua.DashTool.devtools);
      final enabled = response.value!;
      _log.finer('DTDManager.analyticsTelemetryEnabled result: $enabled');
      return enabled;
    } catch (e) {
      _log.fine('Error calling analyticsTelemetryEnabled: $e');
      return false;
    }
  }

  /// Sets the package:unified_analytics telemetry to enabled or disabled based
  /// on the value of [enabled].
  Future<void> setAnalyticsTelemetry(bool enabled) async {
    if (!hasConnection) return;
    try {
      await _dtd.analyticsSetTelemetry(ua.DashTool.devtools, enabled: enabled);
      _log.finer('DTDManager.setAnalyticsTelemetry: $enabled');
    } catch (e) {
      _log.fine('Error calling setAnalyticsTelemetry: $e');
    }
  }

  /// Sends an event to package:unified_analytics.
  Future<void> sendAnalyticsEvent(ua.Event event) async {
    if (!hasConnection) return;
    try {
      await _dtd.analyticsSend(ua.DashTool.devtools, event);
      _log.finer('DTDManager.sendAnalyticsEvent: ${event.eventName}');
    } catch (e) {
      _log.fine('Error calling sendAnalyticsEvent: $e');
    }
  }
}
