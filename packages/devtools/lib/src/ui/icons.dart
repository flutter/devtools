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

import 'package:meta/meta.dart';

import 'fake_flutter/fake_flutter.dart';
import 'material_icons.dart';
import 'theme.dart';

abstract class Icon {
  const Icon();

  int get iconWidth => 18;
  int get iconHeight => 18;
}

class UrlIcon extends Icon {
  const UrlIcon(this.src, {this.invertDark = false});

  final String src;

  /// Whether the icon shout be inverted when rendered in the Dark theme.
  final bool invertDark;
}

class FlutterIcons {
  FlutterIcons._();

  static const Icon flutter13 = UrlIcon('/icons/flutter_13.png');
  static const Icon flutter13_2x = UrlIcon('/icons/flutter_13@2x.png');
  static const Icon flutter64 = UrlIcon('/icons/flutter_64.png');
  static const Icon flutter64_2x = UrlIcon('/icons/flutter_64@2x.png');
  static const Icon flutter = UrlIcon('/icons/flutter.png');
  static const Icon flutter2x = UrlIcon('/icons/flutter@2x.png');
  static const Icon flutterInspect = UrlIcon('/icons/flutter_inspect.png');
  static const Icon flutterTest = UrlIcon('/icons/flutter_test.png');
  static const Icon flutterBadge = UrlIcon('/icons/flutter_badge.png');

  static const Icon phone = UrlIcon('/icons/phone.png');
  static const Icon feedback = UrlIcon('/icons/feedback.png');

  static const Icon openObservatory = UrlIcon('/icons/observatory.png');
  static const Icon openObservatoryGroup =
      UrlIcon('/icons/observatory_overflow.png');

  static const Icon openTimeline = UrlIcon('/icons/timeline.png');

  static const Icon hotRefinal = UrlIcon('/icons/hot-refinal Icon.png');
  static const Icon hotReload = UrlIcon('/icons/hot-reload.png');
  static const Icon hotReloadWhite = UrlIcon('icons/hot-reload-white.png');
  static const Icon hotRestart = UrlIcon('/icons/hot-restart.png');
  static const Icon hotRestartWhite = UrlIcon('icons/hot-restart-white.png');

  static const Icon iconRun = UrlIcon('/icons/refinal Icon_run.png');
  static const Icon iconDebug = UrlIcon('/icons/refinal Icon_debug.png');

  static const Icon bazelRun = UrlIcon('/icons/bazel_run.png');

  static const Icon customClass = UrlIcon('/icons/custom/class.png');
  static const Icon customClassAbstract =
      UrlIcon('/icons/custom/class_abstract.png');
  static const Icon customFields = UrlIcon('/icons/custom/fields.png');
  static const Icon customInterface = UrlIcon('/icons/custom/interface.png');
  static const Icon customMethod = UrlIcon('/icons/custom/method.png');
  static const Icon customMethodAbstract =
      UrlIcon('/icons/custom/method_abstract.png');
  static const Icon customProperty = UrlIcon('/icons/custom/property.png');
  static const Icon customInfo = UrlIcon('/icons/custom/info.png');

  static const Icon androidStudioNewProject =
      UrlIcon('/icons/template_new_project.png');
  static const Icon androidStudioNewPackage =
      UrlIcon('/icons/template_new_package.png');
  static const Icon androidStudioNewPlugin =
      UrlIcon('/icons/template_new_plugin.png');
  static const Icon androidStudioNewModule =
      UrlIcon('/icons/template_new_module.png');

  static const Icon attachDebugger = UrlIcon('/icons/attachDebugger.png');

