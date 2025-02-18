// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../utils/url/url.dart';
import '../utils/utils.dart';
import 'icons.dart';
import 'theme/theme.dart';

/// A DevTools-styled area pane to hold a section of UI on a screen.
///
/// It is strongly recommended to use [AreaPaneHeader] or a Widget that builds
/// an [AreaPaneHeader] for the value of the [header] parameter.
class DevToolsAreaPane extends StatelessWidget {
  const DevToolsAreaPane({
    super.key,
    required this.header,
    required this.child,
  });

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Create a bordered, fixed-height header area with a title and optional child
/// on the right-hand side.
///
/// This is typically used as a title for a logical area of the screen.
class AreaPaneHeader extends StatelessWidget implements PreferredSizeWidget {
  const AreaPaneHeader({
    super.key,
    required this.title,
    this.maxLines = 1,
    this.actions = const [],
    this.leftPadding = defaultSpacing,
    this.rightPadding = densePadding,
    this.tall = false,
    this.dense = false,
    this.roundedTopBorder = true,
    this.includeTopBorder = true,
    this.includeBottomBorder = true,
    this.includeLeftBorder = false,
    this.includeRightBorder = false,
  });

  final Widget title;
  final int maxLines;
  final List<Widget> actions;
  final double leftPadding;
  final double rightPadding;
  final bool tall;
  final bool dense;

  // TODO(kenz): add support for a non uniform border to allow for
  // rounded corners when some border sides are missing. This is a
  // challenge for Flutter since it is not supported out of the box:
  // https://github.com/flutter/flutter/issues/12583.

  /// Whether to use a full border with rounded top corners consistent with
  /// material 3 styling.
  ///
  /// When true, the rounded border will take precedence over any value
  /// specified by [includeTopBorder], [includeBottomBorder],
  /// [includeLeftBorder], and [includeRightBorder].
  final bool roundedTopBorder;

  final bool includeTopBorder;
  final bool includeBottomBorder;
  final bool includeLeftBorder;
  final bool includeRightBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderSide = defaultBorderSide(theme);
    final decoration = !roundedTopBorder &&
            (includeTopBorder ||
                includeBottomBorder ||
                includeLeftBorder ||
                includeRightBorder)
        ? BoxDecoration(
            border: Border(
              top: includeTopBorder ? borderSide : BorderSide.none,
              bottom: includeBottomBorder ? borderSide : BorderSide.none,
              left: includeLeftBorder ? borderSide : BorderSide.none,
              right: includeRightBorder ? borderSide : BorderSide.none,
            ),
            color: theme.colorScheme.surface,
          )
        : null;
    Widget container = Container(
      decoration: decoration,
      padding: EdgeInsets.only(left: leftPadding, right: rightPadding),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium!,
              child: title,
            ),
          ),
          ...actions,
        ],
      ),
    );
    if (roundedTopBorder) {
      container = RoundedOutlinedBorder.onlyTop(child: container);
    }
    return SizedBox.fromSize(
      size: preferredSize,
      child: container,
    );
  }

  @override
  Size get preferredSize {
    return Size.fromHeight(
      tall ? defaultHeaderHeight + 2 * densePadding : defaultHeaderHeight,
    );
  }
}

/// A blank, drop-in replacement for [AreaPaneHeader].
///
/// Acts as an empty header widget with zero size that is compatible with
/// interfaces that expect a [PreferredSizeWidget].
final class BlankHeader extends StatelessWidget implements PreferredSizeWidget {
  const BlankHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  Size get preferredSize => Size.zero;
}

/// Wraps [child] in a rounded border with default styling.
///
/// This border can optionally be made non-uniform by setting any of
/// [showTopLeft], [showTopRight], [showBottomLeft], or [showBottomRight] to
/// false.
///
/// If [clip] is true, the child will be wrapped in a [ClipRRect] to ensure the
/// rounded corner of the border is drawn as expected. This should not be
/// necessary in most cases.
final class RoundedOutlinedBorder extends StatelessWidget {
  const RoundedOutlinedBorder({
    super.key,
    this.showTopLeft = true,
    this.showTopRight = true,
    this.showBottomLeft = true,
    this.showBottomRight = true,
    this.clip = false,
    required this.child,
  });

  factory RoundedOutlinedBorder.onlyTop({
    required Widget? child,
    bool clip = false,
  }) =>
      RoundedOutlinedBorder(
        showBottomLeft: false,
        showBottomRight: false,
        clip: clip,
        child: child,
      );

  factory RoundedOutlinedBorder.onlyBottom({
    required Widget? child,
    bool clip = false,
  }) =>
      RoundedOutlinedBorder(
        showTopLeft: false,
        showTopRight: false,
        clip: clip,
        child: child,
      );

  final bool showTopLeft;
  final bool showTopRight;
  final bool showBottomLeft;
  final bool showBottomRight;

