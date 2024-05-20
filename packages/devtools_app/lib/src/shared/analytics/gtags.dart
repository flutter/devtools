// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names

@JS()
library;

import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import '../../shared/development_helpers.dart';
import 'analytics.dart' as ga;

/// For gtags API see https://developers.google.com/gtagjs/reference/api
/// For debugging install the Chrome Plugin "Google Analytics Debugger".

@JS('gtag')
external void _gTagCommandName(String command, String name, [JSObject? params]);

// TODO(jacobr): refactor this code if we do not migrate off gtags.
// ignore: avoid_classes_with_only_static_members
class GTag {
  static const String _event = 'event';
  static const String _exception = 'exception';

  /// Collect the analytic's event and its parameters.
  static void event(
    String eventName, {
    required GtagEvent Function() gaEventProvider,
  }) async {
    if (debugSendAnalytics || (kReleaseMode && await ga.isAnalyticsEnabled())) {
      _gTagCommandName(_event, eventName, gaEventProvider());
    }
  }

  static void exception({
    required GtagException Function() gaExceptionProvider,
  }) async {
    if (debugSendAnalytics || (kReleaseMode && await ga.isAnalyticsEnabled())) {
      _gTagCommandName(_event, _exception, gaExceptionProvider());
    }
  }
}

extension type GtagEvent._(JSObject _) implements JSObject {
  external factory GtagEvent({
    String? event_category,
    String? event_label, // Event e.g., gaScreenViewEvent, gaSelectEvent, etc.
    String? send_to, // UA ID of target GA property to receive event data.

    int value,
    bool non_interaction,
    JSObject? custom_map,
  });

  external String? get event_category;
  external String? get event_label;
  external String? get send_to;
  external int get value; // Positive number.
  external bool get non_interaction;
  external JSObject? get custom_map; // Custom metrics
}

extension type GtagException._(JSObject _) implements JSObject {
  external factory GtagException({String? description, bool fatal});

  external String? get description; // Description of the error.
  external bool get fatal; // Fatal error.
}
