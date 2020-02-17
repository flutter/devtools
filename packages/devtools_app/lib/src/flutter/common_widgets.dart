// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ui/flutter/label.dart';
import 'flutter_widgets/tagged_text.dart';

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

/// A [TaggedText] with builtin DevTools-specific text styling.
///
/// This widget is a wrapper around Flutter's [RichText]. It's an alternative
/// to that for richly-formatted text. The performance is roughly the same,
/// and it will throw assertion errors in any cases where the text isn't
/// parsed properly.
///
/// The xml styling is much easier to read than creating multiple [TextSpan]s
/// in a [RichText].  For example, the following are equivalent text
/// presentations:
///
/// ```dart
/// var taggedText = DefaultTaggedText(
///   '<bold>bold text</bold>\n'
///   'normal text',
/// );
///
/// var richText = RichText(
///   style
///   text: TextSpan(
///     text: '',
///     style: DefaultTextStyle.of(context)
///     children: [
///       TextSpan(
///         text: 'bold text',
///         style: DefaultTextStyle.of(context).copyWith(fontWeight: FontWeight.w600),
///       ),
///       TextSpan(
///         text: '\nnormal text',
///       )
///     ],
///   ),
/// );
/// ```
///
/// The [TaggedText] abstraction separates the styling from the content
/// of the rich strings we show in the UI.
///
/// The [TaggedText] also has the benefit of being localizable by a
/// human translator. The content is passed in to Flutter as a single
/// string, and the xml markup is understood by many translators.
class DefaultTaggedText extends StatelessWidget {
  const DefaultTaggedText(
    this.content, {
    this.textAlign = TextAlign.start,
    Key key,
  }) : super(key: key);

  /// The XML-markup string to show.
  final String content;

  /// See [TaggedText.textAlign].
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final _tagToTextSpanBuilder = {
      'bold': (text) => TextSpan(
            text: text,
            style: semibold(defaultTextStyle),
          ),
      'primary-color': (text) =>
          TextSpan(text: text, style: primaryColor(defaultTextStyle, context)),
      'primary-color-light': (text) => TextSpan(
          text: text, style: primaryColorLight(defaultTextStyle, context)),
    };
    return TaggedText(
      content: content,
      tagToTextSpanBuilder: _tagToTextSpanBuilder,
      overflow: TextOverflow.visible,
      textAlign: textAlign,
      style: defaultTextStyle,
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
      const SizedBox(height: 16.0),
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
        const SizedBox(height: 16.0),
        SizedBox(
          width: 200.0,
          height: 16.0,
          child: LinearProgressIndicator(
            value: progressValue,
          ),
        ),
      ],
    ),
  );
}

/// The golden ratio.
///
/// Makes for nice-looking rectangles.
final goldenRatio = 1 + sqrt(5) / 2;
