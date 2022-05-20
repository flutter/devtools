// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../shared/eval_on_dart_library.dart';
import '../shared/theme.dart';
import '../shared/utils.dart';
import 'utils.dart';

/// Regex for valid Dart identifiers.
final _identifier = RegExp(r'^[a-zA-Z0-9]|_|\$');

/// Returns the word in the [line] for the provided hover [dx] offset given
/// the [line]'s [textStyle].
String wordForHover(double dx, TextSpan line) {
  String word = '';
  final hoverIndex = _hoverIndexFor(dx, line);
  final lineText = line.toPlainText();
  if (hoverIndex >= 0 && hoverIndex < lineText.length) {
    final hoverChar = lineText[hoverIndex];
    word = '$word$hoverChar';
    if (_identifier.hasMatch(hoverChar) || hoverChar == '.') {
      // Merge trailing valid identifiers.
      int charIndex = hoverIndex + 1;
      while (charIndex < lineText.length) {
        final character = lineText[charIndex];
        if (_identifier.hasMatch(character)) {
          word = '$word$character';
        } else {
          break;
        }
        charIndex++;
      }

      // Merge preceding characters including those linked by a `.`.
      charIndex = hoverIndex - 1;
      while (charIndex >= 0) {
        final character = lineText[charIndex];
        if (_identifier.hasMatch(character) || character == '.') {
          word = '$character$word';
        } else {
          break;
        }
        charIndex--;
      }
    }
  }

  return word;
}

/// Returns the index in the Textspan's plainText for which the hover offset is
/// located.
int _hoverIndexFor(double dx, TextSpan line) {
  int hoverIndex = -1;
  final length = line.toPlainText().length;
  for (var i = 0; i < length; i++) {
    final painter = TextPainter(
      text: truncateTextSpan(line, i + 1),
      textDirection: TextDirection.ltr,
    )..layout();
    if (dx <= painter.width) {
      hoverIndex = i;
      break;
    }
  }
  return hoverIndex;
}

const _hoverYOffset = 10.0;

/// Minimum distance from the side of screen to show tooltip
const _hoverMargin = 16.0;

/// Defines how a [HoverCardTooltip] is positioned
enum HoverCardPosition {
  /// Aligns the tooltip below the cursor
  cursor,

  /// Aligns the tooltip to the element it's wrapped in
  element,
}

class HoverCardData {
  HoverCardData({
    this.title,
    required this.contents,
    double? width,
    this.position = HoverCardPosition.cursor,
  }) : width = width ?? HoverCardTooltip.defaultHoverWidth;

  final String? title;
  final Widget contents;
  final double width;
  final HoverCardPosition position;
}

