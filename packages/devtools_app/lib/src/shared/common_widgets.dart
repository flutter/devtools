// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../screens/debugger/debugger_controller.dart';
import '../screens/inspector/layout_explorer/ui/theme.dart';
import 'analytics/analytics.dart' as ga;
import 'analytics/constants.dart' as gac;
import 'config_specific/launch_url/launch_url.dart';
import 'console/widgets/expandable_variable.dart';
import 'diagnostics/dart_object_node.dart';
import 'diagnostics/tree_builder.dart';
import 'dialogs.dart';
import 'globals.dart';
import 'primitives/auto_dispose.dart';
import 'primitives/flutter_widgets/linked_scroll_controller.dart';
import 'primitives/utils.dart';
import 'routing.dart';
import 'theme.dart';
import 'ui/label.dart';
import 'utils.dart';

const tooltipWait = Duration(milliseconds: 500);
const tooltipWaitLong = Duration(milliseconds: 1000);

/// The width of the package:flutter_test debugger device.
const debuggerDeviceWidth = 800.0;

const defaultDialogRadius = 20.0;
double get areaPaneHeaderHeight => scaleByFontFactor(36.0);

double get assumedMonospaceCharacterWidth =>
    scaleByFontFactor(_assumedMonospaceCharacterWidth);
double _assumedMonospaceCharacterWidth = 9.0;
@visibleForTesting
void setAssumedMonospaceCharacterWidth(double width) {
  _assumedMonospaceCharacterWidth = width;
}

/// Convenience [Divider] with [Padding] that provides a good divider in forms.
class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    Key? key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  }) : super(key: key);

  const PaddedDivider.thin({super.key})
      : padding = const EdgeInsets.only(bottom: 4.0);

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

