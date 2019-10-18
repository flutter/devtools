// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

// ignore_for_file: non_constant_identifier_names

import 'package:js/js.dart';

import 'analytics.dart' as ga;

/// For gtags API see https://developers.google.com/gtagjs/reference/api
/// For debugging install the Chrome Plugin "Google Analytics Debugger".

@JS('gtag')
external void _gTagCommandName(String command, String name, [dynamic params]);

/// Google Analytics ready to collect.
@JS('isGaInitialized')
external bool isGaInitialized();

class GTag {
  static const String _event = 'event';
  static const String _exception = 'exception';

  /// Collect the analytic's event and its parameters.
  static void event(String eventName, GtagEvent gaEvent) async {
    if (await ga.isEnabled) _gTagCommandName(_event, eventName, gaEvent);
  }

  static void exception(GtagException gaException) async {
    if (await ga.isEnabled) {
      _gTagCommandName(_event, _exception, gaException);
    }
  }
}

@JS()
@anonymous
class GtagEvent {
  external factory GtagEvent({
    String event_category,
    String event_label, // Event e.g., gaScreenViewEvent, gaSelectEvent, etc.
    String send_to, // UA ID of target GA property to receive event data.

    int value,
    bool non_interaction,
    dynamic custom_map,
  });

  external String get event_category;
  external String get event_label;
  external String get send_to;
  external int get value; // Positive number.
  external bool get non_interaction;
  external dynamic get custom_map; // Custom metrics
}

@JS()
@anonymous
class GtagException {
  external factory GtagException({
    String description,
    bool fatal,
  });

  external String get description; // Description of the error.
  external bool get fatal; // Fatal error.
}
