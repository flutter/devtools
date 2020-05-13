/*
 * Copyright 2017 The Chromium Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

/// Platform independent definition of icons.
///
/// See [HtmlIconRenderer] for a browser specific implementation of icon
/// rendering. If you add an Icon class you also need to add a renderer class
/// to handle the actual platform specific icon rendering.
/// The benefit of this approach is that icons can be const objects and tests
/// of code that uses icons can run on the Dart VM.
library icons;

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'material_icons.dart';
import 'theme.dart';

const defaultIconSize = 18.0;

abstract class DevToolsIcon {
  const DevToolsIcon();

  double get iconWidth => defaultIconSize;
  double get iconHeight => defaultIconSize;
}

class UrlIcon extends DevToolsIcon {
  const UrlIcon(this.src, {this.invertDark = false});

  final String src;

  /// Whether the icon shout be inverted when rendered in the Dark theme.
  final bool invertDark;
}

class FlutterIcons {
  FlutterIcons._();

  static const DevToolsIcon flutter13 = UrlIcon('/icons/flutter_13.png');
  static const DevToolsIcon flutter13_2x = UrlIcon('/icons/flutter_13@2x.png');
  static const DevToolsIcon flutter64 = UrlIcon('/icons/flutter_64.png');
  static const DevToolsIcon flutter64_2x = UrlIcon('/icons/flutter_64@2x.png');
  static const DevToolsIcon flutter = UrlIcon('/icons/flutter.png');
  static const DevToolsIcon flutter2x = UrlIcon('/icons/flutter@2x.png');
  static const DevToolsIcon flutterInspect =
      UrlIcon('/icons/flutter_inspect.png');
  static const DevToolsIcon flutterTest = UrlIcon('/icons/flutter_test.png');
  static const DevToolsIcon flutterBadge = UrlIcon('/icons/flutter_badge.png');

  static const DevToolsIcon phone = UrlIcon('/icons/phone.png');
  static const DevToolsIcon feedback = UrlIcon('/icons/feedback.png');

  static const DevToolsIcon openObservatory = UrlIcon('/icons/observatory.png');
  static const DevToolsIcon openObservatoryGroup =
      UrlIcon('/icons/observatory_overflow.png');

  static const DevToolsIcon openTimeline = UrlIcon('/icons/timeline.png');

  static const DevToolsIcon hotRefinal = UrlIcon('/icons/hot-refinal Icon.png');
  static const DevToolsIcon hotReload = UrlIcon('/icons/hot-reload.png');
  static const DevToolsIcon hotReloadWhite =
      UrlIcon('/icons/hot-reload-white.png');
  static const DevToolsIcon hotRestart = UrlIcon('/icons/hot-restart.png');
  static const DevToolsIcon hotRestartWhite =
      UrlIcon('/icons/hot-restart-white.png');

  static const DevToolsIcon iconRun = UrlIcon('/icons/refinal Icon_run.png');
  static const DevToolsIcon iconDebug =
      UrlIcon('/icons/refinal Icon_debug.png');

  static const DevToolsIcon bazelRun = UrlIcon('/icons/bazel_run.png');

  static const DevToolsIcon customClass = UrlIcon('/icons/custom/class.png');
  static const DevToolsIcon customClassAbstract =
      UrlIcon('/icons/custom/class_abstract.png');
  static const DevToolsIcon customFields = UrlIcon('/icons/custom/fields.png');
  static const DevToolsIcon customInterface =
      UrlIcon('/icons/custom/interface.png');
  static const DevToolsIcon customMethod = UrlIcon('/icons/custom/method.png');
  static const DevToolsIcon customMethodAbstract =
      UrlIcon('/icons/custom/method_abstract.png');
  static const DevToolsIcon customProperty =
      UrlIcon('/icons/custom/property.png');
  static const DevToolsIcon customInfo = UrlIcon('/icons/custom/info.png');

  static const DevToolsIcon androidStudioNewProject =
      UrlIcon('/icons/template_new_project.png');
  static const DevToolsIcon androidStudioNewPackage =
      UrlIcon('/icons/template_new_package.png');
  static const DevToolsIcon androidStudioNewPlugin =
      UrlIcon('/icons/template_new_plugin.png');
  static const DevToolsIcon androidStudioNewModule =
      UrlIcon('/icons/template_new_module.png');

  static const DevToolsIcon attachDebugger =
      UrlIcon('/icons/attachDebugger.png');

  // Flutter Inspector Widget Icons.
  static const DevToolsIcon accessibility =
      UrlIcon('/icons/inspector/balloonInformation.png');
  static const DevToolsIcon animation = UrlIcon('/icons/inspector/resume.png');
  static const DevToolsIcon assets = UrlIcon('/icons/inspector/any_type.png');
  static const DevToolsIcon asyncUrlIcon =
      UrlIcon('/icons/inspector/threads.png');
  static const DevToolsIcon diagram = UrlIcon('/icons/inspector/diagram.png');
  static const DevToolsIcon input = UrlIcon('/icons/inspector/renderer.png');
  static const DevToolsIcon painting = UrlIcon('/icons/inspector/colors.png');
  static const DevToolsIcon scrollbar =
      UrlIcon('/icons/inspector/scrollbar.png');
  static const DevToolsIcon stack = UrlIcon('/icons/inspector/value.png');
  static const DevToolsIcon styling = UrlIcon('/icons/inspector/atrule.png');
  static const DevToolsIcon text = UrlIcon('/icons/inspector/textArea.png');

  static const DevToolsIcon expandProperty =
      UrlIcon('/icons/inspector/expand_property.png');
  static const DevToolsIcon collapseProperty =
      UrlIcon('/icons/inspector/collapse_property.png');

  // Flutter Outline Widget Icons.
  static const DevToolsIcon column = UrlIcon('/icons/preview/column.png');
  static const DevToolsIcon padding = UrlIcon('/icons/preview/padding.png');
  static const DevToolsIcon removeWidget =
      UrlIcon('/icons/preview/remove_widget.png');
  static const DevToolsIcon row = UrlIcon('/icons/preview/row.png');
  static const DevToolsIcon center = UrlIcon('/icons/preview/center.png');
  static const DevToolsIcon container = UrlIcon('/icons/preview/container.png');
  static const DevToolsIcon up = UrlIcon('/icons/preview/up.png');
  static const DevToolsIcon down = UrlIcon('/icons/preview/down.png');
  static const DevToolsIcon extractMethod =
      UrlIcon('/icons/preview/extract_method.png');

  static const DevToolsIcon greyProgr = UrlIcon('/icons/perf/GreyProgr.png');
  static const DevToolsIcon greyProgress =
      UrlIcon('/icons/perf/grey_progress.gif');
  static const DevToolsIcon redProgress =
      UrlIcon('/icons/perf/red_progress.gif');
  static const DevToolsIcon yellowProgress =
      UrlIcon('/icons/perf/yellow_progress.gif');

  static const DevToolsIcon redError = UrlIcon('/icons/perf/RedExcl.png');

  // Icons matching IntelliJ core icons.
  static const DevToolsIcon locate = UrlIcon('/icons/general/locate.png');
  static const DevToolsIcon forceRefresh =
      UrlIcon('/icons/actions/forceRefresh.png');
  static DevToolsIcon get refresh => MaterialIcon(
      'refresh',
      const ThemedColor(
        Color.fromARGB(255, 0, 0, 0),
        Color.fromARGB(255, 137, 181, 248),
      ),
      codePoint: Icons.refresh.codePoint);

  static const DevToolsIcon performanceOverlay =
      UrlIcon('/icons/general/performance_overlay.png');
  static const DevToolsIcon debugPaint = UrlIcon('/icons/debug_paint.png');
  static const DevToolsIcon repaintRainbow =
      UrlIcon('/icons/repaint_rainbow.png');
  static const DevToolsIcon debugBanner = UrlIcon('/icons/debug_banner.png');
  static const DevToolsIcon history = UrlIcon('/icons/history.png');

  static const UrlIcon pause_black_2x =
      UrlIcon('/icons/general/pause_black@2x.png', invertDark: true);
  // TODO(dantup): Remove the invertDark option from these...
  // https://github.com/flutter/devtools/pull/423#pullrequestreview-214139125
  static const UrlIcon pause_black_disabled_2x =
      UrlIcon('/icons/general/pause_black_disabled@2x.png', invertDark: true);
  static const UrlIcon pause_white_2x =
      UrlIcon('/icons/general/pause_white@2x.png', invertDark: true);
  static const UrlIcon pause_white_disabled_2x =
      UrlIcon('/icons/general/pause_white_disabled@2x.png', invertDark: true);
  static const UrlIcon resume_white_2x =
      UrlIcon('/icons/general/resume_white@2x.png', invertDark: true);
  static const UrlIcon resume_white_disabled_2x =
      UrlIcon('/icons/general/resume_white_disabled@2x.png', invertDark: true);

  /// Used on "primary" buttons that have colored backgrounds, so is not
  /// inverted for Dark theme.
  static const UrlIcon resume_black_2x =
      UrlIcon('/icons/general/resume_black@2x.png');
  static const UrlIcon resume_black_disabled_2x =
      UrlIcon('/icons/general/resume_black_disabled@2x.png');

  static const UrlIcon lightbulb =
      UrlIcon('/icons/general/lightbulb_outline.png');
  static const UrlIcon lightbulb_2x =
      UrlIcon('/icons/general/lightbulb_outline@2x.png');

  static const UrlIcon allocation = UrlIcon('/icons/memory/alloc_icon.png');
  static const UrlIcon search = UrlIcon('/icons/memory/ic_search.png');
  static const UrlIcon snapshot = UrlIcon('/icons/memory/snapshot_color.png');
  static const UrlIcon resetAccumulators =
      UrlIcon('/icons/memory/reset_icon.png', invertDark: true);
  static const UrlIcon settings =
      UrlIcon('/icons/memory/settings.png', invertDark: true);
  static const UrlIcon gcNow =
      UrlIcon('/icons/memory/ic_delete_outline_black.png', invertDark: true);

  static const DevToolsIcon widgetTree = UrlIcon('/icons/widget_tree.png');
}

class CustomIcon extends DevToolsIcon {
  const CustomIcon(
      {@required this.kind, @required this.text, this.isAbstract = false});

  final IconKind kind;
  final String text;
  final bool isAbstract;

  DevToolsIcon get baseIcon => isAbstract ? kind.abstractIcon : kind.icon;

  @override
  double get iconWidth => baseIcon.iconWidth;
  @override
  double get iconHeight => baseIcon.iconHeight;
}

class CustomIconMaker {
  final Map<String, CustomIcon> iconCache = {};

  DevToolsIcon getCustomIcon(String fromText,
      {IconKind kind, bool isAbstract = false}) {
    kind ??= IconKind.classIcon;
    if (fromText?.isEmpty != false) {
      return null;
    }

    final String text = fromText[0].toUpperCase();
    final String mapKey = '${text}_${kind.name}_$isAbstract';

    return iconCache.putIfAbsent(mapKey, () {
      return CustomIcon(kind: kind, text: text, isAbstract: isAbstract);
    });
  }

  DevToolsIcon fromWidgetName(String name) {
    if (name == null) {
      return null;
    }

    final bool isPrivate = name.startsWith('_');
    while (name.isNotEmpty && !isAlphabetic(name.codeUnitAt(0))) {
      name = name.substring(1);
    }

    if (name.isEmpty) {
      return null;
    }

    return getCustomIcon(name,
        kind: isPrivate ? IconKind.method : IconKind.classIcon);
  }

  DevToolsIcon fromInfo(String name) {
    if (name == null) {
      return null;
    }

    if (name.isEmpty) {
      return null;
    }

    return getCustomIcon(name, kind: IconKind.info);
  }

  bool isAlphabetic(int char) {
    return (char < '0'.codeUnitAt(0) || char > '9'.codeUnitAt(0)) &&
        char != '_'.codeUnitAt(0) &&
        char != r'$'.codeUnitAt(0);
  }
}

class IconKind {
  const IconKind(this.name, this.icon, [DevToolsIcon abstractIcon])
      : abstractIcon = abstractIcon ?? icon;

  static const IconKind classIcon = IconKind(
      'class', FlutterIcons.customClass, FlutterIcons.customClassAbstract);
  static const IconKind field = IconKind('fields', FlutterIcons.customFields);
  static const IconKind interface =
      IconKind('interface', FlutterIcons.customInterface);
  static const IconKind method = IconKind(
      'method', FlutterIcons.customMethod, FlutterIcons.customMethodAbstract);
  static const IconKind property =
      IconKind('property', FlutterIcons.customProperty);
  static const IconKind info = IconKind('info', FlutterIcons.customInfo);

  final String name;
  final DevToolsIcon icon;
  final DevToolsIcon abstractIcon;
}

class ColorIcon extends DevToolsIcon {
  const ColorIcon(this.color);

  final Color color;
}

class ColorIconMaker {
  final Map<Color, DevToolsIcon> iconCache = {};

  DevToolsIcon getCustomIcon(Color color) {
    return iconCache.putIfAbsent(color, () => ColorIcon(color));
  }
}
