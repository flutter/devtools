// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ui/flutter/label.dart';
import 'scaffold.dart';
import 'theme.dart';

const tooltipWait = Duration(milliseconds: 500);

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

// TODO(kenz): Cleanup - audit the following methods and convert them into
// Widgets where possible.

/// Button to clear data in the UI.
///
/// * `minIncludeTextWidth`: The minimum width the button can be before the text
///    is omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
StatelessWidget clearButton({
  Key key,
  double minIncludeTextWidth,
  @required VoidCallback onPressed,
}) {
  return OutlineButton(
    key: key,
    onPressed: onPressed,
    child: MaterialIconLabel(
      Icons.block,
      'Clear',
      minIncludeTextWidth: minIncludeTextWidth,
    ),
  );
}

/// Button to start recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `minIncludeTextWidth`: The minimum width the button can be before the text
///    is omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
StatelessWidget recordButton({
  Key key,
  @required bool recording,
  double minIncludeTextWidth,
  @required VoidCallback onPressed,
}) {
  return OutlineButton(
    key: key,
    onPressed: recording ? null : onPressed,
    child: MaterialIconLabel(
      Icons.fiber_manual_record,
      'Record',
      minIncludeTextWidth: minIncludeTextWidth,
    ),
  );
}

/// Button to stop recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `minIncludeTextWidth`: The minimum width the button can be before the text
///    is omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
StatelessWidget stopRecordingButton({
  Key key,
  @required bool recording,
  double minIncludeTextWidth,
  @required VoidCallback onPressed,
}) {
  return OutlineButton(
    key: key,
    onPressed: !recording ? null : onPressed,
    child: MaterialIconLabel(
      Icons.stop,
      'Stop',
      minIncludeTextWidth: minIncludeTextWidth,
    ),
  );
}

/// Button to pause recording data.
///
/// * `recording`: Whether recording is in progress.
/// * `minIncludeTextWidth`: The minimum width the button can be before the text
///    is omitted.
/// * `onPressed`: The callback to be called upon pressing the button.
StatelessWidget pauseButton({
  Key key,
  @required bool paused,
  double minIncludeTextWidth,
  @required VoidCallback onPressed,
}) {
  return OutlineButton(
    key: key,
    onPressed: paused ? null : onPressed,
    child: MaterialIconLabel(
      Icons.pause,
      'Pause',
      minIncludeTextWidth: minIncludeTextWidth,
    ),
  );
}

// TODO(kenz): make recording info its own stateful widget that handles
// listening to value notifiers and building info.
Widget recordingInfo({
  Key instructionsKey,
  Key recordingStatusKey,
  Key processingStatusKey,
  @required bool recording,
  @required String recordedObject,
  @required bool processing,
  double progressValue,
  bool isPause = false,
}) {
  Widget child;
  if (processing) {
    child = processingInfo(
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

Widget _recordingInstructions({Key key, String recordedObject, bool isPause}) {
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

Widget processingInfo({
  Key key,
  @required double progressValue,
  @required String processedObject,
}) {
  return Center(
    child: Column(
      key: key,
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

/// Common button for exiting offline mode.
///
/// Consumers of this widget will be responsible for including the following in
/// onPressed:
///
/// setState(() {
///   offlineMode = false;
/// }
Widget exitOfflineButton(FutureOr<void> Function() onPressed) {
  return OutlineButton(
    key: const Key('exit offline button'),
    onPressed: onPressed,
    child: MaterialIconLabel(
      Icons.clear,
      'Exit offline mode',
    ),
  );
}

/// Display a single bullet character in order to act as a stylized spacer
/// component.
class BulletSpacer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).primaryTextTheme.bodyText1;
    final mutedColor = textStyle.color.withAlpha(0xB2); // 70% alpha

    return Container(
      width: DevToolsScaffold.actionWidgetSize / 2,
      height: DevToolsScaffold.actionWidgetSize,
      alignment: Alignment.center,
      child: Text(
        '•',
        style: textStyle.copyWith(color: mutedColor),
      ),
    );
  }
}

/// Toggle button for use as a child of a [ToggleButtons] widget.
class ToggleButton extends StatelessWidget {
  const ToggleButton({
    @required this.icon,
    @required this.text,
    @required this.enabledTooltip,
    @required this.disabledTooltip,
    @required this.minIncludeTextWidth,
    @required this.selected,
  });

  final IconData icon;
  final String text;
  final String enabledTooltip;
  final String disabledTooltip;
  final double minIncludeTextWidth;
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
          minIncludeTextWidth: minIncludeTextWidth,
        ),
      ),
    );
  }
}

class OutlinedBorder extends StatelessWidget {
  const OutlinedBorder({Key key, this.child}) : super(key: key);
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

/// The golden ratio.
///
/// Makes for nice-looking rectangles.
final goldenRatio = 1 + sqrt(5) / 2;
