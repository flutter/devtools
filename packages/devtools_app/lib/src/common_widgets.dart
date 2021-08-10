// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'scaffold.dart';
import 'theme.dart';
import 'ui/label.dart';

const tooltipWait = Duration(milliseconds: 500);
const tooltipWaitLong = Duration(milliseconds: 1000);

/// The width of the package:flutter_test debugger device.
const debuggerDeviceWidth = 800.0;

const mediumDeviceWidth = 1000.0;

const defaultDialogRadius = 20.0;

const areaPaneHeaderHeight = 36.0;

/// Convenience [Divider] with [Padding] that provides a good divider in forms.
class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    Key key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  }) : super(key: key);

  const PaddedDivider.thin({Key key})
      : padding = const EdgeInsets.only(bottom: 4.0);

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

/// A button with an icon and a label.
///
/// * `onPressed`: The callback to be called upon pressing the button.
/// * `includeTextWidth`: The minimum width the button can be before the text is
///    omitted.
class IconLabelButton extends StatelessWidget {
  const IconLabelButton({
    Key key,
    @required this.icon,
    @required this.label,
    @required this.onPressed,
    this.color,
    this.includeTextWidth,
    this.elevatedButton = false,
    this.tooltip,
  }) : super(key: key);

  final IconData icon;

  final String label;

  final double includeTextWidth;

  final VoidCallback onPressed;

  final Color color;

  /// Whether this icon label button should use an elevated button style.
  final bool elevatedButton;

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final iconLabel = MaterialIconLabel(
      label: label,
      iconData: icon,
      includeTextWidth: includeTextWidth,
      color: color,
    );
    if (elevatedButton) {
      return maybeWrapWithTooltip(
        tooltip,
        ElevatedButton(
          onPressed: onPressed,
          child: iconLabel,
        ),
      );
    }
    // TODO(kenz): this SizedBox wrapper should be unnecessary once
    // https://github.com/flutter/flutter/issues/79894 is fixed.
    return maybeWrapWithTooltip(
      tooltip,
      SizedBox(
        height: defaultButtonHeight,
        width: !includeText(context, includeTextWidth) ? buttonMinWidth : null,
        child: OutlinedButton(
          style: denseAwareOutlinedButtonStyle(context, includeTextWidth),
          onPressed: onPressed,
          child: iconLabel,
        ),
      ),
    );
  }
}

class PauseButton extends IconLabelButton {
  const PauseButton({
    Key key,
    double includeTextWidth,
    String tooltip = 'Pause',
    @required VoidCallback onPressed,
  }) : super(
          key: key,
          icon: Icons.pause,
          label: 'Pause',
          tooltip: tooltip,
          includeTextWidth: includeTextWidth,
          onPressed: onPressed,
        );
}

class ResumeButton extends IconLabelButton {
  const ResumeButton({
    Key key,
    double includeTextWidth,
    String tooltip = 'Resume',
    @required VoidCallback onPressed,
  }) : super(
          key: key,
          icon: Icons.play_arrow,
          label: 'Resume',
          tooltip: tooltip,
          includeTextWidth: includeTextWidth,
          onPressed: onPressed,
        );
}

class ClearButton extends IconLabelButton {
  const ClearButton({
    Key key,
    double includeTextWidth,
    String tooltip = 'Clear',
    @required VoidCallback onPressed,
  }) : super(
          key: key,
          icon: Icons.block,
          label: 'Clear',
          tooltip: tooltip,
          includeTextWidth: includeTextWidth,
          onPressed: onPressed,
        );
}

class RefreshButton extends IconLabelButton {
  const RefreshButton({
    Key key,
    String label = 'Refresh',
    double includeTextWidth,
    String tooltip,
    @required VoidCallback onPressed,
  }) : super(
          key: key,
          icon: Icons.refresh,
          label: label,
          includeTextWidth: includeTextWidth,
          tooltip: tooltip,
          onPressed: onPressed,
        );
}