/// A button with default DevTools styling and analytics handling.
///
/// * `onPressed`: The callback to be called upon pressing the button.
/// * `minScreenWidthForTextBeforeScaling`: The minimum width the button can be before the text is
///    omitted.
class DevToolsButton extends StatelessWidget {
  const DevToolsButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    required this.gaScreen,
    required this.gaSelection,
    this.label,
    this.color,
    this.minScreenWidthForTextBeforeScaling,
    this.elevatedButton = false,
    this.tooltip,
    this.tooltipPadding,
    this.outlined = true,
  }) : super(key: key);

  factory DevToolsButton.iconOnly({
    required IconData icon,
    required String gaScreen,
    required String gaSelection,
    String? tooltip,
    VoidCallback? onPressed,
    bool outlined = true,
  }) {
    return DevToolsButton(
      icon: icon,
      outlined: outlined,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  // TODO(kenz): allow icon to be nullable if this is a text only button.
  final IconData icon;

  final String? label;

  final double? minScreenWidthForTextBeforeScaling;

  final VoidCallback? onPressed;

  final Color? color;

  /// Whether this icon label button should use an elevated button style.
  final bool elevatedButton;

  final String? tooltip;

  final EdgeInsetsGeometry? tooltipPadding;

  final bool outlined;

  final String gaScreen;

  final String gaSelection;

  @override
  Widget build(BuildContext context) {
    final onPressedHandler = onPressed != null
        ? () {
            ga.select(gaScreen, gaSelection);
            onPressed!();
          }
        : null;

    if (label == null) {
      return SizedBox(
        // This is required to force the button size.
        height: defaultButtonHeight,
        width: defaultButtonHeight,
        child: maybeWrapWithTooltip(
          tooltip: tooltip,
          child: outlined
              ? IconButton.outlined(
                  onPressed: onPressedHandler,
                  iconSize: actionsIconSize,
                  icon: Icon(icon),
                )
              : IconButton(
                  onPressed: onPressedHandler,
                  iconSize: actionsIconSize,
                  icon: Icon(
                    icon,
                  ),
                ),
        ),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    var textColor = color;
    if (textColor == null && elevatedButton) {
      textColor =
          onPressed == null ? colorScheme.onSurface : colorScheme.onPrimary;
    }
    final iconLabel = MaterialIconLabel(
      label: label!,
      iconData: icon,
      minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
      color: textColor,
    );
    if (elevatedButton) {
      return maybeWrapWithTooltip(
        tooltip: tooltip,
        tooltipPadding: tooltipPadding,
        child: ElevatedButton(
          onPressed: onPressedHandler,
          child: iconLabel,
        ),
      );
    }
    // TODO(kenz): this SizedBox wrapper should be unnecessary once
    // https://github.com/flutter/flutter/issues/79894 is fixed.
    return maybeWrapWithTooltip(
      tooltip: tooltip,
      tooltipPadding: tooltipPadding,
      child: SizedBox(
        height: defaultButtonHeight,
        width: !includeText(context, minScreenWidthForTextBeforeScaling)
            ? buttonMinWidth
            : null,
        child: outlined
            ? OutlinedButton(
                style: denseAwareOutlinedButtonStyle(
                  context,
                  minScreenWidthForTextBeforeScaling,
                ),
                onPressed: onPressedHandler,
                child: iconLabel,
              )
            : TextButton(
                onPressed: onPressedHandler,
                style: denseAwareTextButtonStyle(
                  context,
                  minScreenWidthForTextBeforeScaling:
                      minScreenWidthForTextBeforeScaling,
                ),
                child: iconLabel,
              ),
      ),
    );
  }
}

class PauseButton extends DevToolsButton {
  const PauseButton({
    super.key,
    required super.tooltip,
    required super.onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.outlined = true,
    super.minScreenWidthForTextBeforeScaling,
    bool iconOnly = false,
  }) : super(
          label: iconOnly ? null : 'Pause',
          icon: Icons.pause,
        );
}

class ResumeButton extends DevToolsButton {
  const ResumeButton({
    super.key,
    required super.tooltip,
    required super.onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.outlined = true,
    super.minScreenWidthForTextBeforeScaling,
    bool iconOnly = false,
  }) : super(
          label: iconOnly ? null : 'Resume',
          icon: Icons.play_arrow,
        );
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

class ClearButton extends DevToolsButton {
  const ClearButton({
    super.key,
    super.color,
    super.tooltip = 'Clear',
    super.outlined = true,
    super.minScreenWidthForTextBeforeScaling,
    required super.gaScreen,
    required super.gaSelection,
    required super.onPressed,
    bool iconOnly = false,
    String label = 'Clear',
  }) : super(icon: Icons.block, label: iconOnly ? null : label);
}

class RefreshButton extends DevToolsButton {
  const RefreshButton({
    super.key,
    String label = 'Refresh',
    super.tooltip,
    super.minScreenWidthForTextBeforeScaling,
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

/// Button to start recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `minScreenWidthForTextBeforeScaling`: The minimum width the button can be before the text is
///    omitted.
/// * `labelOverride`: Optional alternative text to use for the button.
/// * `onPressed`: The callback to be called upon pressing the button.
class RecordButton extends DevToolsButton {
  const RecordButton({
    super.key,
    required bool recording,
    required VoidCallback onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.minScreenWidthForTextBeforeScaling,
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
/// * `minScreenWidthForTextBeforeScaling`: The minimum width the button can be before the text is
///    omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
class StopRecordingButton extends DevToolsButton {
  const StopRecordingButton({
    super.key,
    required bool recording,
    required VoidCallback? onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.minScreenWidthForTextBeforeScaling,
    super.tooltip = 'Stop recording',
  }) : super(
          onPressed: !recording ? null : onPressed,
          icon: Icons.stop,
          label: 'Stop',
        );
}

class SettingsOutlinedButton extends DevToolsButton {
  const SettingsOutlinedButton({
    super.key,
    required super.onPressed,
    required super.gaScreen,
    required super.gaSelection,
    super.tooltip,
  }) : super(outlined: true, icon: Icons.settings_outlined);
}

class HelpButton extends StatelessWidget {
  const HelpButton({
    super.key,
    required this.gaScreen,
    required this.gaSelection,
    required this.onPressed,
    this.outlined = true,
  });

  final VoidCallback onPressed;

  final String gaScreen;

  final String gaSelection;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton(
      icon: Icons.help_outline,
      onPressed: onPressed,
      tooltip: 'Help',
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      outlined: outlined,
    );
  }
}

class ExpandAllButton extends StatelessWidget {
  const ExpandAllButton({
    super.key,
    required this.gaScreen,
    required this.gaSelection,
    required this.onPressed,
    this.minScreenWidthForTextBeforeScaling,
  });

  final VoidCallback onPressed;

  final String gaScreen;

  final String gaSelection;

  final double? minScreenWidthForTextBeforeScaling;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton(
      icon: Icons.unfold_more,
      label: 'Expand All',
      tooltip: 'Expand All',
      onPressed: onPressed,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
    );
  }
}

class CollapseAllButton extends StatelessWidget {
  const CollapseAllButton({
    super.key,
    required this.gaScreen,
    required this.gaSelection,
    required this.onPressed,
    this.minScreenWidthForTextBeforeScaling,
  });

  final VoidCallback onPressed;

  final String gaScreen;

  final String gaSelection;

  final double? minScreenWidthForTextBeforeScaling;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton(
      icon: Icons.unfold_less,
      label: 'Collapse All',
      tooltip: 'Collapse All',
      onPressed: onPressed,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
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
    this.minScreenWidthForTextBeforeScaling,
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
  final double? minScreenWidthForTextBeforeScaling;
  final String label;
  final String tooltip;
  final String gaScreen;
  final String gaSelection;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: show,
      builder: (_, show, __) {
        return DevToolsButton(
          key: key,
          tooltip: tooltip,
          icon: show ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          label: label,
          minScreenWidthForTextBeforeScaling:
              minScreenWidthForTextBeforeScaling,
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
  });

  final bool value;

  final void Function(bool)? onChanged;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: defaultSwitchHeight,
      padding: padding,
      child: FittedBox(
        fit: BoxFit.fill,
        child: Switch(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class ProcessingInfo extends StatelessWidget {
  const ProcessingInfo({
    Key? key,
    required this.progressValue,
    required this.processedObject,
  }) : super(key: key);

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
            child: LinearProgressIndicator(
              value: progressValue,
            ),
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
    return DevToolsButton(
      key: const Key('exit offline button'),
      label: 'Exit offline mode',
      icon: Icons.clear,
      gaScreen: gaScreen,
      gaSelection: gac.exitOfflineMode,
      onPressed: () {
        offlineController.exitOfflineMode();
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
      valueListenable: offlineController.offlineMode,
      builder: (context, offline, _) {
        return Row(
          children: [
            if (offlineController.offlineMode.value)
              Padding(
                padding: const EdgeInsets.only(right: defaultSpacing),
                child: ExitOfflineButton(gaScreen: gaScreen),
              ),
            Expanded(
              child: controlsBuilder(offline),
            ),
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
    const badgePadding = 6.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface,
        borderRadius: BorderRadius.circular(badgeCornerRadius),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: borderPadding,
        horizontal: badgePadding,
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

/// A widget, commonly used for icon buttons, that provides a tooltip with a
/// common delay before the tooltip is shown.
class DevToolsTooltip extends StatelessWidget {
  const DevToolsTooltip({
    Key? key,
    this.message,
    this.richMessage,
    required this.child,
    this.waitDuration = tooltipWait,
    this.preferBelow = false,
    this.padding = const EdgeInsets.all(defaultSpacing),
    this.decoration,
    this.textStyle,
  })  : assert((message == null) != (richMessage == null)),
        super(key: key);

  final String? message;
  final InlineSpan? richMessage;
  final Widget child;
  final Duration waitDuration;
  final bool preferBelow;
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
      padding: padding,
      textStyle: style,
      decoration: decoration,
      child: child,
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
    Key? key,
    this.size,
    this.style,
    this.color,
    this.gaScreen,
    this.gaSelection,
  })  : assert((gaScreen == null) == (gaSelection == null)),
        super(key: key);

  final TextStyle? style;
  final IconData icon;
  final Color? color;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double? size;
  final String? gaScreen;
  final String? gaSelection;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      style: TextButton.styleFrom(
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
      child: Icon(
        icon,
        size: size ?? actionsIconSize,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    );

    return tooltip == null
        ? button
        : DevToolsTooltip(
            message: tooltip,
            child: button,
          );
  }
}

/// A blank, drop-in replacement for [AreaPaneHeader].
///
/// Acts as an empty header widget with zero size that is compatible with
/// interfaces that expect a [PreferredSizeWidget].
class BlankHeader extends StatelessWidget implements PreferredSizeWidget {
  const BlankHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  Size get preferredSize => Size.zero;
}

/// Create a bordered, fixed-height header area with a title and optional child
/// on the right-hand side.
///
/// This is typically used as a title for a logical area of the screen.
class AreaPaneHeader extends StatelessWidget implements PreferredSizeWidget {
  const AreaPaneHeader({
    Key? key,
    required this.title,
    this.maxLines = 1,
    this.actions = const [],
    this.leftPadding = defaultSpacing,
    this.rightPadding = densePadding,
    this.tall = false,
    this.roundedTopBorder = true,
    this.includeTopBorder = true,
    this.includeBottomBorder = true,
    this.includeLeftBorder = false,
    this.includeRightBorder = false,
  }) : super(key: key);

  final Widget title;
  final int maxLines;
  final List<Widget> actions;
  final double leftPadding;
  final double rightPadding;
  final bool tall;

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
    final decoration = !roundedTopBorder
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
              style: theme.textTheme.titleSmall!,
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
      tall ? areaPaneHeaderHeight + 2 * densePadding : defaultHeaderHeight,
    );
  }
}

BorderSide defaultBorderSide(ThemeData theme) {
  return BorderSide(color: theme.focusColor);
}

class DevToolsToggleButtonGroup extends StatelessWidget {
  const DevToolsToggleButtonGroup({
    Key? key,
    required this.children,
    required this.selectedStates,
    required this.onPressed,
  }) : super(key: key);

  final List<Widget> children;

  final List<bool> selectedStates;

  final void Function(int)? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: defaultButtonHeight,
      child: ToggleButtons(
        borderRadius:
            const BorderRadius.all(Radius.circular(defaultBorderRadius)),
        textStyle: theme.textTheme.bodyMedium,
        constraints: BoxConstraints(
          minWidth: defaultButtonHeight,
          minHeight: defaultButtonHeight,
        ),
        isSelected: selectedStates,
        onPressed: onPressed,
        children: children,
      ),
    );
  }
}

/// Button to export data.
///
/// * `minScreenWidthForTextBeforeScaling`: The minimum width the button can be before the text is
///    omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
class ExportButton extends DevToolsButton {
  const ExportButton({
    required super.gaScreen,
    super.key,
    super.onPressed,
    super.minScreenWidthForTextBeforeScaling,
    super.tooltip = 'Export data',
  }) : super(
          icon: Icons.file_download,
          label: 'Export',
          gaSelection: gac.export,
        );
}

/// Button to open related information / documentation.
///
/// [tooltip] specifies the hover text for the button.
/// [link] is the link that should be opened when the button is clicked.
class InformationButton extends StatelessWidget {
  const InformationButton({
    Key? key,
    required this.tooltip,
    required this.link,
  }) : super(key: key);

  final String tooltip;

  final String link;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: const Icon(Icons.help_outline),
        onPressed: () async => await launchUrl(link),
      ),
    );
  }
}

class ToggleButton extends StatelessWidget {
  const ToggleButton({
    Key? key,
    required this.onPressed,
    required this.isSelected,
    required this.message,
    required this.icon,
    this.outlined = true,
    this.label,
    this.shape,
  }) : super(key: key);

  final String message;

  final VoidCallback onPressed;

  final bool isSelected;

  final IconData icon;

  final String? label;

  final OutlinedBorder? shape;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return DevToolsToggleButtonGroup(
      selectedStates: [isSelected],
      onPressed: (_) => onPressed(),
      children: [
        DevToolsTooltip(
          message: message,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
            child: MaterialIconLabel(
              iconData: icon,
              label: label,
            ),
          ),
        ),
      ],
    );
  }
}

class FilterButton extends StatelessWidget {
  const FilterButton({
    Key? key,
    required this.onPressed,
    required this.isFilterActive,
    this.message = 'Filter',
    this.outlined = true,
  }) : super(key: key);

  final VoidCallback onPressed;
  final bool isFilterActive;
  final String message;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return ToggleButton(
      onPressed: onPressed,
      isSelected: isFilterActive,
      message: message,
      icon: Icons.filter_list,
      outlined: outlined,
    );
  }
}

class RoundedCornerOptions {
  const RoundedCornerOptions({
    this.showTopLeft = true,
    this.showTopRight = true,
    this.showBottomLeft = true,
    this.showBottomRight = true,
  });

  final bool showTopLeft;
  final bool showTopRight;
  final bool showBottomLeft;
  final bool showBottomRight;
}

class RoundedDropDownButton<T> extends StatelessWidget {
  const RoundedDropDownButton({
    Key? key,
    this.value,
    this.onChanged,
    this.isDense = false,
    this.isExpanded = false,
    this.style,
    this.selectedItemBuilder,
    this.items,
    this.roundedCornerOptions,
  }) : super(key: key);

  final T? value;

  final ValueChanged<T?>? onChanged;

  final bool isDense;

  final bool isExpanded;

  final TextStyle? style;

  final DropdownButtonBuilder? selectedItemBuilder;

  final List<DropdownMenuItem<T>>? items;

  final RoundedCornerOptions? roundedCornerOptions;

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).colorScheme.backgroundColorSelected;

    Radius selectRadius(bool show) {
      return show ? const Radius.circular(defaultBorderRadius) : Radius.zero;
    }

    final showTopLeft = roundedCornerOptions?.showTopLeft ?? true;
    final showTopRight = roundedCornerOptions?.showTopRight ?? true;
    final showBottomLeft = roundedCornerOptions?.showBottomLeft ?? true;
    final showBottomRight = roundedCornerOptions?.showBottomRight ?? true;
    return RoundedOutlinedBorder(
      showTopLeft: showTopLeft,
      showTopRight: showTopRight,
      showBottomLeft: showBottomLeft,
      showBottomRight: showBottomRight,
      child: Center(
        child: SizedBox(
          height: defaultButtonHeight - 2.0, // subtract 2.0 for width of border
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              padding: const EdgeInsets.only(
                left: defaultSpacing,
                right: borderPadding,
              ),
              value: value,
              onChanged: onChanged,
              isDense: isDense,
              isExpanded: isExpanded,
              borderRadius: BorderRadius.only(
                topLeft: selectRadius(showTopLeft),
                topRight: selectRadius(showTopRight),
                bottomLeft: selectRadius(showBottomLeft),
                bottomRight: selectRadius(showBottomRight),
              ),
              style: style,
              selectedItemBuilder: selectedItemBuilder,
              items: items,
              focusColor: bgColor,
            ),
          ),
        ),
      ),
    );
  }
}

class DevToolsClearableTextField extends StatelessWidget {
  DevToolsClearableTextField({
    Key? key,
    required this.labelText,
    TextEditingController? controller,
    this.hintText,
    this.prefixIcon,
    this.onChanged,
    this.autofocus = false,
  })  : controller = controller ?? TextEditingController(),
        super(key: key);

  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final String labelText;
  final Function(String)? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: autofocus,
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(denseSpacing),
        constraints: BoxConstraints(
          minHeight: defaultTextFieldHeight,
          maxHeight: defaultTextFieldHeight,
        ),
        border: const OutlineInputBorder(),
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: IconButton(
          tooltip: 'Clear',
          icon: const Icon(Icons.clear),
          onPressed: () {
            controller.clear();
            onChanged?.call('');
          },
        ),
        isDense: true,
      ),
    );
  }
}

