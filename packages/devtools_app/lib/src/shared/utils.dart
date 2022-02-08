// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app.dart';
import '../config_specific/logger/logger.dart' as logger;
import 'globals.dart';
import 'notifications.dart';
import 'version.dart';

/// Attempts to copy a String of `data` to the clipboard.
///
/// Shows a `successMessage` [Notification] on the passed in `context`.
Future<void> copyToClipboard(
  String data,
  String successMessage,
  BuildContext context,
) async {
  await Clipboard.setData(ClipboardData(
    text: data,
  ));

  if (successMessage != null) {
    Notifications.of(context)?.push(successMessage);
  }
}

/// Logging to debug console only in debug runs.
void debugLogger(String message) {
  assert(() {
    logger.log('$message');
    return true;
  }());
}

double scaleByFontFactor(double original) {
  return (original * (ideTheme?.fontSizeFactor ?? 1.0)).roundToDouble();
}

bool isDense() {
  return preferences != null && preferences.denseModeEnabled.value ||
      isEmbedded();
}

bool isEmbedded() {
  return ideTheme?.embed ?? false;
}

mixin CompareMixin implements Comparable {
  bool operator <(other) {
    return compareTo(other) < 0;
  }

  bool operator >(other) {
    return compareTo(other) > 0;
  }

  bool operator <=(other) {
    return compareTo(other) <= 0;
  }

  bool operator >=(other) {
    return compareTo(other) >= 0;
  }
}

bool shouldShowPubWarning() =>
    showPubWarning &&
    (serviceManager.connectedApp?.isFlutterAppNow != null &&
            serviceManager.connectedApp.flutterVersionNow >=
                SemanticVersion(major: 2, minor: 8) ||
        (serviceManager.vm != null &&
            SemanticVersion.parse(serviceManager.vm.version) >=
                SemanticVersion(major: 2, minor: 15)));
