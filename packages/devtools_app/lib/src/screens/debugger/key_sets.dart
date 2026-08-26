// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/config_specific/host_platform/host_platform.dart';
import '../../shared/primitives/utils.dart';

final goToLineNumberKeySet = LogicalKeySet(
  HostPlatform.instance.isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control,
  LogicalKeyboardKey.keyG,
);

final goToLineNumberKeySetDescription = goToLineNumberKeySet.describeKeys(
  isMacOS: HostPlatform.instance.isMacOS,
);

final searchInFileKeySet = LogicalKeySet(
  HostPlatform.instance.isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control,
  LogicalKeyboardKey.keyF,
);

final escapeKeySet = LogicalKeySet(LogicalKeyboardKey.escape);

final openFileKeySet = LogicalKeySet(
  HostPlatform.instance.isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control,
  LogicalKeyboardKey.keyP,
);

final openFileKeySetDescription = openFileKeySet.describeKeys(
  isMacOS: HostPlatform.instance.isMacOS,
);

// Debugger stepping / pause shortcuts.
//
// Bindings mirror Chrome DevTools (F8 / F9 / F10 / F11 / Shift+F11), which
// VS Code also uses for the stepping triplet. Aligning with these surfaces
// keeps the debugger feel familiar across IDEs.
//
// See https://github.com/flutter/devtools/issues/3867.
final pauseResumeKeySet = LogicalKeySet(LogicalKeyboardKey.f8);

final nextStackFrameKeySet = LogicalKeySet(LogicalKeyboardKey.f9);

final stepOverKeySet = LogicalKeySet(LogicalKeyboardKey.f10);

final stepInKeySet = LogicalKeySet(LogicalKeyboardKey.f11);

final stepOutKeySet = LogicalKeySet(
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.f11,
);