Widget clearInputButton(VoidCallback onPressed) {
  return inputDecorationSuffixButton(Icons.clear, onPressed);
}

Widget closeSearchDropdownButton(VoidCallback? onPressed) {
  return inputDecorationSuffixButton(Icons.close, onPressed);
}

Widget inputDecorationSuffixButton(IconData icon, VoidCallback? onPressed) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: densePadding),
    height: inputDecorationElementHeight,
    width: defaultIconSize + denseSpacing,
    child: IconButton(
      padding: const EdgeInsets.all(0.0),
      onPressed: onPressed,
      iconSize: defaultIconSize,
      splashRadius: defaultIconSize,
      icon: Icon(icon),
    ),
  );
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: childrenWithOutlines,
    );
  }
}

class OutlineDecoration extends StatelessWidget {
  const OutlineDecoration({
    Key? key,
    this.child,
    this.showTop = true,
    this.showBottom = true,
    this.showLeft = true,
    this.showRight = true,
  }) : super(key: key);

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

class ThickDivider extends StatelessWidget {
  const ThickDivider({super.key});

  static const double thickDividerHeight = 5;

  @override
  Widget build(BuildContext context) {
    return const Divider(
      thickness: thickDividerHeight,
      height: thickDividerHeight,
    );
  }
}

class RoundedOutlinedBorder extends StatelessWidget {
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
      topLeft: showTopLeft
          ? const Radius.circular(defaultBorderRadius)
          : Radius.zero,
      topRight: showTopRight
          ? const Radius.circular(defaultBorderRadius)
          : Radius.zero,
      bottomLeft: showBottomLeft
          ? const Radius.circular(defaultBorderRadius)
          : Radius.zero,
      bottomRight: showBottomRight
          ? const Radius.circular(defaultBorderRadius)
          : Radius.zero,
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

BoxDecoration roundedBorderDecoration(BuildContext context) => BoxDecoration(
      border: Border.all(color: Theme.of(context).focusColor),
      borderRadius: BorderRadius.circular(defaultBorderRadius),
    );

class LeftBorder extends StatelessWidget {
  const LeftBorder({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final leftBorder =
        Border(left: BorderSide(color: Theme.of(context).focusColor));

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

class CenteredMessage extends StatelessWidget {
  const CenteredMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class CenteredCircularProgressIndicator extends StatelessWidget {
  const CenteredCircularProgressIndicator({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    const indicator = Center(
      child: CircularProgressIndicator(),
    );

    if (size == null) return indicator;

    return SizedBox(
      width: size,
      height: size,
      child: indicator,
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

  /// Scroll the content to the bottom using the app's default animation
  /// duration and curve..
  Future<void> autoScrollToBottom() async {
    await animateTo(
      position.maxScrollExtent,
      duration: rapidDuration,
      curve: defaultCurve,
    );

    // Scroll again if we've received new content in the interim.
    if (hasClients) {
      final pos = position;
      if (pos.pixels != pos.maxScrollExtent) {
        jumpTo(pos.maxScrollExtent);
      }
    }
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

/// Utility extension methods to the [Color] class.
extension ColorExtension on Color {
  /// Return a slightly darker color than the current color.
  Color darken([double percent = 0.05]) {
    assert(0.0 <= percent && percent <= 1.0);
    percent = 1.0 - percent;

    final c = this;
    return Color.fromARGB(
      c.alpha,
      (c.red * percent).round(),
      (c.green * percent).round(),
      (c.blue * percent).round(),
    );
  }

  /// Return a slightly brighter color than the current color.
  Color brighten([double percent = 0.05]) {
    assert(0.0 <= percent && percent <= 1.0);

    final c = this;
    return Color.fromARGB(
      c.alpha,
      c.red + ((255 - c.red) * percent).round(),
      c.green + ((255 - c.green) * percent).round(),
      c.blue + ((255 - c.blue) * percent).round(),
    );
  }
}

/// Gets an alternating color to use for indexed UI elements.
Color alternatingColorForIndex(int index, ColorScheme colorScheme) {
  return index % 2 == 1
      ? colorScheme.alternatingBackgroundColor1
      : colorScheme.alternatingBackgroundColor2;
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

  static const height = 28.0;

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
        style: TextStyle(
          color: theme.colorScheme.chartTextColor,
          decoration: TextDecoration.underline,
        ),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout();

    final caretWidth =
        isRoot ? Breadcrumb.caretWidth : Breadcrumb.caretWidth * 2;
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

    final textXOffset =
        isRoot ? densePadding : Breadcrumb.caretWidth + densePadding;
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

// TODO(bkonyi): replace uses of this class with `JsonViewer`.
class FormattedJson extends StatelessWidget {
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
    // TODO(kenz): we could consider using a prettier format like YAML.
    return SelectableText(
      json != null ? encoder.convert(json) : formattedString!,
      style: useSubtleStyle ? theme.subtleFixedFontStyle : theme.fixedFontStyle,
    );
  }
}

class JsonViewer extends StatefulWidget {
  const JsonViewer({
    super.key,
    required this.encodedJson,
  });

  final String encodedJson;

  @override
  State<JsonViewer> createState() => _JsonViewerState();
}

class _JsonViewerState extends State<JsonViewer>
    with ProvidedControllerMixin<DebuggerController, JsonViewer> {
  late Future<void> _initializeTree;
  late DartObjectNode variable;

  Future<void> _buildAndExpand(
    DartObjectNode variable,
  ) async {
    // Build the root node
    await buildVariablesTree(variable);
    // Build the contents of all children
    await Future.wait(variable.children.map(buildVariablesTree));

    // Expand the root node to show the first level of contents
    variable.expand();
  }

  void _updateVariablesTree() {
    assert(widget.encodedJson.isNotEmpty);
    final responseJson = json.decode(widget.encodedJson);
    // Insert the JSON data into the fake service cache so we can use it with
    // the `ExpandableVariable` widget.
    final root =
        serviceManager.service!.fakeServiceCache.insertJsonObject(responseJson);
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
    // Intended to be unawaited.
    // ignore: discarded_futures
    _initializeTree = _buildAndExpand(variable);
  }

  @override
  void initState() {
    super.initState();
    _updateVariablesTree();
  }

  @override
  void didUpdateWidget(JsonViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateVariablesTree();
  }

  @override
  void dispose() {
    super.dispose();
    // Remove the JSON object from the fake service cache to avoid holding on
    // to large objects indefinitely.
    serviceManager.service!.fakeServiceCache
        .removeJsonObject(variable.value as Instance);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Currently a redundant check, but adding it anyway to prevent future
    // bugs being introduced.
    if (!initController()) {
      return;
    }
    // Any additional initialization code should be added after this line.
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: SingleChildScrollView(
        child: FutureBuilder(
          future: _initializeTree,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Container();
            }
            return ExpandableVariable(
              variable: variable,
            );
          },
        ),
      ),
    );
  }
}

class MoreInfoLink extends StatelessWidget {
  const MoreInfoLink({
    Key? key,
    required this.url,
    required this.gaScreenName,
    required this.gaSelectedItemDescription,
    this.padding,
  }) : super(key: key);

  final String url;

  final String gaScreenName;

  final String gaSelectedItemDescription;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _onLinkTap,
      borderRadius: BorderRadius.circular(defaultBorderRadius),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(denseSpacing),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'More info',
              style: theme.linkTextStyle,
            ),
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
    unawaited(launchUrl(url));
    ga.select(gaScreenName, gaSelectedItemDescription);
  }
}

class LinkTextSpan extends TextSpan {
  LinkTextSpan({
    required Link link,
    required BuildContext context,
    TextStyle? style,
  }) : super(
          text: link.display,
          style: style ?? Theme.of(context).linkTextStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              ga.select(
                link.gaScreenName,
                link.gaSelectedItemDescription,
              );
              await launchUrl(link.url);
            },
        );
}

class Link {
  const Link({
    required this.display,
    required this.url,
    required this.gaScreenName,
    required this.gaSelectedItemDescription,
  });

  final String display;

  final String url;

  final String gaScreenName;

  final String gaSelectedItemDescription;
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

class Legend extends StatelessWidget {
  const Legend({
    Key? key,
    required this.entries,
    this.dense = false,
  }) : super(key: key);

  double get legendSquareSize =>
      dense ? scaleByFontFactor(12.0) : scaleByFontFactor(16.0);

  final List<LegendEntry> entries;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textStyle = dense ? Theme.of(context).legendTextStyle : null;
    final List<Widget> legendItems = entries
        .map(
          (entry) => _legendItem(
            entry.description,
            entry.color,
            textStyle,
          ),
        )
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
        Text(
          description,
          style: style,
        ),
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
              copyToClipboard(dataProvider!() ?? '', successMessage),
            );
          };

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
    Key? key,
    required this.notifier,
    this.onChanged,
    this.enabled = true,
    this.checkboxKey,
  }) : super(key: key);

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

class CheckboxSetting extends StatelessWidget {
  const CheckboxSetting({
    Key? key,
    required this.notifier,
    required this.title,
    this.description,
    this.tooltip,
    this.onChanged,
    this.enabled = true,
    this.gaScreenName,
    this.gaItem,
    this.checkboxKey,
  }) : super(key: key);