/// Button to start recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `includeTextWidth`: The minimum width the button can be before the text is
///    omitted.
/// * `labelOverride`: Optional alternative text to use for the button.
/// * `onPressed`: The callback to be called upon pressing the button.
class RecordButton extends IconLabelButton {
  const RecordButton({
    Key key,
    @required bool recording,
    @required VoidCallback onPressed,
    double includeTextWidth,
    String labelOverride,
    String tooltip = 'Start recording',
  }) : super(
          key: key,
          onPressed: recording ? null : onPressed,
          icon: Icons.fiber_manual_record,
          label: labelOverride ?? 'Record',
          tooltip: tooltip,
          includeTextWidth: includeTextWidth,
        );
}

/// Button to stop recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `includeTextWidth`: The minimum width the button can be before the text is
///    omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
class StopRecordingButton extends IconLabelButton {
  const StopRecordingButton({
    Key key,
    @required bool recording,
    @required VoidCallback onPressed,
    double includeTextWidth,
    String tooltip = 'Stop recording',
  }) : super(
          key: key,
          onPressed: !recording ? null : onPressed,
          icon: Icons.stop,
          label: 'Stop',
          tooltip: tooltip,
          includeTextWidth: includeTextWidth,
        );
}

class SettingsOutlinedButton extends IconLabelButton {
  const SettingsOutlinedButton({
    @required VoidCallback onPressed,
    @required String label,
    String tooltip,
  }) : super(
          onPressed: onPressed,
          icon: Icons.settings,
          label: label,
          tooltip: tooltip,
          // TODO(jacobr): consider a more conservative min-width. To minimize the
          // impact on the existing UI and deal with the fact that some of the
          // existing label names are fairly verbose, we set a width that will
          // never be hit.
          includeTextWidth: 20000,
        );
}

class HelpButton extends StatelessWidget {
  const HelpButton({@required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Container(
        height: defaultButtonHeight,
        width: defaultButtonHeight,
        child: const Icon(
          Icons.help_outline,
          size: defaultIconSize,
        ),
      ),
    );
  }
}

class ExpandAllButton extends StatelessWidget {
  const ExpandAllButton({Key key, @required this.onPressed}) : super(key: key);

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: const Text('Expand All'),
    );
  }
}

class CollapseAllButton extends StatelessWidget {
  const CollapseAllButton({Key key, @required this.onPressed})
      : super(key: key);

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: const Text('Collapse All'),
    );
  }
}

class RecordingInfo extends StatelessWidget {
  const RecordingInfo({
    this.instructionsKey,
    this.recordingStatusKey,
    this.processingStatusKey,
    @required this.recording,
    @required this.recordedObject,
    @required this.processing,
    this.progressValue,
    this.isPause = false,
  });

  final Key instructionsKey;

  final Key recordingStatusKey;

  final Key processingStatusKey;

  final bool recording;

  final String recordedObject;

  final bool processing;

  final double progressValue;

  final bool isPause;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (processing) {
      child = ProcessingInfo(
        key: processingStatusKey,
        progressValue: progressValue,
        processedObject: recordedObject,
      );
    } else if (recording) {
      child = RecordingStatus(
        key: recordingStatusKey,
        recordedObject: recordedObject,
      );
    } else {
      child = RecordingInstructions(
        key: instructionsKey,
        recordedObject: recordedObject,
        isPause: isPause,
      );
    }
    return Center(
      child: child,
    );
  }
}

class RecordingStatus extends StatelessWidget {
  const RecordingStatus({
    Key key,
    @required this.recordedObject,
  }) : super(key: key);

  final String recordedObject;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Recording $recordedObject',
          style: Theme.of(context).subtleTextStyle,
        ),
        const SizedBox(height: defaultSpacing),
        const CircularProgressIndicator(),
      ],
    );
  }
}

class RecordingInstructions extends StatelessWidget {
  const RecordingInstructions({
    Key key,
    @required this.isPause,
    @required this.recordedObject,
  }) : super(key: key);

  final String recordedObject;

  final bool isPause;

