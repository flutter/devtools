// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'scaffold.dart';
import 'theme.dart';
import 'ui/label.dart';
import 'ui/theme.dart';

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
        : theme.accentColor,
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
    this.includeTextWidth,
  }) : super(key: key);

  final IconData icon;

  final String label;

  final double includeTextWidth;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      onPressed: onPressed,
      child: MaterialIconLabel(
        icon,
        label,
        includeTextWidth: includeTextWidth,
      ),
    );
  }
}

class PauseButton extends IconLabelButton {
  const PauseButton({
    Key key,
    double includeTextWidth,
    @required VoidCallback onPressed,
  }) : super(
          key: key,
          icon: Icons.pause,
          label: 'Pause',
          includeTextWidth: includeTextWidth,
          onPressed: onPressed,
        );
}

class ResumeButton extends IconLabelButton {
  const ResumeButton({
    Key key,
    double includeTextWidth,
    @required VoidCallback onPressed,
  }) : super(
          key: key,
          icon: Icons.play_arrow,
          label: 'Resume',
          includeTextWidth: includeTextWidth,
          onPressed: onPressed,
        );
}

class ClearButton extends IconLabelButton {
  const ClearButton({
    Key key,
    double includeTextWidth,
    @required VoidCallback onPressed,
  }) : super(
          key: key,
          icon: Icons.block,
          label: 'Clear',
          includeTextWidth: includeTextWidth,
          onPressed: onPressed,
        );
}

class RefreshButton extends IconLabelButton {
  const RefreshButton({
    Key key,
    double includeTextWidth,
    @required VoidCallback onPressed,
  }) : super(
          key: key,
          icon: Icons.refresh,
          label: 'Refresh',
          includeTextWidth: includeTextWidth,
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
class RecordButton extends StatelessWidget {
  const RecordButton({
    Key key,
    @required this.recording,
    this.includeTextWidth,
    this.labelOverride,
    @required this.onPressed,
  }) : super(key: key);

  final bool recording;

  final double includeTextWidth;

  final String labelOverride;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      onPressed: recording ? null : onPressed,
      child: MaterialIconLabel(
        Icons.fiber_manual_record,
        labelOverride ?? 'Record',
        includeTextWidth: includeTextWidth,
      ),
    );
  }
}

/// Button to stop recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `includeTextWidth`: The minimum width the button can be before the text is
///    omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
class StopRecordingButton extends StatelessWidget {
  const StopRecordingButton({
    Key key,
    @required this.recording,
    this.includeTextWidth,
    @required this.onPressed,
  }) : super(key: key);

  final bool recording;

  final double includeTextWidth;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      onPressed: !recording ? null : onPressed,
      child: MaterialIconLabel(
        Icons.stop,
        'Stop',
        includeTextWidth: includeTextWidth,
      ),
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
      child = _recordingStatus(
        key: recordingStatusKey,
        recordedObject: recordedObject,
      );
    } else {
      child = _recordingInstructions(
        key: instructionsKey,
        recordedObject: recordedObject,
        isPause: isPause,
      );
    }
    return Center(
      child: child,
    );
  }

  Widget _recordingInstructions(
      {Key key, String recordedObject, bool isPause}) {
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
      key: key,
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

  Widget _recordingStatus({Key key, String recordedObject}) {
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Recording $recordedObject'),
        const SizedBox(height: defaultSpacing),
        const CircularProgressIndicator(),
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
          Text('Processing $processedObject'),
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
class ExitOfflineButton extends StatelessWidget {
  const ExitOfflineButton({@required this.onPressed});

  final FutureOr<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      key: const Key('exit offline button'),
      onPressed: onPressed,
      child: const MaterialIconLabel(
        Icons.clear,
        'Exit offline mode',
      ),
    );
  }
}

/// Display a single bullet character in order to act as a stylized spacer
/// component.
class BulletSpacer extends StatelessWidget {
  const BulletSpacer({this.useAccentColor = false});

  final bool useAccentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    TextTheme textTheme;
    if (useAccentColor) {
      textTheme = theme.appBarTheme.textTheme ?? theme.primaryTextTheme;
    } else {
      textTheme = theme.textTheme;
    }

    final textStyle = textTheme.bodyText2;
    final mutedColor = textStyle?.color?.withAlpha(0x90);