  final ValueNotifier<bool?> notifier;

  final String title;

  final String? description;

  final String? tooltip;

  final void Function(bool? newValue)? onChanged;

  /// Whether this checkbox setting should be enabled for interaction.
  final bool enabled;

  final String? gaScreenName;

  final String? gaItem;

  final Key? checkboxKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget textContent = RichText(
      overflow: TextOverflow.visible,
      text: TextSpan(
        text: title,
        style: enabled ? theme.regularTextStyle : theme.subtleTextStyle,
      ),
    );

    if (description != null) {
      textContent = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          textContent,
          Expanded(
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                text: ' • $description',
                style: theme.subtleTextStyle,
              ),
            ),
          ),
        ],
      );
    }
    final content = Row(
      children: [
        NotifierCheckbox(
          notifier: notifier,
          onChanged: (bool? value) {
            final gaScreenName = this.gaScreenName;
            final gaItem = this.gaItem;
            if (gaScreenName != null && gaItem != null) {
              ga.select(gaScreenName, gaItem);
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
          child: textContent,
        ),
      ],
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      return DevToolsTooltip(
        message: tooltip,
        child: content,
      );
    }
    return content;
  }
}

class PubWarningText extends StatelessWidget {
  const PubWarningText({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFlutterApp = serviceManager.connectedApp!.isFlutterAppNow == true;
    final sdkName = isFlutterApp ? 'Flutter' : 'Dart';
    final minSdkVersion = isFlutterApp ? '2.8.0' : '2.15.0';
    return SelectableText.rich(
      TextSpan(
        text: 'Warning: you should no longer be launching DevTools from'
            ' pub.\n\n',
        style: theme.subtleTextStyle.copyWith(color: theme.colorScheme.error),
        children: [
          TextSpan(
            text: 'DevTools version 2.8.0 will be the last version to '
                'be shipped on pub. As of $sdkName\nversion >= '
                '$minSdkVersion, DevTools should be launched by running '
                'the ',
            style: theme.subtleTextStyle,
          ),
          TextSpan(
            text: '`dart devtools`',
            style: theme.subtleFixedFontStyle,
          ),
          TextSpan(
            text: '\ncommand.',
            style: theme.subtleTextStyle,
          ),
        ],
      ),
    );
  }
}

class BlinkingIcon extends StatefulWidget {
  const BlinkingIcon({
    Key? key,
    required this.icon,
    required this.color,
    required this.size,
  }) : super(key: key);

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
      crossFadeState:
          showFirst ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    );
  }

  Widget _icon({Color? color}) {
    return Icon(
      widget.icon,
      size: widget.size,
      color: color,
    );
  }
}

