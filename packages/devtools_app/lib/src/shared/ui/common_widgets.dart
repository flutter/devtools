// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as gac;
import '../config_specific/copy_to_clipboard/copy_to_clipboard.dart';
import '../console/widgets/expandable_variable.dart';
import '../diagnostics/dart_object_node.dart';
import '../diagnostics/tree_builder.dart';
import '../framework/routing.dart';
import '../globals.dart';
import '../primitives/flutter_widgets/linked_scroll_controller.dart';
import '../primitives/utils.dart';
import '../utils/utils.dart';

double get assumedMonospaceCharacterWidth => _assumedMonospaceCharacterWidth;
double _assumedMonospaceCharacterWidth = 9.0;

@visibleForTesting
void setAssumedMonospaceCharacterWidth(double width) {
  _assumedMonospaceCharacterWidth = width;
}

/// Creates a semibold version of [style].
TextStyle semibold(TextStyle style) =>
    style.copyWith(fontWeight: FontWeight.w600);

/// Creates a version of [style] that uses the primary color of [context].
///
/// When the app is in dark mode, it instead uses the accent color.
TextStyle primaryColor(TextStyle style, BuildContext context) {
  final theme = Theme.of(context);
  return style.copyWith(
    color: (theme.brightness == Brightness.light)
        ? theme.primaryColor
        : theme.colorScheme.secondary,
    fontWeight: FontWeight.w400,
  );
}

/// Creates a version of [style] that uses the lighter primary color of
/// [context].
///
/// In dark mode, the light primary color still has enough contrast to be
/// visible, so we continue to use it.
TextStyle primaryColorLight(TextStyle style, BuildContext context) {
  final theme = Theme.of(context);
  return style.copyWith(
    color: theme.primaryColorLight,
    fontWeight: FontWeight.w300,
  );
}

class GaDevToolsButton extends DevToolsButton {
  GaDevToolsButton({
    super.key,
    required VoidCallback? onPressed,
    required String gaScreen,
    required String gaSelection,
    super.icon,
    super.label,
    super.tooltip,
    super.color,
    super.minScreenWidthForText,
    super.elevated,
    super.outlined,
    super.tooltipPadding,
  }) : super(
         onPressed: onPressed != null
             ? () {
                 ga.select(gaScreen, gaSelection);
                 onPressed();
               }
             : null,
       );

  factory GaDevToolsButton.iconOnly({
    required IconData icon,
    required String gaScreen,
    required String gaSelection,
    String? tooltip,
    VoidCallback? onPressed,
    bool outlined = true,
  }) {
    return GaDevToolsButton(
      icon: icon,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      outlined: outlined,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class PauseButton extends GaDevToolsButton {
  PauseButton({
    super.key,
    super.tooltip = 'Pause',
    required super.onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.outlined = true,
    super.minScreenWidthForText,
    bool iconOnly = false,
  }) : super(label: iconOnly ? null : 'Pause', icon: Icons.pause);
}

class ResumeButton extends GaDevToolsButton {
  ResumeButton({
    super.key,
    super.tooltip = 'Resume',
    required super.onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.outlined = true,
    super.minScreenWidthForText,
    bool iconOnly = false,
  }) : super(label: iconOnly ? null : 'Resume', icon: Icons.play_arrow);
}

/// A button that groups pause and resume controls and automatically manages
/// the button enabled states depending on the value of [paused].
class PauseResumeButtonGroup extends StatelessWidget {
  const PauseResumeButtonGroup({
    super.key,
    required this.paused,
    required this.onPause,
    required this.onResume,
    this.pauseTooltip = 'Pause',
    this.resumeTooltip = 'Resume',
    required this.gaScreen,
    required this.gaSelectionPause,
    required this.gaSelectionResume,
  });

  final bool paused;

  final VoidCallback onPause;

  final VoidCallback onResume;

  final String pauseTooltip;

  final String resumeTooltip;

  final String gaScreen;

  final String gaSelectionPause;

  final String gaSelectionResume;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PauseButton(
          iconOnly: true,
          onPressed: paused ? null : onPause,
          tooltip: pauseTooltip,
          gaScreen: gaScreen,
          gaSelection: gaSelectionPause,
        ),
        const SizedBox(width: denseSpacing),
        ResumeButton(
          iconOnly: true,
          onPressed: paused ? onResume : null,
          tooltip: resumeTooltip,
          gaScreen: gaScreen,
          gaSelection: gaSelectionResume,
        ),
      ],
    );
  }
}

class ClearButton extends GaDevToolsButton {
  ClearButton({
    super.key,
    super.color,
    super.tooltip = 'Clear',
    super.outlined = true,
    super.minScreenWidthForText,
    required super.gaScreen,
    required super.gaSelection,
    required super.onPressed,
    bool iconOnly = false,
    String label = 'Clear',
  }) : super(icon: Icons.block, label: iconOnly ? null : label);
}

class RefreshButton extends GaDevToolsButton {
  RefreshButton({
    super.key,
    String label = 'Refresh',
    super.tooltip,
    super.minScreenWidthForText,
    super.outlined,
    required super.gaScreen,
    required super.gaSelection,
    required super.onPressed,
    bool iconOnly = false,
  }) : super(icon: Icons.refresh, label: iconOnly ? null : label);
}

/// A Refresh ToolbarAction button.
class ToolbarRefresh extends ToolbarAction {
  const ToolbarRefresh({
    super.key,
    super.icon = Icons.refresh,
    required super.onPressed,
    super.tooltip = 'Refresh',
  });
}

class StartStopRecordingButton extends GaDevToolsButton {
  StartStopRecordingButton({
    super.key,
    required this.recording,
    required super.onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.minScreenWidthForText,
    String? tooltipOverride,
    Color? colorOverride,
    String? labelOverride,
  }) : super(
         icon: _icon(recording),
         label: labelOverride ?? _label(recording),
         color: colorOverride ?? _color(recording),
         tooltip: tooltipOverride ?? _tooltip(recording),
       );

  static IconData _icon(bool recording) =>
      recording ? Icons.stop : Icons.fiber_manual_record;

  static String _label(bool recording) =>
      recording ? 'Stop recording' : 'Start recording';