    return Container(
      width: DevToolsScaffold.actionWidgetSize / 2,
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
class ActionButton extends StatelessWidget {
  const ActionButton({
    @required this.tooltip,
    @required this.child,
  });

  final String tooltip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: tooltipWait,
      child: child,
    );
  }
}

/// A wrapper around a FlatButton, an Icon, and an optional Tooltip; used for
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
    final button = FlatButton(
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
// TODO(devoncarew): Refactor this into an 'AreaPaneHeader' widget.
// TODO(peterdjlee): Consider passing in a list of widgets for content instead of String title.
SizedBox areaPaneHeader(
  BuildContext context, {
  @required String title,
  bool needsTopBorder = true,
  bool needsBottomBorder = true,
  bool needsLeftBorder = false,
  List<Widget> actions = const [],
  double rightPadding = densePadding,
  bool tall = false,
}) {
  final theme = Theme.of(context);
  return SizedBox(
    height:
        tall ? areaPaneHeaderHeight + 2 * densePadding : areaPaneHeaderHeight,
    child: Container(
      decoration: BoxDecoration(
        border: Border(
          top: needsTopBorder ? defaultBorderSide(theme) : BorderSide.none,
          bottom:
              needsBottomBorder ? defaultBorderSide(theme) : BorderSide.none,
          left: needsLeftBorder ? defaultBorderSide(theme) : BorderSide.none,
        ),
        color: titleSolidBackgroundColor(theme),
      ),
      padding: EdgeInsets.only(left: defaultSpacing, right: rightPadding),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.subtitle2,
            ),
          ),
          ...actions,
        ],
      ),
    ),
  );
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
          icon,
          text,
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
class ExportButton extends StatelessWidget {
  const ExportButton({
    Key key,
    @required this.includeTextWidth,
    @required this.onPressed,
  }) : super(key: key);

  final double includeTextWidth;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlineButton(
      key: key,
      onPressed: onPressed,
      child: MaterialIconLabel(
        Icons.file_download,
        'Export',
        includeTextWidth: includeTextWidth,
      ),
    );
  }
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
    final colorScheme = Theme.of(context).colorScheme;
    return RoundedOutlinedBorder(
      child: SizedBox(
        height: defaultButtonHeight,
        child: Tooltip(
          message: 'Filter',
          child: FlatButton(
            key: key,
            onPressed: onPressed,
            color: isFilterActive
                ? colorScheme.toggleButtonBackgroundColor
                : Colors.transparent,
            child: createIcon(
              Icons.filter_list,
              color: isFilterActive
                  ? colorScheme.toggleButtonForegroundColor
                  : null,
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
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).focusColor),
        borderRadius: BorderRadius.circular(borderPadding),
      ),
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
        width: 24.0,
        height: 24.0,
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

/// Utility extension methods to the [ThemeData] class.
extension ThemeDataExtension on ThemeData {
  /// Returns whether we are currently using a dark theme.
  bool get isDarkTheme => brightness == Brightness.dark;

  TextStyle get regularTextStyle => TextStyle(color: textTheme.bodyText2.color);

  TextStyle get subtleTextStyle => TextStyle(color: unselectedWidgetColor);

  TextStyle get selectedTextStyle =>
      TextStyle(color: textSelectionTheme.selectionColor);
}

/// Gets an alternating color to use for indexed UI elements.
Color alternatingColorForIndexWithContext(int index, BuildContext context) {
  final theme = Theme.of(context);
  final color = theme.canvasColor;
  return _colorForIndex(color, index, theme.colorScheme);
}

Color alternatingColorForIndex(int index, ColorScheme colorScheme) {
  final color = colorScheme.defaultBackgroundColor;
  return _colorForIndex(color, index, colorScheme);
}

Color _colorForIndex(Color color, int index, ColorScheme colorScheme) {
  if (index % 2 == 1) {
    return color;
  } else {
    return colorScheme.isLight ? color.darken() : color.brighten();
  }
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
  const FormattedJson({@required this.json});

  static const encoder = JsonEncoder.withIndent('  ');

  final Map<String, dynamic> json;

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): we could consider using a prettier format like YAML.
    final formattedArgs = encoder.convert(json);
    return Text(
      formattedArgs,
      style: fixedFontStyle(context),
    );
  }
}