// TODO(https://github.com/flutter/devtools/issues/2989): investigate if we can
// modify this widget to be a 'MultiValueListenableBuilder' that can take an
// arbitrary number of listenables.
/// A widget that listens for changes to two different [ValueListenable]s and
/// rebuilds for change notifications to either.
///
/// This widget is preferred over nesting two [ValueListenableBuilder]s in a
/// single build method.
class DualValueListenableBuilder<T, U> extends StatefulWidget {
  const DualValueListenableBuilder({
    Key? key,
    required this.firstListenable,
    required this.secondListenable,
    required this.builder,
    this.child,
  }) : super(key: key);

  final ValueListenable<T> firstListenable;

  final ValueListenable<U> secondListenable;

  final Widget Function(
    BuildContext context,
    T firstValue,
    U secondValue,
    Widget? child,
  ) builder;

  final Widget? child;

  @override
  State<DualValueListenableBuilder<T, U>> createState() =>
      _DualValueListenableBuilderState<T, U>();
}

class _DualValueListenableBuilderState<T, U>
    extends State<DualValueListenableBuilder<T, U>> with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(widget.firstListenable);
    addAutoDisposeListener(widget.secondListenable);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      widget.firstListenable.value,
      widget.secondListenable.value,
      widget.child,
    );
  }
}