  /// Whether we should clip [child].
  ///
  /// This should be used sparingly and only where necessary for performance
  /// reasons.
  final bool clip;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: showTopLeft ? defaultRadius : Radius.zero,
      topRight: showTopRight ? defaultRadius : Radius.zero,
      bottomLeft: showBottomLeft ? defaultRadius : Radius.zero,
      bottomRight: showBottomRight ? defaultRadius : Radius.zero,
    );

    var child = this.child;
    if (clip) {
      child = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.hardEdge,
        child: child,
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).focusColor),
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

/// Wraps [child] in a border with default styling.
///
/// This border can optionally be made non-uniform by setting any of
/// [showTop], [showBottom], [showLeft] or [showRight] to false.
final class OutlineDecoration extends StatelessWidget {
  const OutlineDecoration({
    super.key,
    this.child,
    this.showTop = true,
    this.showBottom = true,
    this.showLeft = true,
    this.showRight = true,
  });

  factory OutlineDecoration.onlyBottom({required Widget? child}) =>
      OutlineDecoration(
        showTop: false,
        showLeft: false,
        showRight: false,
        child: child,
      );

  factory OutlineDecoration.onlyTop({required Widget? child}) =>
      OutlineDecoration(
        showBottom: false,
        showLeft: false,
        showRight: false,
        child: child,
      );

  factory OutlineDecoration.onlyLeft({required Widget? child}) =>
      OutlineDecoration(
        showBottom: false,
        showTop: false,
        showRight: false,
        child: child,
      );

  factory OutlineDecoration.onlyRight({required Widget? child}) =>
      OutlineDecoration(
        showBottom: false,
        showTop: false,
        showLeft: false,
        child: child,
      );

  final bool showTop;
  final bool showBottom;
  final bool showLeft;
  final bool showRight;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).focusColor;
    final border = BorderSide(color: color);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: showLeft ? border : BorderSide.none,
          right: showRight ? border : BorderSide.none,
          top: showTop ? border : BorderSide.none,
          bottom: showBottom ? border : BorderSide.none,
        ),
      ),
      child: child,
    );
  }
}

/// [BorderSide] styled with the DevTools default color palette.
BorderSide defaultBorderSide(ThemeData theme) {
  return BorderSide(color: theme.focusColor);
}

/// Convenience [Divider] with [Padding] that provides a good divider in forms.
final class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    super.key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  });

  const PaddedDivider.thin({super.key})
      : padding = const EdgeInsets.only(bottom: 4.0);

  const PaddedDivider.noPadding({super.key}) : padding = EdgeInsets.zero;

  PaddedDivider.vertical({super.key, double padding = densePadding})
      : padding = EdgeInsets.symmetric(vertical: padding);

  /// The padding to place around the divider.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Divider(thickness: 1.0),
    );
  }
}

/// A widget that provides a tooltip with a common delay before the tooltip is
/// shown.
final class DevToolsTooltip extends StatelessWidget {
  const DevToolsTooltip({
    super.key,
    this.message,
    this.richMessage,
    required this.child,
    this.waitDuration = tooltipWait,
    this.preferBelow = false,
    this.enableTapToDismiss = true,
    this.padding = const EdgeInsets.all(defaultSpacing),
    this.decoration,
    this.textStyle,
  }) : assert((message == null) != (richMessage == null));

  final String? message;
  final InlineSpan? richMessage;
  final Widget child;
  final Duration waitDuration;
  final bool preferBelow;
  final bool enableTapToDismiss;
  final EdgeInsetsGeometry? padding;
  final Decoration? decoration;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    TextStyle? style = textStyle;
    if (richMessage == null) {
      style ??= TextStyle(
        color: Theme.of(context).colorScheme.tooltipTextColor,
        fontSize: defaultFontSize,
      );
    }
    return Tooltip(
      message: message,
      richMessage: richMessage,
      waitDuration: waitDuration,
      preferBelow: preferBelow,
      enableTapToDismiss: enableTapToDismiss,
      padding: padding,
      textStyle: style,
      decoration: decoration,
      child: child,
    );
  }
}

/// Label including an image icon and optional text.
final class ImageIconLabel extends StatelessWidget {
  const ImageIconLabel(
    this.icon,
    this.text, {
    super.key,
    this.unscaledMinIncludeTextWidth,
  });

  final Widget icon;
  final String text;
  final double? unscaledMinIncludeTextWidth;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      children: [
        icon,
        // TODO(jacobr): animate showing and hiding the text.
        if (isScreenWiderThan(context, unscaledMinIncludeTextWidth))
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(text),
          ),
      ],
    );
  }
}

final class MaterialIconLabel extends StatelessWidget {
  const MaterialIconLabel({
    super.key,
    required this.label,
    this.iconData,
    this.iconAsset,
    this.iconSize,
    this.color,
    this.minScreenWidthForTextBeforeScaling,
  })  : assert(
          label != null || iconData != null || iconAsset != null,
          'At least one of iconData, iconAsset, or label must be specified.',
        ),
        assert(
          iconData == null || iconAsset == null,
          'Only one of iconData and iconAsset may be specified.',
        );