  // Flutter Inspector Widget Icons.
  static const Icon accessibility =
      UrlIcon('/icons/inspector/balloonInformation.png');
  static const Icon animation = UrlIcon('/icons/inspector/resume.png');
  static const Icon assets = UrlIcon('/icons/inspector/any_type.png');
  static const Icon asyncUrlIcon = UrlIcon('/icons/inspector/threads.png');
  static const Icon diagram = UrlIcon('/icons/inspector/diagram.png');
  static const Icon input = UrlIcon('/icons/inspector/renderer.png');
  static const Icon painting = UrlIcon('/icons/inspector/colors.png');
  static const Icon scrollbar = UrlIcon('/icons/inspector/scrollbar.png');
  static const Icon stack = UrlIcon('/icons/inspector/value.png');
  static const Icon styling = UrlIcon('/icons/inspector/atrule.png');
  static const Icon text = UrlIcon('/icons/inspector/textArea.png');

  static const Icon expandProperty =
      UrlIcon('/icons/inspector/expand_property.png');
  static const Icon collapseProperty =
      UrlIcon('/icons/inspector/collapse_property.png');

  // Flutter Outline Widget Icons.
  static const Icon column = UrlIcon('/icons/preview/column.png');
  static const Icon padding = UrlIcon('/icons/preview/padding.png');
  static const Icon removeWidget = UrlIcon('/icons/preview/remove_widget.png');
  static const Icon row = UrlIcon('/icons/preview/row.png');
  static const Icon center = UrlIcon('/icons/preview/center.png');
  static const Icon container = UrlIcon('/icons/preview/container.png');
  static const Icon up = UrlIcon('/icons/preview/up.png');
  static const Icon down = UrlIcon('/icons/preview/down.png');
  static const Icon extractMethod =
      UrlIcon('/icons/preview/extract_method.png');

  static const Icon greyProgr = UrlIcon('/icons/perf/GreyProgr.png');
  static const Icon greyProgress = UrlIcon('/icons/perf/grey_progress.gif');
  static const Icon redProgress = UrlIcon('/icons/perf/red_progress.gif');
  static const Icon yellowProgress = UrlIcon('/icons/perf/yellow_progress.gif');

  // Icons matching IntelliJ core icons.
  static const Icon locate = UrlIcon('/icons/general/locate.png');
  static const Icon forceRefresh = UrlIcon('/icons/actions/forceRefresh.svg');
  // TODO(dantup): Make a ThemedIcon class to handle this.
  static Icon get refresh => isDarkTheme
      ? const MaterialIcon('refresh', Color.fromARGB(255, 137, 181, 248))
      : const MaterialIcon('refresh', Color.fromARGB(255, 0, 0, 0));
  static const Icon performanceOverlay =
      UrlIcon('/icons/general/performance_overlay.svg');
  static const Icon debugPaint = UrlIcon('/icons/debug_paint.png');
  static const Icon repaintRainbow = UrlIcon('/icons/repaint_rainbow.png');
  static const Icon debugBanner = UrlIcon('/icons/debug_banner.png');
  static const Icon history = UrlIcon('/icons/history.svg');

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
  static const UrlIcon filter =
      UrlIcon('/icons/memory/ic_filter_list_alt_black.png', invertDark: true);
  static const UrlIcon gcNow =
      UrlIcon('/icons/memory/ic_delete_outline_black.png', invertDark: true);
}

class CustomIcon extends Icon {
  const CustomIcon(
      {@required this.kind, @required this.text, this.isAbstract = false});

  final IconKind kind;
  final String text;
  final bool isAbstract;

  Icon get baseIcon => isAbstract ? kind.abstractIcon : kind.icon;

  @override
  int get iconWidth => baseIcon.iconWidth;
  @override
  int get iconHeight => baseIcon.iconHeight;
}

class CustomIconMaker {
  final Map<String, CustomIcon> iconCache = {};

  Icon getCustomIcon(String fromText,
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

  Icon fromWidgetName(String name) {
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

  Icon fromInfo(String name) {
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
  const IconKind(this.name, this.icon, [abstractIcon])
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
  final Icon icon;
  final Icon abstractIcon;
}

class ColorIcon extends Icon {
  const ColorIcon(this.color);

  final Color color;
}

class ColorIconMaker {
  final Map<Color, Icon> iconCache = {};

  Icon getCustomIcon(Color color) {
    return iconCache.putIfAbsent(color, () => ColorIcon(color));
  }
}
