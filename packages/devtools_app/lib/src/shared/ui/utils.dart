// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../primitives/enum_utils.dart';
import '../primitives/utils.dart';
import '../table/table.dart';

/// Returns a [TextSpan] that only includes the first [length] characters of
/// [span].
TextSpan truncateTextSpan(TextSpan span, int length) {
  int available = length;
  TextSpan truncateHelper(TextSpan span) {
    var text = span.text;
    List<TextSpan>? children;
    if (text != null) {
      if (text.length > available) {
        text = text.substring(0, available);
      }
      available -= text.length;
    }
    if (span.children != null) {
      children = <TextSpan>[];
      for (var child in span.children!) {
        if (available <= 0) break;
        children.add(truncateHelper(child as TextSpan));
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
double calculateTextSpanWidth(TextSpan? span) {
  final textPainter = TextPainter(
    text: span,
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout();

  return textPainter.width;
}

/// Returns the height in pixels of the [span].
double calculateTextSpanHeight(TextSpan span) {
  final textPainter = TextPainter(
    text: span,
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout();

  return textPainter.height;
}

TextSpan? findLongestTextSpan(List<TextSpan> spans) {
  int longestLength = 0;
  TextSpan? longestSpan;
  for (final span in spans) {
    final int currentLength = span.toPlainText().length;
    if (currentLength > longestLength) {
      longestLength = currentLength;
      longestSpan = span;
    }
  }
  return longestSpan;
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
    Key? key,
    this.isAlwaysShown = false,
    required this.axis,
    required this.controller,
    required this.offsetController,
    required this.child,
    required this.offsetControllerViewportDimension,
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
  State<OffsetScrollbar> createState() => _OffsetScrollbarState();
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
            thumbVisibility: widget.isAlwaysShown,
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

/// Scrolls to [position] if [position] is not already visible in the scroll view.
void maybeScrollToPosition(
  ScrollController scrollController,
  double position,
) {
  final extentVisible = Range(
    scrollController.offset,
    scrollController.offset + scrollController.position.extentInside,
  );

  if (!extentVisible.contains(position)) {
    final positionToScrollTo = max(0.0, position - defaultRowHeight);

    unawaited(
      scrollController.animateTo(
        //TODO (carolynqu): should be positionToScrollTo.clamp(0.0, scrollController.position.maxScrollExtent) but maxScrollExtent is not being updated, https://github.com/flutter/devtools/issues/4264
        positionToScrollTo,
        duration: defaultDuration,
        curve: defaultCurve,
      ),
    );
  }
}

class ColorPair {
  const ColorPair({required this.background, required this.foreground});

  final Color foreground;

  final Color background;
}

class ThemedColorPair {
  const ThemedColorPair({required this.background, required this.foreground});

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
  const ThemedColor({required this.light, required this.dark});

  const ThemedColor.fromSingle(Color color)
      : light = color,
        dark = color;

  final Color light;

  final Color dark;

  Color colorFor(ColorScheme colorScheme) {
    return colorScheme.isLight ? light : dark;
  }
}

enum MediaSize with EnumIndexOrdering {
  xxs,
  xs,
  s,
  m,
  l,
  xl,
}

class ScreenSize {
  ScreenSize(BuildContext context) {
    _height = _calculateHeight(context);
    _width = _calculateWidth(context);
  }

  MediaSize get height => _height;
  MediaSize get width => _width;
  late MediaSize _height;
  late MediaSize _width;

  MediaSize _calculateWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 300) return MediaSize.xxs;
    if (width < 600) return MediaSize.xs;
    if (width < 900) return MediaSize.s;
    if (width < 1200) return MediaSize.m;
    if (width < 1500) return MediaSize.l;
    return MediaSize.xl;
  }

  MediaSize _calculateHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 300) return MediaSize.xxs;
    if (height < 450) return MediaSize.xs;
    if (height < 600) return MediaSize.s;
    if (height < 750) return MediaSize.m;
    if (height < 900) return MediaSize.l;
    return MediaSize.xl;
  }
}
