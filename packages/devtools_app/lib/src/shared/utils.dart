// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file contain higher level utils, i.e. utils that depend on
// other libraries in this package.
// Utils, that do not have dependencies, should go to primitives/utils.dart.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vm_service/vm_service.dart';

import '../config_specific/logger/logger.dart' as logger;
import 'globals.dart';
import 'notifications.dart';

/// Attempts to copy a String of `data` to the clipboard.
///
/// Shows a `successMessage` [Notification] on the passed in `context`.
Future<void> copyToClipboard(
  String data,
  String successMessage,
  BuildContext context,
) async {
  await Clipboard.setData(
    ClipboardData(
      text: data,
    ),
  );

  Notifications.of(context)?.push(successMessage);
}

/// Logging to debug console only in debug runs.
void debugLogger(String message) {
  assert(
    () {
      logger.log('$message');
      return true;
    }(),
  );
}

double scaleByFontFactor(double original) {
  return (original * ideTheme.fontSizeFactor).roundToDouble();
}

bool isDense() {
  return preferences.denseModeEnabled.value || isEmbedded();
}

bool isEmbedded() => ideTheme.embed;

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

extension VmExtension on VM {
  String get deviceDisplay {
    return [
      '$targetCPU',
      if (architectureBits != null && architectureBits != -1)
        '($architectureBits bit)',
      operatingSystem,
    ].join(' ');
  }
}
