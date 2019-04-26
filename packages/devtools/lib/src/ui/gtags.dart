// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@JS()
library gtags;

import 'package:js/js.dart';

/// For gtags API see https://developers.google.com/gtagjs/reference/api
/// For debugging install the Chrome Plugin "Google Analytics Debugger".

/// Analytic's DevTools Property ID 'UA-nnn'.
//@JS('_GA_DEVTOOLS_PROPERTY')
//external String get gaDevToolsPropertyTrackingID;

@JS('gtag')
external void _gTagCommandName(String command, String name, [dynamic params]);

@JS('gaCollectionAllowed')
external bool _gaCollectionAllowed();

/// Google Analytics ready to collect.
@JS('isGaInitialized')
external bool isGaInitialized();

class GTag {
  static const String _event = 'event';
  static const String _exception = 'exception';

  /// Collect the analytic's event and its parameters.
  static void event(String eventName, GtagEvent gaEvent) {
    if (_gaCollectionAllowed()) _gTagCommandName(_event, eventName, gaEvent);
  }

  static void exception(GtagException gaException) {
    if (_gaCollectionAllowed())
      _gTagCommandName(_event, _exception, gaException);
  }
}

@JS()
@anonymous
class GtagEvent {
  external factory GtagEvent({
    // ignore: non_constant_identifier_names
    String event_category,
    // ignore: non_constant_identifier_names
    String event_label, // Event e.g., gaScreenViewEvent, gaSelectEvent, etc.
    // ignore: non_constant_identifier_names
    String send_to, // UA ID of target GA property to receive event data.

    int value,

    // ignore: non_constant_identifier_names
    bool non_interaction,

    // ignore: non_constant_identifier_names
    dynamic custom_map,
  });

  // ignore: non_constant_identifier_names
  external String get event_category;
  // ignore: non_constant_identifier_names
  external String get event_label;
  // ignore: non_constant_identifier_names
  external String get send_to;
  // ignore: non_constant_identifier_names
  external int get value; // Positive number.
  // ignore: non_constant_identifier_names
  external bool get non_interaction;
  // ignore: non_constant_identifier_names
  external dynamic get custom_map;
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