  @override
  Widget build(BuildContext context) {
    final stopOrPauseRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: isPause
          ? const [
              Text('Click the pause button '),
              Icon(Icons.pause),
              Text(' to pause the recording.'),
            ]
          : const [
              Text('Click the stop button '),
              Icon(Icons.stop),
              Text(' to end the recording.'),
            ],
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Click the record button '),
            const Icon(Icons.fiber_manual_record),
            Text(' to start recording $recordedObject.')
          ],
        ),
        stopOrPauseRow,
      ],
    );
  }
}

class ProcessingInfo extends StatelessWidget {
  const ProcessingInfo({
    Key key,
    @required this.progressValue,
    @required this.processedObject,
  }) : super(key: key);

  final double progressValue;

  final String processedObject;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Processing $processedObject',
            style: Theme.of(context).subtleTextStyle,
          ),
          const SizedBox(height: defaultSpacing),
          SizedBox(
            width: 200.0,
            height: defaultSpacing,
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
///
/// Consumers of this widget will be responsible for including the following in
/// onPressed:
///
/// setState(() {
///   offlineMode = false;
/// }
class ExitOfflineButton extends IconLabelButton {
  const ExitOfflineButton({@required VoidCallback onPressed})
      : super(
          key: const Key('exit offline button'),
          onPressed: onPressed,
          label: 'Exit offline mode',
          icon: Icons.clear,
        );
}

/// Display a single bullet character in order to act as a stylized spacer
/// component.
class BulletSpacer extends StatelessWidget {
  const BulletSpacer({this.useAccentColor = false});

  final bool useAccentColor;

  static const width = DevToolsScaffold.actionWidgetSize / 2;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    TextStyle textStyle;
    if (useAccentColor) {
      textStyle = theme.appBarTheme.toolbarTextStyle ??
          theme.primaryTextTheme.bodyText2;
    } else {
      textStyle = theme.textTheme.bodyText2;
    }

    final mutedColor = textStyle?.color?.withAlpha(0x90);

    return Container(
      width: width,
      height: DevToolsScaffold.actionWidgetSize,
      alignment: Alignment.center,
      child: Text(
        '•',
        style: textStyle?.copyWith(color: mutedColor),
      ),
    );
  }
}

/// A small element containing some accessory information, often a numeric
/// value.
class Badge extends StatelessWidget {
  const Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // These constants are sized to give 1 digit badges a circular look.
    const badgeCornerRadius = 12.0;
    const badgePadding = 6.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: BorderRadius.circular(badgeCornerRadius),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: borderPadding,
        horizontal: badgePadding,
      ),
      child: Text(
        text,
        // Use a slightly smaller font for the badge.
        style: theme.primaryTextTheme.bodyText2.apply(fontSizeDelta: -1),
      ),
    );
  }
}

/// A widget, commonly used for icon buttons, that provides a tooltip with a
/// common delay before the tooltip is shown.
class DevToolsTooltip extends StatelessWidget {
  const DevToolsTooltip({
    @required this.tooltip,
    @required this.child,
    this.waitDuration = tooltipWait,
    this.preferBelow = false,
    this.padding,
  });

  final String tooltip;
  final Widget child;
  final Duration waitDuration;
  final bool preferBelow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: waitDuration,
      preferBelow: preferBelow,
      padding: padding,
      child: child,
    );
  }
}

/// A wrapper around a TextButton, an Icon, and an optional Tooltip; used for
/// small toolbar actions.
class ToolbarAction extends StatelessWidget {
  const ToolbarAction({
    @required this.icon,
    @required this.onPressed,
    this.tooltip,
    Key key,
  }) : super(key: key);

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Icon(icon, size: actionsIconSize),
    );

    return tooltip == null
        ? button
        : Tooltip(
            message: tooltip,
            waitDuration: tooltipWait,
            child: button,
          );
  }
}

