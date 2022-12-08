// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/config_specific/host_platform/host_platform.dart';
import '../../shared/primitives/utils.dart';

final LogicalKeySet goToLineNumberKeySet = LogicalKeySet(
  HostPlatform.instance.isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control,
  LogicalKeyboardKey.keyG,
);

final String goToLineNumberKeySetDescription =
    goToLineNumberKeySet.describeKeys(isMacOS: HostPlatform.instance.isMacOS);

final LogicalKeySet searchInFileKeySet = LogicalKeySet(
  HostPlatform.instance.isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control,
  LogicalKeyboardKey.keyF,
);

final LogicalKeySet escapeKeySet = LogicalKeySet(
  LogicalKeyboardKey.escape,
);

final LogicalKeySet openFileKeySet = LogicalKeySet(
  HostPlatform.instance.isMacOS
      ? LogicalKeyboardKey.meta
      : LogicalKeyboardKey.control,
  LogicalKeyboardKey.keyP,
);

final String openFileKeySetDescription =
    openFileKeySet.describeKeys(isMacOS: HostPlatform.instance.isMacOS);
