/*
 * Copyright 2020 The Chromium Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../auto_dispose_mixin.dart';
import '../theme.dart';

/// Stateful Checkbox Widget class using a [ValueNotifier].
///
/// Used to create a Checkbox widget who's boolean value is attached
/// to a [ValueNotifier<bool>].  This allows for the pattern:
///
/// Create the [NotifierCheckbox] widget in build e.g.,
///
///   myCheckboxWidget = NotifierCheckbox(notifier: controller.myCheckbox);
///
/// The checkbox and the value notifier are now linked with clicks updating the
/// [ValueNotifier] and changes to the [ValueNotifier] updating the checkbox.
class NotifierCheckbox extends StatefulWidget {
  const NotifierCheckbox({
    Key key,
    @required this.notifier,
  }) : super(key: key);

  final ValueNotifier<bool> notifier;

  @override
  _NotifierCheckboxState createState() => _NotifierCheckboxState();
}

class _NotifierCheckboxState extends State<NotifierCheckbox>
    with AutoDisposeMixin {
  bool currentValue;

  @override
  void initState() {
    super.initState();
    _trackValue();
  }

  @override
  void didUpdateWidget(NotifierCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.notifier == widget.notifier) return;

    cancel();
    _trackValue();
  }

  void _trackValue() {
    _updateValue();
    addAutoDisposeListener(widget.notifier, _updateValue);
  }

  void _updateValue() {
    if (currentValue == widget.notifier.value) return;
    setState(() {
      currentValue = widget.notifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: currentValue,
      onChanged: (value) {
        widget.notifier.value = value;
      },
    );
  }
}

/// Returns a [TextSpan] that only includes the first [length] characters of
/// [span].
TextSpan truncateTextSpan(TextSpan span, int length) {
  int available = length;
  TextSpan truncateHelper(TextSpan span) {
    var text = span.text;
    List<TextSpan> children;
    if (text != null) {
      if (text.length > available) {
        text = text.substring(0, available);
      }
      available -= text.length;
    }
    if (span.children != null) {
      children = <TextSpan>[];
      for (var child in span.children) {
        if (available <= 0) break;
        children.add(truncateHelper(child));
      }
      if (children.isEmpty) {
        children = null;
      }
    }
    return TextSpan(
      text: text,
      children: children,
      style: span.style,
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel,
    );
  }

  return truncateHelper(span);
}

/// Returns the width in pixels of the [span].
double calculateTextSpanWidth(TextSpan span) {
  final textPainter = TextPainter(
    text: span,
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout();

  return textPainter.width;
}

/// Scrollbar that is offset by the amount specified by an [offsetController].
///
/// This makes it possible to create a [ListView] with both vertical and
/// horizontal scrollbars by wrapping the [ListView] in a
/// [SingleChildScrollView] that handles horizontal scrolling. The
/// [offsetController] is the offset of the parent [SingleChildScrollView] in
/// this example.
///
/// This class could be optimized if performance was a concern using a
/// [CustomPainter] instead of an [AnimatedBuilder] so that the
/// [OffsetScrollbar] widget does not need to build on each change to the
/// [offsetController].
class OffsetScrollbar extends StatefulWidget {
  const OffsetScrollbar({
    Key key,
    this.isAlwaysShown = false,
    @required this.axis,
    @required this.controller,
    @required this.offsetController,
    @required this.child,
    @required this.offsetControllerViewportDimension,
  }) : super(key: key);

  final bool isAlwaysShown;
  final Axis axis;
  final ScrollController controller;
  final ScrollController offsetController;
  final Widget child;

  /// The current viewport dimension of the offsetController may not be
  /// available at build time as it is not updated until later so we require
  /// that the known correct viewport dimension is passed into this class.
  ///
  /// This is a workaround because we use an AnimatedBuilder to listen for
  /// changes to the offsetController rather than displaying the scrollbar at
  /// paint time which would be more difficult.
  final double offsetControllerViewportDimension;

  @override
  _OffsetScrollbarState createState() => _OffsetScrollbarState();
}

class _OffsetScrollbarState extends State<OffsetScrollbar> {
  @override
  Widget build(BuildContext context) {
    if (!widget.offsetController.position.hasContentDimensions) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        if (widget.offsetController.position.hasViewportDimension && mounted) {
          // TODO(jacobr): find a cleaner way to be notified that the
          // offsetController now has a valid dimension. We would probably
          // have to implement our own ScrollbarPainter instead of being able
          // to use the existing Scrollbar widget.
          setState(() {});
        }
      });
    }
    return AnimatedBuilder(
      animation: widget.offsetController,
      builder: (context, child) {
        // Compute a delta to move the scrollbar from where it is by default to
        // where it should be given the viewport dimension of the
        // offsetController not the viewport that is the entire scroll extent
        // of the offsetController because this controller is nested within the
        // offset controller.
        double delta = 0.0;
        if (widget.offsetController.position.hasContentDimensions) {
          delta = widget.offsetController.offset -
              widget.offsetController.position.maxScrollExtent +
              widget.offsetController.position.minScrollExtent;
          if (widget.offsetController.position.hasViewportDimension) {
            // TODO(jacobr): this is a bit of a hack.
            // The viewport dimension from the offsetController may be one frame
            // behind the true viewport dimension. We add this delta so the
            // scrollbar always appears stuck to the side of the viewport.
            delta += widget.offsetControllerViewportDimension -
                widget.offsetController.position.viewportDimension;
          }
        }
        final offset = widget.axis == Axis.vertical
            ? Offset(delta, 0.0)
            : Offset(0.0, delta);
        return Transform.translate(
          offset: offset,
          child: Scrollbar(
            isAlwaysShown: widget.isAlwaysShown,
            controller: widget.controller,
            child: Transform.translate(
              offset: -offset,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class ColorPair {
  const ColorPair({@required this.background, @required this.foreground});

  final Color foreground;

  final Color background;
}

class ThemedColorPair {
  const ThemedColorPair({@required this.background, @required this.foreground});

  factory ThemedColorPair.from(ColorPair colorPair) {
    return ThemedColorPair(
      foreground: ThemedColor.fromSingle(colorPair.foreground),
      background: ThemedColor.fromSingle(colorPair.background),
    );
  }

  final ThemedColor foreground;

  final ThemedColor background;
}

/// A theme-dependent color.
///
/// When possible, themed colors should be specified in an extension on
/// [ColorScheme] using the [ColorScheme.isLight] getter. However, this class
/// may be used when access to the [BuildContext] is not available at the time
/// the color needs to be specified.
class ThemedColor {
  const ThemedColor({this.light, this.dark});

  factory ThemedColor.fromSingle(Color color) =>
      ThemedColor(light: color, dark: color);

  final Color light;

  final Color dark;

  Color colorFor(BuildContext context) {
    return Theme.of(context).colorScheme.isLight ? light : dark;
  }
}