/// A card to display content while hovering over a widget.
///
/// This widget will automatically remove itself after the mouse has entered
/// and left its region.
///
/// Note that if a mouse has never entered, it will not remove itself.
class HoverCard {
  HoverCard({
    required BuildContext context,
    required Widget contents,
    required double width,
    required Offset position,
    String? title,
    double? maxCardHeight,
  }) {
    maxCardHeight ??= maxHoverCardHeight;
    final overlayState = Overlay.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final focusColor = Theme.of(context).focusColor;
    final hoverHeading = colorScheme.hoverTitleTextStyle;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx,
          top: position.dy,
          MouseRegion(
            onExit: (_) {
              remove();
            },
            onEnter: (_) {
              _hasMouseEntered = true;
            },
            Container(
              padding: const EdgeInsets.all(denseSpacing),
              decoration: BoxDecoration(
                color: colorScheme.defaultBackgroundColor,
                border: Border.all(
                  color: focusColor,
                  width: hoverCardBorderWidth,
                ),
                borderRadius: BorderRadius.circular(defaultBorderRadius),
              ),
              width: width,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                [
                  if (title != null) ...[
                    Container(
                      width: width,
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: hoverHeading,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Divider(color: colorScheme.hoverTextStyle.color),
                  ],
                  SingleChildScrollView(
                    Container(
                      constraints: BoxConstraints(maxHeight: maxCardHeight!),
                      contents,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    overlayState.insert(_overlayEntry);
  }

  HoverCard.fromHoverEvent({
    required BuildContext context,
    required PointerHoverEvent event,
    required Widget contents,
    required double width,
    String? title,
  }) : this(
          context: context,
          contents: contents,
          width: width,
          position: Offset(
            math.max(0, event.position.dx - (width / 2.0)),
            event.position.dy + _hoverYOffset,
          ),
          title: title,
        );

  late OverlayEntry _overlayEntry;

  bool _isRemoved = false;

  bool _hasMouseEntered = false;

  /// Attempts to remove the HoverCard from the screen.
  ///
  /// The HoverCard will not be removed if the mouse is currently inside the
  /// widget.
  void maybeRemove() {
    if (!_hasMouseEntered) remove();
  }

  /// Removes the HoverCard even if the mouse is in the corresponding mouse
  /// region.
  void remove() {
    if (!_isRemoved) _overlayEntry.remove();
    _isRemoved = true;
  }
}

/// A hover card based tooltip.
class HoverCardTooltip extends StatefulWidget {
  const HoverCardTooltip({
    required this.enabled,
    required this.onHover,
    required this.child,
    this.disposable,
  });

  static const _hoverDelay = Duration(milliseconds: 500);
  static double get defaultHoverWidth => scaleByFontFactor(450.0);

  /// Whether the tooltip is currently enabled.
  final bool Function() enabled;

  /// Data to display when hovering over a particular point.
  final Future<HoverCardData> Function(PointerHoverEvent event) onHover;

  final Widget child;

  /// Disposable object to be disposed when the group is closed.
  final Disposable? disposable;

  @override
  _HoverCardTooltipState createState() => _HoverCardTooltipState();
}

class _HoverCardTooltipState extends State<HoverCardTooltip> {
  /// A timer that shows a [HoverCard] with an evaluation result when completed.
  Timer? _showTimer;

  /// A timer that removes a [HoverCard] when completed.
  Timer? _removeTimer;

  /// Displays the evaluation result of a source code item.
  HoverCard? _hoverCard;

  void _onHoverExit() {
    _showTimer?.cancel();
    _removeTimer = Timer(HoverCardTooltip._hoverDelay, () {
      _hoverCard?.maybeRemove();
    });
  }

  void _onHover(PointerHoverEvent event) {
    _showTimer?.cancel();
    _showTimer = null;
    _removeTimer?.cancel();
    _removeTimer = null;

    if (!widget.enabled()) return;
    _showTimer = Timer(HoverCardTooltip._hoverDelay, () async {
      _hoverCard?.remove();
      _hoverCard = null;
      final hoverCardData = await widget.onHover(event);
      if (!mounted) return;
      if (hoverCardData.position == HoverCardPosition.cursor) {
        _hoverCard = HoverCard.fromHoverEvent(
          context: context,
          title: hoverCardData.title,
          contents: hoverCardData.contents,
          width: hoverCardData.width,
          event: event,
        );
      } else {
        _hoverCard = HoverCard(
          context: context,
          title: hoverCardData.title,
          contents: hoverCardData.contents,
          width: hoverCardData.width,
          position: _calculateTooltipPosition(hoverCardData.width),
        );
      }
    });
  }

  Offset _calculateTooltipPosition(double width) {
    final overlayBox =
        Overlay.of(context)!.context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;

    final maxX = overlayBox.size.width - _hoverMargin - width;
    final maxY = overlayBox.size.height - _hoverMargin;

    final offset = box.localToGlobal(
      box.size.bottomCenter(Offset.zero).translate(-width / 2, _hoverYOffset),
      ancestor: overlayBox,
    );

    return Offset(
      offset.dx.clamp(_hoverMargin, maxX),
      offset.dy.clamp(_hoverMargin, maxY),
    );
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _removeTimer?.cancel();
    _hoverCard?.remove();
    widget.disposable?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (_) => _onHoverExit(),
      onHover: _onHover,
      widget.child,
    );
  }
}