  static String _tooltip(bool recording) =>
      recording ? 'Stop recording' : 'Start recording';

  static Color? _color(bool recording) => recording ? Colors.red : null;

  final bool recording;
}

/// Button to start recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `minScreenWidthForText`: The minimum width the button can be before the text is
///    omitted.
/// * `labelOverride`: Optional alternative text to use for the button.
/// * `onPressed`: The callback to be called upon pressing the button.
class RecordButton extends GaDevToolsButton {
  RecordButton({
    super.key,
    required bool recording,
    required VoidCallback onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.minScreenWidthForText,
    super.tooltip = 'Start recording',
    String? labelOverride,
  }) : super(
         onPressed: recording ? null : onPressed,
         icon: Icons.fiber_manual_record,
         label: labelOverride ?? 'Record',
       );
}

/// Button to stop recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `minScreenWidthForText`: The minimum width the button can be before the text is
///    omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
class StopRecordingButton extends GaDevToolsButton {
  StopRecordingButton({
    super.key,
    required bool recording,
    required VoidCallback? onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.minScreenWidthForText,
    super.tooltip = 'Stop recording',
  }) : super(
         onPressed: !recording ? null : onPressed,
         icon: Icons.stop,
         label: 'Stop',
       );
}

class SettingsOutlinedButton extends GaDevToolsButton {
  SettingsOutlinedButton({
    super.key,
    required super.onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.tooltip,
  }) : super(outlined: true, icon: Icons.settings_outlined);
}

class HelpButton extends GaDevToolsButton {
  HelpButton({
    super.key,
    required super.gaScreen,
    required super.gaSelection,
    required super.onPressed,
    super.outlined = true,
  }) : super(icon: Icons.help_outline, tooltip: 'Help');
}

class ExpandAllButton extends StatelessWidget {
  const ExpandAllButton({
    super.key,
    required this.gaScreen,
    required this.gaSelection,
    required this.onPressed,
    this.minScreenWidthForText,
  });

  final VoidCallback onPressed;

  final String gaScreen;

  final String gaSelection;

  final double? minScreenWidthForText;

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton(
      icon: Icons.unfold_more,
      label: 'Expand All',
      tooltip: 'Expand All',
      onPressed: onPressed,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      minScreenWidthForText: minScreenWidthForText,
    );
  }
}

class CollapseAllButton extends StatelessWidget {
  const CollapseAllButton({
    super.key,
    required this.gaScreen,
    required this.gaSelection,
    required this.onPressed,
    this.minScreenWidthForText,
  });

  final VoidCallback onPressed;

  final String gaScreen;

  final String gaSelection;

  final double? minScreenWidthForText;

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton(
      icon: Icons.unfold_less,
      label: 'Collapse All',
      tooltip: 'Collapse All',
      onPressed: onPressed,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      minScreenWidthForText: minScreenWidthForText,
    );
  }
}

/// Button that should be used to control showing or hiding a chart.
///
/// The button automatically toggles the icon and the tooltip to indicate the
/// shown or hidden state.
class VisibilityButton extends StatelessWidget {
  const VisibilityButton({
    super.key,
    required this.show,
    required this.onPressed,
    this.minScreenWidthForText,
    required this.label,
    required this.tooltip,
    required this.gaScreen,
    // We use a default value for visibility button because in some cases, the
    // analytics for the visibility this button controls are tracked at the
    // preferenes change.
    this.gaSelection = gac.visibilityButton,
  });

  final ValueListenable<bool> show;
  final void Function(bool) onPressed;
  final double? minScreenWidthForText;
  final String label;
  final String tooltip;
  final String gaScreen;
  final String gaSelection;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: show,
      builder: (_, show, _) {
        return GaDevToolsButton(
          key: key,
          tooltip: tooltip,
          icon: show ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          label: label,
          minScreenWidthForText: minScreenWidthForText,
          gaScreen: gaScreen,
          gaSelection: gaSelection,
          onPressed: () => onPressed(!show),
        );
      },
    );
  }
}

/// Default switch for DevTools that enforces size restriction.
class DevToolsSwitch extends StatelessWidget {
  const DevToolsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.padding,
    this.height,
    this.activeColor,
    this.inactiveColor,
  });

  final bool value;

  final void Function(bool)? onChanged;

  final EdgeInsets? padding;

  final double? height;

  final Color? activeColor;

  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? defaultButtonHeight,
      padding: padding,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Switch(
          activeTrackColor: activeColor,
          inactiveTrackColor: inactiveColor,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class ProcessingInfo extends StatelessWidget {
  const ProcessingInfo({
    super.key,
    required this.progressValue,
    required this.processedObject,
  });

  final double? progressValue;

  final String processedObject;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Processing $processedObject',
            style: Theme.of(context).regularTextStyle,
          ),
          const SizedBox(height: defaultSpacing),
          SizedBox(
            width: 200.0,
            child: LinearProgressIndicator(value: progressValue),
          ),
        ],
      ),
    );
  }
}

/// Common button for exiting offline mode.
class ExitOfflineButton extends StatelessWidget {
  const ExitOfflineButton({required this.gaScreen, super.key});

  final String gaScreen;

  @override
  Widget build(BuildContext context) {
    final routerDelegate = DevToolsRouterDelegate.of(context);
    return GaDevToolsButton(
      key: const Key('exit offline button'),
      label: 'Exit offline mode',
      icon: Icons.clear,
      gaScreen: gaScreen,
      gaSelection: gac.stopShowingOfflineData,
      onPressed: () {
        offlineDataController.stopShowingOfflineData();
        // Use Router.neglect to replace the current history entry with
        // the homepage so that clicking Back will not return here.
        Router.neglect(
          context,
          () => routerDelegate.navigateHome(clearScreenParam: true),
        );
      },
    );
  }
}

class OfflineAwareControls extends StatelessWidget {
  const OfflineAwareControls({
    required this.controlsBuilder,
    required this.gaScreen,
    super.key,
  });

