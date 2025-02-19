// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../constants.dart';

// ignore: avoid_classes_with_only_static_members, used for namespacing.
class PropertyEditorSidebar {
  /// Analytics id to track events that come from the DTD editor sidebar.
  static String get id => 'propertyEditorSidebar';

  /// Analytics event that is sent when the property editor is updated with new
  /// properties.
  static String widgetPropertiesUpdate({String? name}) =>
      'widgetPropertiesUpdate${name != null ? '-$name' : ''}';

  /// Analytics event for an edit request.
  static String applyEditRequest({
    required String argName,
    required String argType,
  }) => 'applyEditRequest-$argType-$argName';

  /// Analytics event on completion of an edit.
  static String applyEditComplete({
    required String argName,
    required String argType,
    bool succeeded = true,
  }) => 'applyEdit${succeeded ? 'Success' : 'Failure'}-$argType-$argName';
}
