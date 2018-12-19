/*
 * Copyright 2017 The Chromium Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

library icons;

class Icon {
  const Icon(this.url);

  final String url;
}

class FlutterIcons {
  static const Icon Flutter_13 = Icon('/icons/flutter_13.png');
  static const Icon Flutter_13_2x = Icon('/icons/flutter_13@2x.png');
  static const Icon Flutter_64 = Icon('/icons/flutter_64.png');
  static const Icon Flutter_64_2x = Icon('/icons/flutter_64@2x.png');
  static const Icon Flutter = Icon('/icons/flutter.png');
  static const Icon Flutter_2x = Icon('/icons/flutter@2x.png');
  static const Icon Flutter_inspect = Icon('/icons/flutter_inspect.png');
  static const Icon Flutter_test = Icon('/icons/flutter_test.png');
  static const Icon Flutter_badge = Icon('/icons/flutter_badge.png');

  static const Icon Phone = Icon('/icons/phone.png');
  static const Icon Feedback = Icon('/icons/feedback.png');

  static const Icon OpenObservatory = Icon('/icons/observatory.png');
  static const Icon OpenObservatoryGroup =
      Icon('/icons/observatory_overflow.png');

  static const Icon OpenTimeline = Icon('/icons/timeline.png');

  static const Icon HotReconst = Icon('/icons/hot-reconst Icon.png');
  static const Icon HotRestart = Icon('/icons/hot-restart.png');

  static const Icon IconRun = Icon('/icons/reconst Icon_run.png');
  static const Icon IconDebug = Icon('/icons/reconst Icon_debug.png');

  static const Icon BazelRun = Icon('/icons/bazel_run.png');

  static const Icon CustomClass = Icon('/icons/custom/class.png');
  static const Icon CustomClassAbstract =
      Icon('/icons/custom/class_abstract.png');
  static const Icon CustomFields = Icon('/icons/custom/fields.png');
  static const Icon CustomInterface = Icon('/icons/custom/interface.png');
  static const Icon CustomMethod = Icon('/icons/custom/method.png');
  static const Icon CustomMethodAbstract =
      Icon('/icons/custom/method_abstract.png');
  static const Icon CustomProperty = Icon('/icons/custom/property.png');
  static const Icon CustomInfo = Icon('/icons/custom/info.png');

  static const Icon AndroidStudioNewProject =
      Icon('/icons/template_new_project.png');
  static const Icon AndroidStudioNewPackage =
      Icon('/icons/template_new_package.png');
  static const Icon AndroidStudioNewPlugin =
      Icon('/icons/template_new_plugin.png');
  static const Icon AndroidStudioNewModule =
      Icon('/icons/template_new_module.png');

  static const Icon AttachDebugger = Icon('/icons/attachDebugger.png');

  // Flutter Inspector Widget Icons.
  static const Icon Accessibility =
      Icon('/icons/inspector/balloonInformation.png');
  static const Icon Animation = Icon('/icons/inspector/resume.png');
  static const Icon Assets = Icon('/icons/inspector/any_type.png');
  static const Icon Async = Icon('/icons/inspector/threads.png');
  static const Icon Diagram = Icon('/icons/inspector/diagram.png');
  static const Icon Input = Icon('/icons/inspector/renderer.png');
  static const Icon Painting = Icon('/icons/inspector/colors.png');
  static const Icon Scrollbar = Icon('/icons/inspector/scrollbar.png');
  static const Icon Stack = Icon('/icons/inspector/value.png');
  static const Icon Styling = Icon('/icons/inspector/atrule.png');
  static const Icon Text = Icon('/icons/inspector/textArea.png');

  static const Icon ExpandProperty =
      Icon('/icons/inspector/expand_property.png');
  static const Icon CollapseProperty =
      Icon('/icons/inspector/collapse_property.png');

  // Flutter Outline Widget Icons.
  static const Icon Column = Icon('/icons/preview/column.png');
  static const Icon Padding = Icon('/icons/preview/padding.png');
  static const Icon RemoveWidget = Icon('/icons/preview/remove_widget.png');
  static const Icon Row = Icon('/icons/preview/row.png');
  static const Icon Center = Icon('/icons/preview/center.png');
  static const Icon Container = Icon('/icons/preview/container.png');
  static const Icon Up = Icon('/icons/preview/up.png');
  static const Icon Down = Icon('/icons/preview/down.png');
  static const Icon ExtractMethod = Icon('/icons/preview/extract_method.png');
}

class FlutterIconsState {
  static const Icon RedProgr = Icon('/icons/perf/RedProgr.png'); // 16x16
  static const Icon RedProgr_1 = Icon('/icons/perf/RedProgr_1.png'); // 16x16
  static const Icon RedProgr_2 = Icon('/icons/perf/RedProgr_2.png'); // 16x16
  static const Icon RedProgr_3 = Icon('/icons/perf/RedProgr_3.png'); // 16x16
  static const Icon RedProgr_4 = Icon('/icons/perf/RedProgr_4.png'); // 16x16
  static const Icon RedProgr_5 = Icon('/icons/perf/RedProgr_5.png'); // 16x16
  static const Icon RedProgr_6 = Icon('/icons/perf/RedProgr_6.png'); // 16x16
  static const Icon RedProgr_7 = Icon('/icons/perf/RedProgr_7.png'); // 16x16
  static const Icon RedProgr_8 = Icon('/icons/perf/RedProgr_8.png'); // 16x16

  static const Icon YellowProgr = Icon('/icons/perf/YellowProgr.png'); // 16x16
  static const Icon YellowProgr_1 =
      Icon('/icons/perf/YellowProgr_1.png'); // 16x16
  static const Icon YellowProgr_2 =
      Icon('/icons/perf/YellowProgr_2.png'); // 16x16
  static const Icon YellowProgr_3 =
      Icon('/icons/perf/YellowProgr_3.png'); // 16x16
  static const Icon YellowProgr_4 =
      Icon('/icons/perf/YellowProgr_4.png'); // 16x16
  static const Icon YellowProgr_5 =
      Icon('/icons/perf/YellowProgr_5.png'); // 16x16
  static const Icon YellowProgr_6 =
      Icon('/icons/perf/YellowProgr_6.png'); // 16x16
  static const Icon YellowProgr_7 =
      Icon('/icons/perf/YellowProgr_7.png'); // 16x16
  static const Icon YellowProgr_8 =
      Icon('/icons/perf/YellowProgr_8.png'); // 16x16
}

class CustomIconMaker {
  static const String normalColor = '231F20';

  final Map<String, Icon> iconCache = {};

  Icon getCustomIcon(String fromText,
      [IconKind kind = IconKind.kClass, bool isAbstract = false]) {
    return null;
    // TODO(jacobr): use canvas and base64 encoded images for this.
    /*
    if (StringUtil.isEmpty(fromText)) {
      return null;
    }

    final String text = fromText.toUpperCase().substring(0, 1);
    final String mapKey = text + '_' + kind.name + '_' + isAbstract;

    if (!iconCache.containsKey(mapKey)) {
      final Icon baseIcon = isAbstract ? kind.abstractIcon : kind.icon;

      final Icon icon = new LayeredIcon(baseIcon, new Icon() {
      void paintIcon(Component c, Graphics g, int x, int y) {
      final Graphics2D g2 = (Graphics2D)g.create();

      try {
      GraphicsUtil.setupAAPainting(g2);
      g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
      g2.setColor(normalColor);

      final Font font = UIUtil.getFont(UIUtil.FontSize.MINI, UIUtil.getTreeFont());
      g2.setFont(font);

      final Rectangle2D bounds = g2.getFontMetrics().getStringBounds(text, g2);
      final float offsetX = (getIconWidth() - (float)bounds.getWidth()) / 2.0f;
      // Some black magic here for vertical centering.
      final float offsetY = getIconHeight() - ((getIconHeight() - (float)bounds.getHeight()) / 2.0f) - 2.0f;

      g2.drawString(text, x + offsetX, y + offsetY);
      }
      finally {
      g2.dispose();
      }
      }

      int getIconWidth() {
      return baseIcon != null ? baseIcon.getIconWidth() : 13;
      }

      int getIconHeight() {
      return baseIcon != null ? baseIcon.getIconHeight() : 13;
      }
      });

      iconCache.put(mapKey, icon);
    }

    return iconCache.get(mapKey);
    */
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

    return getCustomIcon(name, isPrivate ? IconKind.kMethod : IconKind.kClass);
  }

  Icon fromInfo(String name) {
    if (name == null) {
      return null;
    }

    if (name.isEmpty) {
      return null;
    }

    return getCustomIcon(name, IconKind.kInfo);
  }

  bool isAlphabetic(int char) {
    return (char < '0'.codeUnitAt(0) || char > '9'.codeUnitAt(0)) &&
        char != '_'.codeUnitAt(0) &&
        char != r'$'.codeUnitAt(0);
  }
}

// Strip Java naming convention;
class IconKind {
  const IconKind(this.name, this.icon, [abstractIcon])
      : abstractIcon = abstractIcon ?? icon;

  static const IconKind kClass = IconKind(
      'class', FlutterIcons.CustomClass, FlutterIcons.CustomClassAbstract);
  static const IconKind kField = IconKind('fields', FlutterIcons.CustomFields);
  static const IconKind kInterface =
      IconKind('interface', FlutterIcons.CustomInterface);
  static const IconKind kMethod = IconKind(
      'method', FlutterIcons.CustomMethod, FlutterIcons.CustomMethodAbstract);
  static const IconKind kProperty =
      IconKind('property', FlutterIcons.CustomProperty);
  static const IconKind kInfo = IconKind('info', FlutterIcons.CustomInfo);

  final String name;
  final Icon icon;
  final Icon abstractIcon;
}