class SmallCircularProgressIndicator extends StatelessWidget {
  const SmallCircularProgressIndicator({
    Key? key,
    required this.valueColor,
  }) : super(key: key);

  final Animation<Color?> valueColor;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: valueColor,
    );
  }
}

class ElevatedCard extends StatelessWidget {
  const ElevatedCard({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.padding,
  }) : super(key: key);

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: defaultElevation,
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(defaultBorderRadius),
      ),
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
/// rebuilding. This is useful for children of [TabView]s. When wrapped in this
/// wrapper, [child] will not be destroyed and rebuilt when switching tabs.
///
/// See [AutomaticKeepAliveClientMixin] for more information.
class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({Key? key, required this.child}) : super(key: key);

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
    this.outlined = true,
  });

  final String gaScreen;

  final String gaSelection;

  final String dialogTitle;

  final Widget child;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return HelpButton(
      onPressed: () {
        ga.select(gaScreen, gaSelection);
        unawaited(
          showDialog(
            context: context,
            builder: (context) => DevToolsDialog(
              title: DialogTitleText(dialogTitle),
              includeDivider: false,
              content: child,
              actions: const [
                DialogCloseButton(),
              ],
            ),
          ),
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
    final ThemeData theme = Theme.of(context);

    final textStyle = theme.textTheme.bodyMedium;
    final mutedColor = textStyle?.color?.withAlpha(0x90);

    return Container(
      width: width,
      height: actionWidgetSize,
      alignment: Alignment.center,
      child: Text(
        '•',
        style: textStyle?.copyWith(color: color ?? mutedColor),
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
        child: SizedBox(
          width: _lineWidth,
          height: height,
        ),
      ),
    );
  }
}

class ToCsvButton extends StatelessWidget {
  const ToCsvButton({
    Key? key,
    this.onPressed,
    this.tooltip = 'Download data in CSV format',
    required this.minScreenWidthForTextBeforeScaling,
    required this.gaScreen,
    required this.gaSelection,
  }) : super(key: key);

  final VoidCallback? onPressed;
  final String? tooltip;
  final double minScreenWidthForTextBeforeScaling;
  final String gaScreen;
  final String gaSelection;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton(
      label: 'CSV',
      icon: Icons.file_download,
      tooltip: tooltip,
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      onPressed: onPressed,
      minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
    );
  }
}

class RadioButton<T> extends StatelessWidget {
  const RadioButton({
    super.key,
    required this.label,
    required this.itemValue,
    required this.groupValue,
    this.onChanged,
    this.radioKey,
  });

  final String label;
  final T itemValue;
  final T groupValue;
  final void Function(T?)? onChanged;
  final Key? radioKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Radio<T>(
          value: itemValue,
          groupValue: groupValue,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: onChanged,
          key: radioKey,
        ),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class ContextMenuButton extends StatelessWidget {
  ContextMenuButton({
    super.key,
    required this.menuChildren,
    this.color,
    this.gaScreen,
    this.gaItem,
    this.buttonWidth = defaultWidth,
    this.icon = Icons.more_vert,
    double? iconSize,
  }) : iconSize = iconSize ?? tableIconSize;

  static const double defaultWidth = 14.0;
  static const double densePadding = 2.0;

  final Color? color;
  final String? gaScreen;
  final String? gaItem;
  final List<Widget> menuChildren;
  final IconData icon;
  final double iconSize;
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
