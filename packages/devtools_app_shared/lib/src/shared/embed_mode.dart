// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The type of embedding for this DevTools instance.
///
/// The embed mode will be specified by the IDE or tool that is embedding
/// DevTools by setting query parameters in the DevTools URI.
///
/// 'embedMode=many' => EmbedMode.embedMany, which means that many DevTools
/// screens will be embedded in this view. This will result in the top level
/// tab bar being present. Any screens that should be hidden in this mode will
/// be specified by the 'hide' query parameter.
///
/// 'embedMode=one' => EmbedMode.embedOne, which means that a single DevTools
/// screen will be embedded in this view. This will result in the top level tab
/// bar being hidden, and only the screen specified by the URI path will be
/// shown.
enum EmbedMode {
  embedOne,
  embedMany,
  none;

  static EmbedMode fromArgs(Map<String, String?> args) {
    final embedMode = args[_embedModeKey];
    if (embedMode != null) {
      return switch (embedMode) {
        _embedModeManyValue => EmbedMode.embedMany,
        _embedModeOneValue => EmbedMode.embedOne,
        _ => EmbedMode.none,
      };
    }

    if (args[_legacyEmbedKey] == 'true') {
      // Handle legacy query parameters that may set 'embed' to 'true'
      return EmbedMode.embedOne;
    }

    return EmbedMode.none;
  }

  static const _embedModeKey = 'embedMode';
  static const _embedModeOneValue = 'one';
  static const _embedModeManyValue = 'many';

  // TODO(kenz): remove legacy values in May of 2025 when all IDEs are not using
  // these and 12 months have passed to allow users enough time to upgrade.
  static const _legacyEmbedKey = 'embed';

  bool get embedded =>
      this == EmbedMode.embedOne || this == EmbedMode.embedMany;
}