/// Create a bordered, fixed-height header area with a title and optional child
/// on the right-hand side.
///
/// This is typically used as a title for a logical area of the screen.
class AreaPaneHeader extends StatelessWidget implements PreferredSizeWidget {
  const AreaPaneHeader({
    Key key,
    @required this.title,
    this.maxLines = 1,
    this.needsTopBorder = true,
    this.needsBottomBorder = true,
    this.needsLeftBorder = false,
    this.leftActions = const [],
    this.rightActions = const [],
    this.rightPadding = densePadding,
    this.tall = false,
  }) : super(key: key);

  final Widget title;
  final int maxLines;
  final bool needsTopBorder;
  final bool needsBottomBorder;
  final bool needsLeftBorder;
  final List<Widget> leftActions;
  final List<Widget> rightActions;
  final double rightPadding;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.fromSize(
      size: preferredSize,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: needsTopBorder ? defaultBorderSide(theme) : BorderSide.none,
            bottom:
                needsBottomBorder ? defaultBorderSide(theme) : BorderSide.none,
            left: needsLeftBorder ? defaultBorderSide(theme) : BorderSide.none,
          ),
          color: theme.titleSolidBackgroundColor,
        ),
        padding: EdgeInsets.only(left: defaultSpacing, right: rightPadding),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            DefaultTextStyle(
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.subtitle2,
              child: title,
            ),
            ...leftActions,
            if (rightActions.isNotEmpty) const Spacer(),
            ...rightActions,
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize {
    return Size.fromHeight(
      tall ? areaPaneHeaderHeight + 2 * densePadding : areaPaneHeaderHeight,
    );
  }
}

BorderSide defaultBorderSide(ThemeData theme) {
  return BorderSide(color: theme.focusColor);
}

/// Toggle button for use as a child of a [ToggleButtons] widget.
class ToggleButton extends StatelessWidget {
  const ToggleButton({
    @required this.icon,
    @required this.text,
    @required this.enabledTooltip,
    @required this.disabledTooltip,
    @required this.includeTextWidth,
    @required this.selected,
  });

  final IconData icon;
  final String text;
  final String enabledTooltip;
  final String disabledTooltip;
  final double includeTextWidth;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? enabledTooltip : disabledTooltip,
      waitDuration: tooltipWait,
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
        child: MaterialIconLabel(
          label: text,
          iconData: icon,
          includeTextWidth: includeTextWidth,
        ),
      ),
    );
  }
}

/// Button to export data.
///
/// * `includeTextWidth`: The minimum width the button can be before the text is
///    omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
class ExportButton extends IconLabelButton {
  const ExportButton({
    Key key,
    @required VoidCallback onPressed,
    @required double includeTextWidth,
    String tooltip = 'Export data',
  }) : super(
          key: key,
          onPressed: onPressed,
          icon: Icons.file_download,
          label: 'Export',
          tooltip: tooltip,
          includeTextWidth: includeTextWidth,
        );
}

class FilterButton extends StatelessWidget {
  const FilterButton({
    Key key,
    @required this.onPressed,
    @required this.isFilterActive,
  }) : super(key: key);

  final VoidCallback onPressed;

  final bool isFilterActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsTooltip(
      tooltip: 'Filter',
      // TODO(kenz): this SizedBox wrapper should be unnecessary once
      // https://github.com/flutter/flutter/issues/79894 is fixed.
      child: SizedBox(
        height: defaultButtonHeight,
        child: OutlinedButton(
          key: key,
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: isFilterActive
                ? theme.colorScheme.toggleButtonBackgroundColor
                : Colors.transparent,
          ),
          child: Icon(
            Icons.filter_list,
            size: defaultIconSize,
            color: isFilterActive
                ? theme.colorScheme.toggleButtonForegroundColor
                : theme.colorScheme.contrastForeground,
          ),
        ),
      ),
    );
  }
}

class RoundedDropDownButton<T> extends StatelessWidget {
  const RoundedDropDownButton({
    Key key,
    this.value,
    this.onChanged,
    this.isDense = false,
    this.style,
    this.selectedItemBuilder,
    this.items,
  }) : super(key: key);

