// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../screens/debugger/debugger_controller.dart';
import '../screens/inspector/layout_explorer/ui/theme.dart';
import 'analytics/analytics.dart' as ga;
import 'analytics/constants.dart' as gac;
import 'config_specific/copy_to_clipboard/copy_to_clipboard.dart';
import 'config_specific/launch_url/launch_url.dart';
import 'console/widgets/expandable_variable.dart';
import 'diagnostics/dart_object_node.dart';
import 'diagnostics/tree_builder.dart';
import 'globals.dart';
import 'primitives/flutter_widgets/linked_scroll_controller.dart';
import 'primitives/utils.dart';
import 'routing.dart';
import 'utils.dart';

/// The width of the package:flutter_test debugger device.
const debuggerDeviceWidth = 800.0;

const defaultDialogRadius = 20.0;

double get assumedMonospaceCharacterWidth =>
    scaleByFontFactor(_assumedMonospaceCharacterWidth);
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
    super.minScreenWidthForTextBeforeScaling,
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

class ResumeButton extends GaDevToolsButton {
  ResumeButton({
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

class ClearButton extends GaDevToolsButton {
  ClearButton({
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

class RefreshButton extends GaDevToolsButton {
  RefreshButton({
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
class RecordButton extends GaDevToolsButton {
  RecordButton({
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
class StopRecordingButton extends GaDevToolsButton {
  StopRecordingButton({
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
  }) : super(
          icon: Icons.help_outline,
          tooltip: 'Help',
        );
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
    return GaDevToolsButton(
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
    return GaDevToolsButton(
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
        return GaDevToolsButton(
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
      height: defaultButtonHeight,
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

/// Icon action button used in the main DevTools toolbar or footer.
abstract class ScaffoldAction extends StatelessWidget {
  const ScaffoldAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;

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
          child: Icon(
            icon,
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

class RoundedCornerOptions {
  const RoundedCornerOptions({
    this.showTopLeft = true,
    this.showTopRight = true,
    this.showBottomLeft = true,
    this.showBottomRight = true,
  });

  /// Static constant instance with all borders hidden
  static const RoundedCornerOptions empty = RoundedCornerOptions(
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
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.backgroundColorSelected;

    Radius selectRadius(bool show) {
      return show ? defaultRadius : Radius.zero;
    }

    final style = this.style ?? theme.regularTextStyle;
    final showTopLeft = roundedCornerOptions?.showTopLeft ?? true;
    final showTopRight = roundedCornerOptions?.showTopRight ?? true;
    final showBottomLeft = roundedCornerOptions?.showBottomLeft ?? true;
    final showBottomRight = roundedCornerOptions?.showBottomRight ?? true;

    final button = Center(
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
    );

    if (roundedCornerOptions == RoundedCornerOptions.empty) return button;

    return RoundedOutlinedBorder(
      showTopLeft: showTopLeft,
      showTopRight: showTopRight,
      showBottomLeft: showBottomLeft,
      showBottomRight: showBottomRight,
      child: button,
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
    this.additionalSuffixActions = const <Widget>[],
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled,
    this.roundedBorder = false,
  })  : controller = controller ?? TextEditingController(),
        super(key: key);

  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final List<Widget> additionalSuffixActions;
  final String labelText;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool autofocus;
  final bool? enabled;
  final bool roundedBorder;

  static const _contentVerticalPadding = 6.0;

  /// This is the default border radius used by the [OutlineInputBorder]
  /// constructor.
  static const _defaultInputBorderRadius =
      BorderRadius.all(Radius.circular(4.0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: defaultTextFieldHeight,
      child: TextField(
        autofocus: autofocus,
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: theme.regularTextStyle,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.only(
            top: _contentVerticalPadding,
            bottom: _contentVerticalPadding,
            left: denseSpacing,
            right: densePadding,
          ),
          constraints: BoxConstraints(
            minHeight: defaultTextFieldHeight,
            maxHeight: defaultTextFieldHeight,
          ),
          border: OutlineInputBorder(
            borderRadius: roundedBorder
                ? const BorderRadius.all(defaultRadius)
                : _defaultInputBorderRadius,
          ),
          labelText: labelText,
          labelStyle: theme.subtleTextStyle,
          hintText: hintText,
          hintStyle: theme.subtleTextStyle,
          prefixIcon: prefixIcon,
          suffix: SizedBox(
            height: inputDecorationElementHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                clearInputButton(
                  () {
                    controller.clear();
                    onChanged?.call('');
                  },
                ),
                ...additionalSuffixActions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget clearInputButton(VoidCallback onPressed) {
  return inputDecorationSuffixButton(
    icon: Icons.clear,
    onPressed: onPressed,
    tooltip: 'Clear',
  );
}

Widget closeSearchDropdownButton(VoidCallback? onPressed) {
  return inputDecorationSuffixButton(icon: Icons.close, onPressed: onPressed);
}

Widget inputDecorationSuffixButton({
  required IconData icon,
  required VoidCallback? onPressed,
  String? tooltip,
}) {
  return maybeWrapWithTooltip(
    tooltip: tooltip,
    child: SizedBox(
      height: inputDecorationElementHeight,
      width: inputDecorationElementHeight + denseSpacing,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        iconSize: defaultIconSize,
        splashRadius: defaultIconSize,
        icon: Icon(icon),
      ),
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

BoxDecoration roundedBorderDecoration(BuildContext context) => BoxDecoration(
      border: Border.all(color: Theme.of(context).focusColor),
      borderRadius: defaultBorderRadius,
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

/// A centered text widget with the default DevTools text style applied.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).regularTextStyle,
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
    return SelectionArea(
      child: Text(
        displayText,
        style: style,
      ),
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
  static const jsonEncoder = JsonEncoder.withIndent('  ');

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
    serviceConnection.serviceManager.service!.fakeServiceCache
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
    return SelectionArea(
      child: Padding(
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
                onCopy: (copiedVariable) {
                  unawaited(
                    copyToClipboard(
                      jsonEncoder.convert(
                        serviceConnection
                            .serviceManager.service!.fakeServiceCache
                            .instanceToJson(copiedVariable.value as Instance),
                      ),
                      'JSON copied to clipboard',
                    ),
                  );
                },
              );
            },
          ),
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
      borderRadius: defaultBorderRadius,
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

class LinkIconLabel extends StatelessWidget {
  const LinkIconLabel({
    super.key,
    required this.icon,
    required this.link,
    required this.color,
  });

  final IconData icon;
  final Link link;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _onLinkTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: defaultIconSize,
            color: color,
          ),
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
    unawaited(launchUrl(link.url));
    if (link.gaScreenName != null && link.gaSelectedItemDescription != null) {
      ga.select(link.gaScreenName!, link.gaSelectedItemDescription!);
    }
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
              if (link.gaScreenName != null &&
                  link.gaSelectedItemDescription != null) {
                ga.select(
                  link.gaScreenName!,
                  link.gaSelectedItemDescription!,
                );
              }
              await launchUrl(link.url);
            },
        );
}

class Link {
  const Link({
    required this.display,
    required this.url,
    this.gaScreenName,
    this.gaSelectedItemDescription,
  });

  final String display;

  final String url;

  final String? gaScreenName;

  final String? gaSelectedItemDescription;
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

/// A widget that represents a check box setting and automatically updates for
/// value changes to [notifier].
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
    Widget checkboxAndTitle = Row(
      mainAxisSize: MainAxisSize.min,
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
                    text: TextSpan(
                      text: ' • ',
                      style: theme.subtleTextStyle,
                    ),
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

class PubWarningText extends StatelessWidget {
  const PubWarningText({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFlutterApp =
        serviceConnection.serviceManager.connectedApp!.isFlutterAppNow == true;
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
  ) builder;

  final Widget? child;

  @override
  State<MultiValueListenableBuilder> createState() =>
      _MultiValueListenableBuilderState();
}

class _MultiValueListenableBuilderState
    extends State<MultiValueListenableBuilder> with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    widget.listenables.forEach(addAutoDisposeListener);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      [for (final listenable in widget.listenables) listenable.value],
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
        borderRadius: defaultBorderRadius,
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
        child: SizedBox(
          width: _lineWidth,
          height: height,
        ),
      ),
    );
  }
}

class DownloadButton extends StatelessWidget {
  const DownloadButton({
    Key? key,
    this.onPressed,
    this.tooltip = 'Download data',
    this.label = 'Download',
    required this.minScreenWidthForTextBeforeScaling,
    required this.gaScreen,
    required this.gaSelection,
  }) : super(key: key);

  final VoidCallback? onPressed;
  final String? tooltip;
  final String label;
  final double minScreenWidthForTextBeforeScaling;
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
