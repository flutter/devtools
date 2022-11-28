// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

// ignore_for_file: non_constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:js/js.dart';

import '../analytics/analytics.dart' as ga;

/// For gtags API see https://developers.google.com/gtagjs/reference/api
/// For debugging install the Chrome Plugin "Google Analytics Debugger".

/// Enable this flag to debug analytics when DevTools is run in debug or profile
/// mode, otherwise analytics will only be sent in release builds.
///
/// `ga.isAnalyticsEnabled()` still must return true for analytics to be sent.
bool _debugAnalytics = false;

@JS('gtag')
external void _gTagCommandName(String command, String name, [dynamic params]);

// ignore: avoid_classes_with_only_static_members
class GTag {
  static const String _event = 'event';
  static const String _exception = 'exception';

  static bool get shouldSendAnalytics => kReleaseMode || _debugAnalytics;

  /// Collect the analytic's event and its parameters.
  static void event(
    String eventName, {
    required GtagEvent Function() gaEventProvider,
  }) async {
    if (shouldSendAnalytics && await ga.isAnalyticsEnabled()) {
      _gTagCommandName(_event, eventName, gaEventProvider());
    }
  }

  static void exception({
    required GtagException Function() gaExceptionProvider,
  }) async {
    if (shouldSendAnalytics && await ga.isAnalyticsEnabled()) {
      _gTagCommandName(_event, _exception, gaExceptionProvider());
    }
  }
}

@JS()
@anonymous
class GtagEvent {
  external factory GtagEvent({
    String? event_category,
    String? event_label, // Event e.g., gaScreenViewEvent, gaSelectEvent, etc.
    String? send_to, // UA ID of target GA property to receive event data.

    int value = 0,
    bool non_interaction = false,
    dynamic custom_map,
  });

  external String? get event_category;

  external String? get event_label;

  external String? get send_to;

  external int get value; // Positive number.
  external bool get non_interaction;

  external dynamic get custom_map; // Custom metrics
}

@JS()
@anonymous
class GtagException {
  external factory GtagException({
    String? description,
    bool fatal = false,
  });

  external String? get description; // Description of the error.
  external bool get fatal; // Fatal error.
}