  final T value;

  final ValueChanged<T> onChanged;

  final bool isDense;

  final TextStyle style;

  final DropdownButtonBuilder selectedItemBuilder;

  final List<DropdownMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      child: Center(
        child: Container(
          padding: const EdgeInsets.only(
            left: defaultSpacing,
            right: borderPadding,
          ),
          height: defaultButtonHeight - 2.0, // subtract 2.0 for width of border
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              onChanged: onChanged,
              isDense: isDense,
              style: style,
              selectedItemBuilder: selectedItemBuilder,
              items: items,
            ),
          ),
        ),
      ),
    );
  }
}

Widget clearInputButton(VoidCallback onPressed) {
  return inputDecorationSuffixButton(Icons.clear, onPressed);
}

Widget closeSearchDropdownButton(VoidCallback onPressed) {
  return inputDecorationSuffixButton(Icons.close, onPressed);
}

Widget inputDecorationSuffixButton(IconData icon, VoidCallback onPressed) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: densePadding),
    width: 24.0,
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
  const OutlinedRowGroup({@required this.children, this.borderColor});

  final List<Widget> children;

  final Color borderColor;

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
  const OutlineDecoration({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).focusColor),
      ),
      child: child,
    );
  }
}

class RoundedOutlinedBorder extends StatelessWidget {
  const RoundedOutlinedBorder({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: roundedBorderDecoration(context),
      child: child,
    );
  }
}

BoxDecoration roundedBorderDecoration(BuildContext context) => BoxDecoration(
      border: Border.all(color: Theme.of(context).focusColor),
      borderRadius: BorderRadius.circular(defaultBorderRadius),
    );

class LeftBorder extends StatelessWidget {
  const LeftBorder({this.child});

  final Widget child;

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
  const CenteredMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.headline6,
      ),
    );
  }
}

class CenteredCircularProgressIndicator extends StatelessWidget {
  const CenteredCircularProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class CircularIconButton extends StatelessWidget {
  const CircularIconButton({
    @required this.icon,
    @required this.onPressed,
    @required this.backgroundColor,
    @required this.foregroundColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return RawMaterialButton(
      fillColor: backgroundColor,
      hoverColor: Theme.of(context).hoverColor,
      elevation: 0.0,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      constraints: const BoxConstraints.tightFor(
        width: actionsIconSize,
        height: actionsIconSize,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(
          width: 2.0,
          color: foregroundColor,
        ),
      ),
      onPressed: onPressed,
      child: Icon(
        icon,
        size: defaultIconSize,
        color: foregroundColor,
      ),
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
  void autoScrollToBottom() async {
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
      ? colorScheme.defaultBackgroundColor
      : colorScheme.alternatingBackgroundColor;
}

class BreadcrumbNavigator extends StatelessWidget {
  const BreadcrumbNavigator.builder({
    @required this.itemCount,
    @required this.builder,
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
    @required this.text,
    @required this.isRoot,
    @required this.onPressed,
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
    @required this.textPainter,
    @required this.isRoot,
    @required this.breadcrumbWidth,
    @required this.colorScheme,
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

class FormattedJson extends StatelessWidget {
  const FormattedJson({
    this.json,
    this.formattedString,
    this.useSubtleStyle = false,
  }) : assert((json == null) != (formattedString == null));

  static const encoder = JsonEncoder.withIndent('  ');

  final Map<String, dynamic> json;

  final String formattedString;

  final bool useSubtleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // TODO(kenz): we could consider using a prettier format like YAML.
    return SelectableText(
      json != null ? encoder.convert(json) : formattedString,
      style: useSubtleStyle ? theme.subtleFixedFontStyle : theme.fixedFontStyle,
    );
  }
}

class Link {
  const Link({this.display, this.url});

  final String display;

  final String url;
}

Widget maybeWrapWithTooltip(String tooltip, Widget child) {
  if (tooltip != null) {
    return DevToolsTooltip(
      tooltip: tooltip,
      child: child,
    );
  }
  return child;
}