  final IconData? iconData;
  final String? iconAsset;
  final double? iconSize;
  final Color? color;
  final String? label;
  final double? minScreenWidthForTextBeforeScaling;

  @override
  Widget build(BuildContext context) {
    // TODO(jacobr): display the label as a tooltip for the icon particularly
    // when the text is not shown.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconData != null || iconAsset != null)
          DevToolsIcon(
            icon: iconData,
            iconAsset: iconAsset,
            size: iconSize ?? defaultIconSize,
            color: color,
          ),
        // TODO(jacobr): animate showing and hiding the text.
        if (label != null &&
            isScreenWiderThan(context, minScreenWidthForTextBeforeScaling))
          Padding(
            padding: EdgeInsets.only(
              left: iconData != null ? densePadding : 0.0,
            ),
            child: Text(
              label!,
              style: Theme.of(context).regularTextStyleWithColor(color),
            ),
          ),
      ],
    );
  }
}

/// Helper that will wrap [child] in a [DevToolsTooltip] widget if [tooltip] is
/// non-null.
Widget maybeWrapWithTooltip({
  required String? tooltip,
  EdgeInsetsGeometry? tooltipPadding,
  required Widget child,
}) {
  if (tooltip != null && tooltip.isNotEmpty) {
    return DevToolsTooltip(
      message: tooltip,
      padding: tooltipPadding,
      child: child,
    );
  }
  return child;
}

/// Displays a [json] map as selectable, formatted text.
final class FormattedJson extends StatelessWidget {
  const FormattedJson({
    super.key,
    this.json,
    this.formattedString,
    this.useSubtleStyle = false,
  }) : assert((json == null) != (formattedString == null));

  static const encoder = JsonEncoder.withIndent('  ');

  final Map<String, dynamic>? json;

  final String? formattedString;

  final bool useSubtleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SelectableText(
      json != null ? encoder.convert(json) : formattedString!,
      style: useSubtleStyle ? theme.subtleFixedFontStyle : theme.fixedFontStyle,
    );
  }
}

/// An extension on [ScrollController] to facilitate having the scrolling widget
/// auto scroll to the bottom on new content.
extension ScrollControllerAutoScroll on ScrollController {
// TODO(devoncarew): We lose dock-to-bottom when we receive content when we're
// off screen.

  /// Return whether the view is currently scrolled to the bottom.
  bool get atScrollBottom {
    final pos = position;
    return pos.pixels == pos.maxScrollExtent;
  }

  /// Scroll the content to the bottom.
  ///
  /// By default, this will scroll using the app's default animation
  /// duration and curve. When [jump] is false, this will scroll by jumping
  /// instead.
  Future<void> autoScrollToBottom({bool jump = false}) async {
    if (jump) {
      jumpTo(position.maxScrollExtent);
    } else {
      await animateTo(
        position.maxScrollExtent,
        duration: rapidDuration,
        curve: defaultCurve,
      );
    }

    // Scroll again if we've received new content in the interim.
    if (hasClients) {
      final pos = position;
      if (pos.pixels != pos.maxScrollExtent) {
        jumpTo(pos.maxScrollExtent);
      }
    }
  }
}

/// A text span that, when clicked, will launch the provided URL from the `link`
/// given in the constructor.
class LinkTextSpan extends TextSpan {
  LinkTextSpan({
    required Link link,
    required BuildContext context,
    VoidCallback? onTap,
    VoidCallback? onLaunchUrlError,
    TextStyle? style,
  }) : super(
          text: link.display,
          style: style ?? Theme.of(context).linkTextStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              onTap?.call();
              await launchUrl(link.url, onError: onLaunchUrlError);
            },
        );
}

/// A data model for a clickable link in a UI.
class Link {
  const Link({required this.display, required this.url});

  final String display;
  final String url;
}

class RoundedCornerOptions {
  const RoundedCornerOptions({
    this.showTopLeft = true,
    this.showTopRight = true,
    this.showBottomLeft = true,
    this.showBottomRight = true,
  });

  /// Static constant instance with all borders hidden
  static const empty = RoundedCornerOptions(
    showTopLeft: false,
    showTopRight: false,
    showBottomLeft: false,
    showBottomRight: false,
  );

  final bool showTopLeft;
  final bool showTopRight;
  final bool showBottomLeft;
  final bool showBottomRight;
}

/// A rounded label containing [labelText].
class RoundedLabel extends StatelessWidget {
  const RoundedLabel({
    super.key,
    required this.labelText,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.tooltipText,
  });

  final String labelText;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final String? tooltipText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = Container(
      padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
      decoration: BoxDecoration(
        borderRadius: defaultBorderRadius,
        color: backgroundColor ?? colorScheme.secondary,
      ),
      child: Text(
        labelText,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: theme.regularTextStyle.copyWith(
            color: textColor ?? colorScheme.onSecondary,
            backgroundColor: backgroundColor ?? colorScheme.secondary,
            fontSize: fontSize ?? defaultFontSize),
      ),
    );
    return tooltipText != null
        ? DevToolsTooltip(message: tooltipText, child: label)
        : label;
  }
}
