// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../constants.dart';

enum PropertyEditorSidebar {
  /// Analytics event that is sent when the property editor is updated with new
  /// properties.
  widgetPropertiesUpdate,

  /// Analytics event that is sent when a user requests a property edit.
  applyEditRequest;

  /// Analytics id to track events that come from the DTD editor sidebar.
  static String get id => 'propertyEditorSidebar';

  /// Analytics event for when a request to edit a property succeeds.
  static String applyEditSuccess(String argType) => 'editSuccess-$argType';

  /// Analytics event for when a request to edit a property fails.
  static String applyEditFailed(String argType) => 'editFailed-$argType';
}