  final Widget Function(bool) controlsBuilder;
  final String gaScreen;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: offlineDataController.showingOfflineData,
      builder: (context, offline, _) {
        return Row(
          children: [
            if (offlineDataController.showingOfflineData.value)
              Padding(
                padding: const EdgeInsets.only(right: defaultSpacing),
                child: ExitOfflineButton(gaScreen: gaScreen),
              ),
            Expanded(child: controlsBuilder(offline)),
          ],
        );
      },
    );
  }
}

/// A small element containing some accessory information, often a numeric
/// value.
class Badge extends StatelessWidget {
  const Badge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // These constants are sized to give 1 digit badges a circular look.
    const badgeCornerRadius = 12.0;
    const verticalBadgePadding = 1.0;
    const horizontalBadgePadding = 6.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface,
        borderRadius: BorderRadius.circular(badgeCornerRadius),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: verticalBadgePadding,
        horizontal: horizontalBadgePadding,
      ),
      child: Text(
        text,
        // Use a slightly smaller font for the badge.
        style: theme.regularTextStyle
            .copyWith(color: theme.colorScheme.surface)
            .apply(fontSizeDelta: -1),
      ),
    );
  }
}

/// A wrapper around a TextButton, an Icon, and an optional Tooltip; used for
/// small toolbar actions.
class ToolbarAction extends StatelessWidget {
  const ToolbarAction({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
    this.size,
    this.style,
    this.buttonStyle,
    this.color,
    this.gaScreen,
    this.gaSelection,
  }) : assert((gaScreen == null) == (gaSelection == null));

  final TextStyle? style;
  final ButtonStyle? buttonStyle;
  final IconData icon;
  final Color? color;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double? size;
  final String? gaScreen;
  final String? gaSelection;

  @override
  Widget build(BuildContext context) {
    return SmallAction(
      onPressed: onPressed,
      tooltip: tooltip,
      style: style,
      buttonStyle: buttonStyle,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      child: Icon(
        icon,
        size: size ?? actionsIconSize,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class SmallAction extends StatelessWidget {
  const SmallAction({
    required this.child,
    required this.onPressed,
    this.tooltip,
    super.key,
    this.style,
    this.buttonStyle,
    this.gaScreen,
    this.gaSelection,
  }) : assert((gaScreen == null) == (gaSelection == null));

  final TextStyle? style;
  final ButtonStyle? buttonStyle;
  final Widget child;
  final String? tooltip;
  final VoidCallback? onPressed;
  final String? gaScreen;
  final String? gaSelection;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      style:
          buttonStyle ??
          TextButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: style,
          ),
      onPressed: () {
        if (gaScreen != null && gaSelection != null) {
          ga.select(gaScreen!, gaSelection!);
        }
        onPressed?.call();
      },
      child: child,
    );

    return tooltip == null
        ? button
        : DevToolsTooltip(message: tooltip, child: button);
  }
}

/// Icon action button used in the main DevTools toolbar or footer.
abstract class ScaffoldAction extends StatelessWidget {
  const ScaffoldAction({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.iconAsset,
    this.color,
  }) : assert(
         (icon == null) != (iconAsset == null),
         'Exactly one of icon and iconAsset must be specified.',
       );

  /// The icon to use for this scaffold action.
  ///
  /// Only one of [icon] or [iconAsset] may be non-null.
  final IconData? icon;

  /// The icon asset path to render as the icon for this scaffold action.
  ///
  /// Only one of [icon] or [iconAsset] may be non-null.
  final String? iconAsset;

  final String tooltip;

  final void Function(BuildContext) onPressed;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onPressed(context),
        child: Container(
          width: actionWidgetSize,
          height: actionWidgetSize,
          alignment: Alignment.center,
          child: DevToolsIcon(
            icon: icon,
            iconAsset: iconAsset,
            size: actionsIconSize,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Button to open related information / documentation.
///
/// [tooltip] specifies the hover text for the button.
/// [link] is the link that should be opened when the button is clicked.
class InformationButton extends StatelessWidget {
  const InformationButton({
    super.key,
    required this.tooltip,
    required this.link,
  });

  final String tooltip;

  final String link;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: const Icon(Icons.help_outline),
        onPressed: () async => await launchUrlWithErrorHandling(link),
      ),
    );
  }
}

class OutlinedRowGroup extends StatelessWidget {
  const OutlinedRowGroup({super.key, required this.children, this.borderColor});

  final List<Widget> children;

  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? Theme.of(context).focusColor;
    final childrenWithOutlines = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      childrenWithOutlines.addAll([
        Container(
          decoration: BoxDecoration(
            border: Border(
              left: i == 0 ? BorderSide(color: color) : BorderSide.none,
              right: BorderSide(color: color),
              top: BorderSide(color: color),
              bottom: BorderSide(color: color),
            ),
          ),
          child: children[i],
        ),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: childrenWithOutlines);
  }
}

class ThickDivider extends StatelessWidget {
  const ThickDivider({super.key});

  static const thickDividerHeight = 5.0;

  @override
  Widget build(BuildContext context) {
    return const Divider(
      thickness: thickDividerHeight,
      height: thickDividerHeight,
    );
  }
}

BoxDecoration roundedBorderDecoration(BuildContext context) => BoxDecoration(
  border: Border.all(color: Theme.of(context).focusColor),
  borderRadius: defaultBorderRadius,
);

class LeftBorder extends StatelessWidget {
  const LeftBorder({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final leftBorder = Border(
      left: BorderSide(color: Theme.of(context).focusColor),
    );

    return Container(
      decoration: BoxDecoration(border: leftBorder),
      child: child,
    );
  }
}

/// The golden ratio.
///
/// Makes for nice-looking rectangles.
final goldenRatio = 1 + sqrt(5) / 2;

/// A centered text widget with the default DevTools text style applied.
///
/// Only one of [message] or [richMessage] can be specified.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({this.message, this.richMessage, super.key})
    : assert((message == null) != (richMessage == null));

  final String? message;

  final List<InlineSpan>? richMessage;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (message != null) {
      child = Text(
        message!,
        textAlign: TextAlign.center,
        style: Theme.of(context).regularTextStyle,
      );
    } else {
      child = RichText(text: TextSpan(children: richMessage));
    }
    return Center(child: child);
  }
}

