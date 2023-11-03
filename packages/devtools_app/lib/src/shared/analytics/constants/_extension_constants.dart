// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../constants.dart';

/// Extension screens UX actions.
enum DevToolsExtensionEvents {
  /// Analytics id to track events that come from an extension screen.
  extensionScreenId,

  /// Analytics id to track events that come from the extension settings menu.
  extensionSettingsId,

  /// Analytics id for the setting to only show DevTools tabs for extensions
  /// that have been manually opted into.
  showOnlyEnabledExtensionsSetting,

  /// Analytics id for the embedded extension view, which will only show once
  /// an extension has been enabled.
  embeddedExtension;

  /// Event sent via [ga.screen] when an extension screen is opened.
  static String extensionScreenName(DevToolsExtensionConfig ext) =>
      'extension-${_extensionName(ext)}';

  /// Event sent when a user clicks the "Report an issue" link on an extension
  /// screen.
  static String extensionFeedback(DevToolsExtensionConfig ext) =>
      'extensionFeedback-${_extensionName(ext)}';

  /// Event sent when an extension is enabled because a user manually enabled
  /// it from the extensions settings menu.
  static String extensionEnableManual(DevToolsExtensionConfig ext) =>
      'extensionEnable-manual-${_extensionName(ext)}';

  /// Event sent when an extension is enabled because a user answered the
  /// enablement prompt with "Enable".
  static String extensionEnablePrompt(DevToolsExtensionConfig ext) =>
      'extensionEnable-prompt-${_extensionName(ext)}';

  /// Event sent when an extension is disabled because a user manually disabled
  /// it from the [DisableExtensionDialog] or the main extensions settings menu.
  static String extensionDisableManual(DevToolsExtensionConfig ext) =>
      'extensionDisable-manual-${_extensionName(ext)}';

  /// Event sent when an extension is disabled because a user answered the
  /// enablement prompt with "No, hide this sceen".
  static String extensionDisablePrompt(DevToolsExtensionConfig ext) =>
      'extensionDisable-prompt-${_extensionName(ext)}';

  /// Event sent when an extension is force reloaded from the extension screen
  /// context menu.
  static String extensionForceReload(DevToolsExtensionConfig ext) =>
      'extensionForceReload-${_extensionName(ext)}';
}

String _extensionName(DevToolsExtensionConfig ext) => ext.gaName;
