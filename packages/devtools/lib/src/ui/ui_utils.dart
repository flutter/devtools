// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../messages.dart';
import 'elements.dart';
import 'environment.dart' as environment;
import 'fake_flutter/dart_ui/dart_ui.dart';
import 'html_icon_renderer.dart';
import 'material_icons.dart';

const int defaultSplitterWidth = 10;

StatusItem createLinkStatusItem(
  CoreElement textElement, {
  @required String href,
  @required String title,
}) {
  // TODO(jacobr): cleanup icon rendering so the icon changes color on hover.
  final icon = createIconElement(const MaterialIcon(
    'open_in_new',
    Colors.grey,
  ));
  // TODO(jacobr): add this style to the css for all icons displayed as HTML
  // once we verify there are not unintended consequences.
  icon.element.style
    ..verticalAlign = 'text-bottom'
    ..marginBottom = '0';
  final element = CoreElement('a')
    ..add(<CoreElement>[icon, textElement])
    ..setAttribute('href', href)
    ..setAttribute('target', '_blank')
    ..element.title = title;
  return StatusItem()..element.add(element);
}

Future<void> maybeAddDebugMessage(Framework framework, String screenId) async {
  if (!offlineMode &&
      serviceManager.connectedApp != null &&
      await serviceManager.connectedApp.isFlutterApp &&
      !await serviceManager.connectedApp.isProfileBuild) {
    framework.showMessage(message: debugWarning, screenId: screenId);
  }
}

Set<String> _hiddenPages;

Set<String> get hiddenPages {
  return _hiddenPages ??= _lookupHiddenPages();
}

Set<String> _lookupHiddenPages() {
  final queryString = window.location.search;
  if (queryString == null || queryString.length <= 1) {
    // TODO(dantup): Remove this ignore, change to `{}` and bump SDK requirements
    // in pubspec.yaml (devtools + devtools_server) once Flutter stable includes
    // Dart SDK >= v2.2.
    // ignore: prefer_collection_literals
    return Set();
  }
  final qsParams = Uri.splitQueryString(queryString.substring(1));
  return (qsParams['hide'] ?? '').split(',').toSet();
}

bool isTabDisabledByQuery(String key) => hiddenPages.contains(key);

bool get allTabsEnabledByQuery => hiddenPages.contains('none');

/// Creates a canvas scaled to match the device's devicePixelRatio.
///
/// A default canvas will look pixelated on high devicePixelRatio screens so it
/// is important to scale the canvas to reflect the devices physical pixels
/// instead of logical pixels.
///
/// There are some complicated edge cases for non-integer devicePixelRatios as
/// found on Windows 10 so always use this method instead of rolling your own.
CanvasElement createHighDpiCanvas(int width, int height) {
  // If the size has to be rounded, we choose to err towards a higher resolution
  // image instead of a lower resolution one. The cost of a higher resolution
  // image is generally only slightly higher memory usage while a lower
  // resolution image could introduce rendering artifacts.
  final int scaledWidth = (width * environment.devicePixelRatio).ceil();
  final int scaledHeight = (height * environment.devicePixelRatio).ceil();
  final canvas = CanvasElement(width: scaledWidth, height: scaledHeight);
  canvas.style
    ..width = '${width}px'
    ..height = '${height}px';
  final context = canvas.context2D;

  // If there is rounding error as in the case of a non-integer DPI as on some
  // Windows 10 machines, the ratio between the Canvas's dimensions and its size
  // won't precisely match environment.devicePixelRatio.
  // We fix this issue by applying a scale transform to the canvas to reflect
  // the actual ratio between the canvas size and logical pixels in each axis.
  context.scale(scaledWidth / width, scaledHeight / height);
  return canvas;
}

void downloadFile(String src, String filename) {
  final element = document.createElement('a');
  element.setAttribute('href', Url.createObjectUrl(Blob([src])));
  element.setAttribute('download', filename);
  element.style.display = 'none';
  document.body.append(element);
  element.click();
  element.remove();
}