class CenteredCircularProgressIndicator extends StatelessWidget {
  const CenteredCircularProgressIndicator({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    const indicator = Center(child: CircularProgressIndicator());

    if (size == null) return indicator;

    return SizedBox(width: size, height: size, child: indicator);
  }
}

/// An extension on [LinkedScrollControllerGroup] to facilitate having the
/// scrolling widgets auto scroll to the bottom on new content.
///
/// This extension serves the same function as the [ScrollControllerAutoScroll]
/// extension above, but we need to implement these methods again as an
/// extension on [LinkedScrollControllerGroup] because individual
/// [ScrollController]s are intentionally inaccessible from
/// [LinkedScrollControllerGroup].
extension LinkedScrollControllerGroupExtension on LinkedScrollControllerGroup {
  bool get atScrollBottom {
    final pos = position;
    return pos.pixels == pos.maxScrollExtent;
  }

  /// Scroll the content to the bottom using the app's default animation
  /// duration and curve..
  void autoScrollToBottom() async {
    await animateTo(
      position.maxScrollExtent,
      duration: rapidDuration,
      curve: defaultCurve,
    );

    // Scroll again if we've received new content in the interim.
    if (hasAttachedControllers) {
      final pos = position;
      if (pos.pixels != pos.maxScrollExtent) {
        jumpTo(pos.maxScrollExtent);
      }
    }
  }
}

class BreadcrumbNavigator extends StatelessWidget {
  const BreadcrumbNavigator.builder({
    super.key,
    required this.itemCount,
    required this.builder,
  });

  final int itemCount;

  final IndexedWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Breadcrumb.height + 2 * borderPadding,
      alignment: Alignment.centerLeft,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        itemBuilder: builder,
      ),
    );
  }
}

class Breadcrumb extends StatelessWidget {
  const Breadcrumb({
    super.key,
    required this.text,
    required this.isRoot,
    required this.onPressed,
  });

  static const height = 24.0;

  static const caretWidth = 4.0;

  final String text;

  final bool isRoot;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Create the text painter here so that we can calculate `breadcrumbWidth`.
    // We need the width for the wrapping Container that gives the CustomPaint
    // a bounded width.
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: theme.regularTextStyle.copyWith(
          color: theme.colorScheme.contrastTextColor,
          decoration: TextDecoration.underline,
        ),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout();

    final caretWidth = isRoot
        ? Breadcrumb.caretWidth
        : Breadcrumb.caretWidth * 2;
    final breadcrumbWidth = textPainter.width + caretWidth + densePadding * 2;

