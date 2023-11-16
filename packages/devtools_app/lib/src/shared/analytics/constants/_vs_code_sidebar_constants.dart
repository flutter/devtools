// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../constants.dart';

enum VsCodeFlutterSidebar {
  /// Analytics id to track events that come from the VS Code Flutter sidebar.
  vsCodeFlutterSidebar,

  /// Analytics event that is sent when a device selection occurs from the list
  /// of available devices in the sidebar.
  changeSelectedDevice,

  /// Analytics event that is sent when DevTools is opened in the browser
  /// without a specific page.
  openDevToolsExternally;

  static String get id => VsCodeFlutterSidebar.vsCodeFlutterSidebar.name;

  /// Analytics event for when a request to enable a new platform type is sent
  /// to VS Code.
  static String enablePlatformType(String platformType) =>
      'enablePlatformType-$platformType';

  /// Analytics event that is sent when a DevTools screen is opened from the
  /// actions toolbar for a debug session.
  static String openDevToolsScreen(String screen) =>
      'openDevToolsScreen-$screen';
}
