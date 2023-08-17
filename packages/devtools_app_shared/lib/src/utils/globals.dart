// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/theme/ide_theme.dart';

IdeTheme get ideTheme {
  final theme = globals[IdeTheme];
  if (theme == null) {
    throw StateError(
      'The global [IdeTheme] is not set. Please call '
      '`setGlobal(IdeTheme, getIdeTheme())` before you call `runApp`.',
    );
  }
  return theme as IdeTheme;
}

final Map<Type, Object> globals = <Type, Object>{};

void setGlobal(Type clazz, Object instance) {
  globals[clazz] = instance;
}