    return InkWell(
      onTap: onPressed,
      child: Container(
        width: breadcrumbWidth,
        padding: const EdgeInsets.all(borderPadding),
        child: CustomPaint(
          painter: _BreadcrumbPainter(
            textPainter: textPainter,
            isRoot: isRoot,
            breadcrumbWidth: breadcrumbWidth,
            colorScheme: theme.colorScheme,
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbPainter extends CustomPainter {
  _BreadcrumbPainter({
    required this.textPainter,
    required this.isRoot,
    required this.breadcrumbWidth,
    required this.colorScheme,
  });

  final TextPainter textPainter;

  final bool isRoot;

  final double breadcrumbWidth;

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colorScheme.chartAccentColor;
    final path = Path()..moveTo(0, 0);

    if (isRoot) {
      path.lineTo(0, Breadcrumb.height);
    } else {
      path
        ..lineTo(Breadcrumb.caretWidth, Breadcrumb.height / 2)
        ..lineTo(0, Breadcrumb.height);
    }

    path
      ..lineTo(breadcrumbWidth - Breadcrumb.caretWidth, Breadcrumb.height)
      ..lineTo(breadcrumbWidth, Breadcrumb.height / 2)
      ..lineTo(breadcrumbWidth - Breadcrumb.caretWidth, 0);

    canvas.drawPath(path, paint);

    final textXOffset = isRoot
        ? densePadding
        : Breadcrumb.caretWidth + densePadding;
    textPainter.paint(
      canvas,
      Offset(textXOffset, (Breadcrumb.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BreadcrumbPainter oldDelegate) {
    return textPainter != oldDelegate.textPainter ||
        isRoot != oldDelegate.isRoot ||
        breadcrumbWidth != oldDelegate.breadcrumbWidth ||
        colorScheme != oldDelegate.colorScheme;
  }
}

/// A wrapper for a Text widget, which allows for concatenating text if it
/// becomes too long.
class TextViewer extends StatelessWidget {
  const TextViewer({
    super.key,
    required this.text,
    this.maxLength = 65536, //2^16
    this.style,
  });

  final String text;

  // TODO: change the maxLength if we determine a more appropriate limit
  // in https://github.com/flutter/devtools/issues/6263.
  final int maxLength;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final String displayText;
    // Limit the length of the displayed text to maxLength
    if (text.length > maxLength) {
      displayText = '${text.substring(0, min(maxLength, text.length))}...';
    } else {
      displayText = text;
    }
    return SelectionArea(child: Text(displayText, style: style));
  }
}

class JsonViewer extends StatefulWidget {
  JsonViewer({super.key, required this.encodedJson, this.scrollable = true})
    : assert(encodedJson.isNotEmpty);

  final String encodedJson;
  final bool scrollable;

  @override
  State<JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer> {
  late Future<void> _initializeTree;
  late DartObjectNode variable;
  static const jsonEncoder = JsonEncoder.withIndent('  ');

  Future<void> _buildAndExpand(DartObjectNode variable) async {
    // Build the root node
    await buildVariablesTree(variable);
    // Build the contents of all children
    await variable.children.map(buildVariablesTree).wait;

    // Expand the root node to show the first level of contents
    variable.expand();
  }

  void _updateVariablesTree() {
    assert(widget.encodedJson.isNotEmpty);
    final responseJson = json.decode(widget.encodedJson);
    // Insert the JSON data into the fake service cache so we can use it with
    // the `ExpandableVariable` widget.
    if (serviceConnection.serviceManager.connectedState.value.connected) {
      final root = serviceConnection.serviceManager.service!.fakeServiceCache
          .insertJsonObject(responseJson);

      variable = DartObjectNode.fromValue(
        name: '[root]',
        value: root,
        artificialName: true,
        isolateRef: IsolateRef(
          id: 'fake-isolate',
          number: 'fake-isolate',
          name: 'local-cache',
          isSystemIsolate: true,
        ),
      );
    } else {
      variable = _buildJsonTree(
        responseJson,
        '[root]',
      ); // Creates tree structure
    }
    // Intended to be unawaited.
    // ignore: discarded_futures
    _initializeTree = _buildAndExpand(variable);
  }

  DartObjectNode _buildJsonTree(Object? jsonValue, String nodeName) {
    final node = DartObjectNode.fromValue(
      name: nodeName,
      value: jsonValue,
      artificialName: true,
      isolateRef: IsolateRef(
        id: 'fake-isolate',
        number: 'fake-isolate',
        name: 'local-cache',
        isSystemIsolate: true,
      ),
    );

    // Add children for objects (Maps)
    if (jsonValue is Map<String, Object?>) {
      for (final entry in jsonValue.entries) {
        node.addChild(_buildJsonTree(entry.value, entry.key));
      }
    }
    // Add children for lists (Arrays)
    else if (jsonValue is List<Object?>) {
      for (int i = 0; i < jsonValue.length; i++) {
        node.addChild(_buildJsonTree(jsonValue[i], '[$i]'));
      }
    }

    return node; // Returning a properly structured tree
  }

  @override
  void initState() {
    super.initState();
    _updateVariablesTree();
  }

  @override
  void didUpdateWidget(JsonViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.encodedJson != widget.encodedJson) {
      _updateVariablesTree();
    }
  }

  @override
  void dispose() {
    // Remove the JSON object from the fake service cache (while in connected mode) to avoid holding on
    // to large objects indefinitely.
    if (serviceConnection.serviceManager.connectedState.value.connected) {
      serviceConnection.serviceManager.service!.fakeServiceCache
          .removeJsonObject(variable.value as Instance);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = FutureBuilder(
      future: _initializeTree,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container();
        }
        return ExpandableVariable(
          variable: variable,
          onCopy: (copiedVariable) {
            final jsonData = copyJsonData(copiedVariable);
            unawaited(
              copyToClipboard(
                jsonData,
                successMessage: 'JSON copied to clipboard',
              ),
            );
          },
        );
      },
    );
    if (widget.scrollable) {
      child = SingleChildScrollView(child: child);
    }
    return SelectionArea(
      child: Padding(padding: const EdgeInsets.all(denseSpacing), child: child),
    );
  }

  String copyJsonData(DartObjectNode copiedVariable) {
    // Check if service connection is active
    if (serviceConnection.serviceManager.connectedState.value.connected) {
      return jsonEncoder.convert(
        serviceConnection.serviceManager.service!.fakeServiceCache
            .instanceToJson(copiedVariable.value as Instance),
      );
    }

    // Directly convert object to JSON if not connected
    return const JsonEncoder.withIndent('  ').convert(copiedVariable.value);
  }
}

class MoreInfoLink extends StatelessWidget {
  const MoreInfoLink({
    super.key,
    required this.url,
    required this.gaScreenName,
    required this.gaSelectedItemDescription,
    this.padding,
  });

  final String url;

  final String gaScreenName;

  final String gaSelectedItemDescription;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _onLinkTap,
      borderRadius: defaultBorderRadius,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(denseSpacing),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('More info', style: theme.linkTextStyle),
            const SizedBox(width: densePadding),
            Icon(
              Icons.launch,
              size: tooltipIconSize,
              color: theme.colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  void _onLinkTap() {
    unawaited(launchUrlWithErrorHandling(url));
    ga.select(gaScreenName, gaSelectedItemDescription);
  }
}

class LinkIconLabel extends StatelessWidget {
  const LinkIconLabel({
    super.key,
    required this.icon,
    required this.link,
    required this.color,
  });

  final IconData icon;
  final GaLink link;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _onLinkTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: defaultIconSize, color: color),
          const SizedBox(width: densePadding),
          Padding(
            padding: const EdgeInsets.only(bottom: densePadding),
            child: RichText(
              text: TextSpan(
                text: link.display,
                style: Theme.of(context).linkTextStyle.copyWith(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onLinkTap() {
    unawaited(launchUrlWithErrorHandling(link.url));
    if (link.gaScreenName != null && link.gaSelectedItemDescription != null) {
      ga.select(link.gaScreenName!, link.gaSelectedItemDescription!);
    }
  }
}

class GaLinkTextSpan extends LinkTextSpan {
  GaLinkTextSpan({
    required GaLink link,
    required super.context,
    TextStyle? style,
  }) : super(
         link: link,
         onTap: () {
           if (link.gaScreenName != null &&
               link.gaSelectedItemDescription != null) {
             ga.select(link.gaScreenName!, link.gaSelectedItemDescription!);
           }
         },
       );
}

class GaLink extends Link {
  const GaLink({
    required super.display,
    required super.url,
    this.gaScreenName,
    this.gaSelectedItemDescription,
  });

  final String? gaScreenName;
  final String? gaSelectedItemDescription;
}

class Legend extends StatelessWidget {
  const Legend({super.key, required this.entries, this.dense = false});

  double get legendSquareSize => dense ? 12.0 : 16.0;

  final List<LegendEntry> entries;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textStyle = dense ? Theme.of(context).legendTextStyle : null;
    final legendItems = entries
        .map((entry) => _legendItem(entry.description, entry.color, textStyle))
        .toList()
        .joinWith(const SizedBox(height: denseRowSpacing));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: legendItems,
    );
  }

  Widget _legendItem(String description, Color? color, TextStyle? style) {
    return Row(
      children: [
        Container(
          height: legendSquareSize,
          width: legendSquareSize,
          color: color,
        ),
        const SizedBox(width: denseSpacing),
        Text(description, style: style),
      ],
    );
  }
}

class LegendEntry {
  const LegendEntry(this.description, this.color);

  final String description;

  final Color? color;
}

/// The type of data provider function used by the CopyToClipboard Control.
typedef ClipboardDataProvider = String? Function();

/// Control that copies `data` to the clipboard.
///
/// If it succeeds, it displays a notification with `successMessage`.
class CopyToClipboardControl extends StatelessWidget {
  const CopyToClipboardControl({
    super.key,
    this.dataProvider,
    this.successMessage = 'Copied to clipboard.',
    this.tooltip = 'Copy to clipboard',
    this.buttonKey,
    this.size,
    this.gaScreen,
    this.gaItem,
  });

  final ClipboardDataProvider? dataProvider;
  final String? successMessage;
  final String tooltip;
  final Key? buttonKey;
  final double? size;
  final String? gaScreen;
  final String? gaItem;

  @override
  Widget build(BuildContext context) {
    final onPressed = dataProvider == null
        ? null
        : () {
            if (gaScreen != null && gaItem != null) {
              ga.select(gaScreen!, gaItem!);
            }
            unawaited(
              copyToClipboard(
                dataProvider!() ?? '',
                successMessage: successMessage,
              ),
            );
          };
    final size = this.size ?? defaultIconSize;
    return SizedBox(
      height: size,
      child: ToolbarAction(
        icon: Icons.content_copy,
        tooltip: tooltip,
        onPressed: onPressed,
        key: buttonKey,
        size: size,
      ),
    );
  }
}

/// Checkbox Widget class that listens to and manages a [ValueNotifier].
///
/// Used to create a Checkbox widget who's boolean value is attached
/// to a [ValueNotifier<bool>]. This allows for the pattern:
///
/// Create the [NotifierCheckbox] widget in build e.g.,
///
///   myCheckboxWidget = NotifierCheckbox(notifier: controller.myCheckbox);
///
/// The checkbox and the value notifier are now linked with clicks updating the
/// [ValueNotifier] and changes to the [ValueNotifier] updating the checkbox.
class NotifierCheckbox extends StatelessWidget {
  const NotifierCheckbox({
    super.key,
    required this.notifier,
    this.onChanged,
    this.enabled = true,
    this.checkboxKey,
  });

  /// The notifier this [NotifierCheckbox] is responsible for listening to and
  /// updating.
  final ValueNotifier<bool?> notifier;

  /// The callback to be called on change in addition to the notifier changes
  /// handled by this class.
  final void Function(bool? newValue)? onChanged;

  /// Whether this checkbox should be enabled for interaction.
  final bool enabled;

  /// Key to assign to the checkbox, for testing purposes.
  final Key? checkboxKey;

  void _updateValue(bool? value) {
    if (notifier.value != value) {
      notifier.value = value;
      if (onChanged != null) {
        onChanged!(value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, bool? value, _) {
        return SizedBox(
          height: defaultButtonHeight,
          child: Checkbox(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            value: value,
            onChanged: enabled ? _updateValue : null,
            key: checkboxKey,
          ),
        );
      },
    );
  }
}

/// Switch Widget class that listens to and manages a [ValueNotifier].
///
/// Used to create a Switch widget who's boolean value is attached
/// to a [ValueNotifier<bool>]. This allows for the pattern:
///
/// Create the [NotifierSwitch] widget in build e.g.,
///
///   mySwitchWidget = NotifierSwitch(notifier: controller.mySwitchNotifer);
///
/// The switch and the value notifier are now linked with clicks updating the
/// [ValueNotifier] and changes to the [ValueNotifier] updating the switch.
class NotifierSwitch extends StatelessWidget {
  const NotifierSwitch({
    super.key,
    required this.notifier,
    this.onChanged,
    this.padding,
    this.activeColor,
    this.inactiveColor,
  });

  /// The notifier this [NotifierSwitch] is responsible for listening to and
  /// updating.
  final ValueNotifier<bool> notifier;

  /// The callback to be called on change in addition to the notifier changes
  /// handled by this class.
  final void Function(bool? newValue)? onChanged;

  final EdgeInsets? padding;

  final Color? activeColor;

  final Color? inactiveColor;

  void _updateValue(bool value) {
    if (notifier.value != value) {
      notifier.value = value;
      if (onChanged != null) {
        onChanged!(value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, bool? value, _) {
        return DevToolsSwitch(
          value: notifier.value,
          onChanged: _updateValue,
          padding: padding,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
        );
      },
    );
  }
}

/// A widget that represents a check box setting and automatically updates for
/// value changes to [notifier].
class CheckboxSetting extends StatelessWidget {
  const CheckboxSetting({
    super.key,
    required this.notifier,
    required this.title,
    this.description,
    this.tooltip,
    this.onChanged,
    this.enabled = true,
    this.gaScreen,
    this.gaItem,
    this.checkboxKey,
  });

  final ValueNotifier<bool?> notifier;

  final String title;

  final String? description;

  final String? tooltip;

  final void Function(bool? newValue)? onChanged;

  /// Whether this checkbox setting should be enabled for interaction.
  final bool enabled;

  final String? gaScreen;

  final String? gaItem;

  final Key? checkboxKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget checkboxAndTitle = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NotifierCheckbox(
          notifier: notifier,
          onChanged: (bool? value) {
            final gaScreen = this.gaScreen;
            final gaItem = this.gaItem;
            if (gaScreen != null && gaItem != null) {
              ga.select(gaScreen, '$gaItem-$value');
            }
            final onChanged = this.onChanged;
            if (onChanged != null) {
              onChanged(value);
            }
          },
          enabled: enabled,
          checkboxKey: checkboxKey,
        ),
        Flexible(
          child: RichText(
            overflow: TextOverflow.visible,
            maxLines: 3,
            text: TextSpan(
              text: title,
              style: enabled ? theme.regularTextStyle : theme.subtleTextStyle,
            ),
          ),
        ),
      ],
    );
    if (description == null) {
      checkboxAndTitle = Expanded(child: checkboxAndTitle);
    }
    return maybeWrapWithTooltip(
      tooltip: tooltip,
      child: Row(
        children: [
          checkboxAndTitle,
          if (description != null) ...[
            Expanded(
              child: Row(
                children: [
                  RichText(
                    text: TextSpan(text: ' • ', style: theme.subtleTextStyle),
                  ),
                  Flexible(
                    child: RichText(
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        text: description,
                        style: theme.subtleTextStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A widget that represents a switch setting and automatically updates for
/// value changes to [notifier].
class SwitchSetting extends StatelessWidget {
  const SwitchSetting({
    super.key,
    required this.notifier,
    required this.title,
    this.tooltip,
    this.onChanged,
    this.gaScreen,
    this.gaItem,
    this.activeColor,
    this.inactiveColor,
    this.minScreenWidthForText,
  });

  final ValueNotifier<bool> notifier;

  final String title;

  final String? tooltip;

  final void Function(bool newValue)? onChanged;

  final String? gaScreen;

  final String? gaItem;

  final Color? activeColor;

  final Color? inactiveColor;

  final double? minScreenWidthForText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return maybeWrapWithTooltip(
      tooltip: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isScreenWiderThan(context, minScreenWidthForText))
            Flexible(
              child: RichText(
                overflow: TextOverflow.visible,
                maxLines: 3,
                text: TextSpan(text: title, style: theme.regularTextStyle),
              ),
            ),
          NotifierSwitch(
            padding: const EdgeInsets.only(left: borderPadding),
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            notifier: notifier,
            onChanged: (bool? value) {
              final gaScreen = this.gaScreen;
              final gaItem = this.gaItem;
              if (gaScreen != null && gaItem != null) {
                ga.select(gaScreen, '$gaItem-$value');
              }
              final onChanged = this.onChanged;
              if (value != null) {
                onChanged?.call(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class PubWarningText extends StatelessWidget {
  const PubWarningText({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFlutterApp =
        serviceConnection.serviceManager.connectedApp!.isFlutterAppNow == true;
    final sdkName = isFlutterApp ? 'Flutter' : 'Dart';
    final minSdkVersion = isFlutterApp ? '2.8.0' : '2.15.0';
    return SelectionArea(
      child: Text.rich(
        TextSpan(
          text:
              'Warning: you should no longer be launching DevTools from'
              ' pub.\n\n',
          style: theme.subtleTextStyle.copyWith(color: theme.colorScheme.error),
          children: [
            TextSpan(
              text:
                  'DevTools version 2.8.0 will be the last version to '
                  'be shipped on pub. As of $sdkName\nversion >= '
                  '$minSdkVersion, DevTools should be launched by running '
                  'the ',
              style: theme.subtleTextStyle,
            ),
            TextSpan(
              text: '`dart devtools`',
              style: theme.subtleFixedFontStyle,
            ),
            TextSpan(text: '\ncommand.', style: theme.subtleTextStyle),
          ],
        ),
      ),
    );
  }
}

class BlinkingIcon extends StatefulWidget {
  const BlinkingIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;

  final Color color;

  final double size;

  @override
  State<BlinkingIcon> createState() => _BlinkingIconState();
}

class _BlinkingIconState extends State<BlinkingIcon> {
  late Timer timer;

  late bool showFirst;

  @override
  void initState() {
    super.initState();
    showFirst = true;
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        showFirst = !showFirst;
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(seconds: 1),
      firstChild: _icon(),
      secondChild: _icon(color: widget.color),
      crossFadeState: showFirst
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
    );
  }

  Widget _icon({Color? color}) {
    return Icon(widget.icon, size: widget.size, color: color);
  }
}

/// A widget that listens for changes to multiple different [ValueListenable]s
/// and rebuilds for change notifications from any of them.
///
/// The current value of each [ValueListenable] is provided by the `values`
/// parameter in [builder], where the index of each value in the list is equal
/// to the index of its parent [ValueListenable] in [listenables].
///
/// This widget is preferred over nesting many [ValueListenableBuilder]s in a
/// single build method.
class MultiValueListenableBuilder extends StatefulWidget {
  const MultiValueListenableBuilder({
    super.key,
    required this.listenables,
    required this.builder,
    this.child,
  });

  final List<ValueListenable> listenables;

  final Widget Function(
    BuildContext context,
    List<Object?> values,
    Widget? child,
  )
  builder;

  final Widget? child;

  @override
  State<MultiValueListenableBuilder> createState() =>
      _MultiValueListenableBuilderState();
}

class _MultiValueListenableBuilderState
    extends State<MultiValueListenableBuilder>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    widget.listenables.forEach(addAutoDisposeListener);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, [
      for (final listenable in widget.listenables) listenable.value,
    ], widget.child);
  }
}

class SmallCircularProgressIndicator extends StatelessWidget {
  const SmallCircularProgressIndicator({super.key, required this.valueColor});

  final Animation<Color?> valueColor;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(strokeWidth: 2, valueColor: valueColor);
  }
}

class ElevatedCard extends StatelessWidget {
  const ElevatedCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: defaultElevation,
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: defaultBorderRadius),
      child: Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.all(denseSpacing),
        child: child,
      ),
    );
  }
}

/// A convenience wrapper for a [StatefulWidget] that uses the
/// [AutomaticKeepAliveClientMixin] on its [State].
///
/// Wrap a widget in this class if you want [child] to stay alive, and avoid
/// rebuilding. This is useful for children of TabViews. When wrapped in this
/// wrapper, [child] will not be destroyed and rebuilt when switching tabs.
///
/// See [AutomaticKeepAliveClientMixin] for more information.
class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool wantKeepAlive = true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Help button, that opens a dialog on click.
class HelpButtonWithDialog extends StatelessWidget {
  const HelpButtonWithDialog({
    super.key,
    required this.gaScreen,
    required this.gaSelection,
    required this.dialogTitle,
    required this.child,
    this.actions = const <Widget>[],
    this.outlined = true,
  });

  final String gaScreen;

  final String gaSelection;

  final String dialogTitle;

  final Widget child;

  final List<Widget> actions;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return HelpButton(
      onPressed: () {
        showDevToolsDialog(
          context: context,
          title: dialogTitle,
          content: child,
          actions: actions,
        );
      },
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      outlined: outlined,
    );
  }
}

/// Display a single bullet character in order to act as a stylized spacer
/// component.
class BulletSpacer extends StatelessWidget {
  const BulletSpacer({super.key, this.color});

  final Color? color;

  static double get width => actionWidgetSize / 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withAlpha(0x90);
    return Container(
      width: width,
      height: actionWidgetSize,
      alignment: Alignment.center,
      child: Text(
        '•',
        style: theme.regularTextStyle.copyWith(color: color ?? mutedColor),
      ),
    );
  }
}

class VerticalLineSpacer extends StatelessWidget {
  const VerticalLineSpacer({required this.height, super.key});

  // The total width of this spacer should be 8.0.
  static double get totalWidth => _lineWidth + _paddingWidth * 2;
  static const _lineWidth = 1.0;
  static const _paddingWidth = 3.5;

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _paddingWidth),
      child: OutlineDecoration.onlyLeft(
        child: SizedBox(width: _lineWidth, height: height),
      ),
    );
  }
}

class DownloadButton extends StatelessWidget {
  const DownloadButton({
    super.key,
    this.onPressed,
    this.tooltip = 'Download data',
    this.label = 'Download',
    required this.minScreenWidthForText,
    required this.gaScreen,
    required this.gaSelection,
  });

  final VoidCallback? onPressed;
  final String? tooltip;
  final String label;
  final double minScreenWidthForText;
  final String gaScreen;
  final String gaSelection;

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton(
      label: label,
      icon: Icons.file_download,
      tooltip: tooltip,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      onPressed: onPressed,
      minScreenWidthForText: minScreenWidthForText,
    );
  }
}

class ContextMenuButton extends StatelessWidget {
  const ContextMenuButton({
    super.key,
    required this.menuChildren,
    this.color,
    this.gaScreen,
    this.gaItem,
    this.buttonWidth = defaultWidth,
    this.icon = Icons.more_vert,
    this.style,
    double? iconSize,
  }) : iconSize = iconSize ?? tableIconSize;

  static const defaultWidth = 14.0;
  static const densePadding = 2.0;

  final Color? color;
  final String? gaScreen;
  final String? gaItem;
  final List<Widget> menuChildren;
  final IconData icon;
  final double iconSize;
  final ButtonStyle? style;
  final double buttonWidth;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: menuChildren,
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return SizedBox(
              width: buttonWidth,
              child: ToolbarAction(
                icon: icon,
                size: iconSize,
                color: color,
                buttonStyle: style,
                onPressed: () {
                  if (gaScreen != null && gaItem != null) {
                    ga.select(gaScreen!, gaItem!);
                  }
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              ),
            );
          },
    );
  }
}

/// A Widget for displaying a setting field that sets an integer value.
class PositiveIntegerSetting extends StatefulWidget {
  const PositiveIntegerSetting({
    super.key,
    required this.title,
    required this.subTitle,
    required this.notifier,
    this.minimumValue = 0,
    this.width = 150.0,
  });

  final String title;
  final String subTitle;
  final ValueNotifier<int> notifier;
  final int minimumValue;
  final double width;

  @override
  State<PositiveIntegerSetting> createState() => _PositiveIntegerSettingState();
}

class _PositiveIntegerSettingState extends State<PositiveIntegerSetting>
    with AutoDisposeMixin {
  late final TextEditingController _textEditingController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    addAutoDisposeListener(
      widget.notifier,
      () => _textEditingController.text = widget.notifier.value.toString(),
    );

    _textEditingController = TextEditingController()
      ..text = widget.notifier.value.toString();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textFieldValidationText = 'Enter an integer > ${widget.minimumValue}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title),
              Text(widget.subTitle, style: theme.subtleTextStyle),
            ],
          ),
        ),
        const SizedBox(width: defaultSpacing),
        SizedBox(
          width: widget.width,
          child: Form(
            key: _formKey,
            child: TextFormField(
              enableInteractiveSelection: false,
              textAlignVertical: TextAlignVertical.top,
              style: theme.regularTextStyle,
              controller: _textEditingController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Integer > ${widget.minimumValue}',
                border: const OutlineInputBorder(),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: theme.colorScheme.error),
                ),
              ),
              validator: (value) {
                if (value.isNullOrEmpty) {
                  return textFieldValidationText;
                }
                final intValue = int.tryParse(value!);
                if (intValue == null || intValue < widget.minimumValue) {
                  return textFieldValidationText;
                }
                return null;
              },
              onChanged: (String text) {
                if (_formKey.currentState!.validate()) {
                  int value;
                  try {
                    value = int.parse(text);
                  } catch (_) {
                    value = 0;
                  }
                  widget.notifier.value = value;
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Creates an overlay with the provided [content].
///
/// Set [fullScreen] to true to take up the entire screen. Otherwise, a
/// [maxSize] and [topOffset] can be provided to determine the overlay's size
/// and location.
class DevToolsOverlay extends StatelessWidget {
  const DevToolsOverlay({
    super.key,
    required this.content,
    this.fullScreen = false,
    this.maxSize,
    this.topOffset,
  }) : assert(maxSize != null || topOffset != null ? !fullScreen : true);

  final Widget content;
  final bool fullScreen;
  final Size? maxSize;
  final double? topOffset;

  @override
  Widget build(BuildContext context) {
    final parentSize = MediaQuery.of(context).size;

    final overlayContent = Container(
      width: _overlayWidth(parentSize),
      height: _overlayHeight(parentSize),
      color: Theme.of(context).colorScheme.semiTransparentOverlayColor,
      child: Center(child: content),
    );

    return fullScreen
        ? overlayContent
        : Center(
            child: Padding(
              padding: EdgeInsets.only(top: topOffset ?? 0.0),
              child: RoundedOutlinedBorder(clip: true, child: overlayContent),
            ),
          );
  }

  double _overlayWidth(Size parentSize) {
    if (fullScreen) return parentSize.width;
    final defaultWidth = parentSize.width - largeSpacing;
    return maxSize != null ? min(maxSize!.width, defaultWidth) : defaultWidth;
  }

  double _overlayHeight(Size parentSize) {
    if (fullScreen) return parentSize.height;
    final defaultHeight = parentSize.height - largeSpacing;
    return maxSize != null
        ? min(maxSize!.height, defaultHeight)
        : defaultHeight;
  }
}
