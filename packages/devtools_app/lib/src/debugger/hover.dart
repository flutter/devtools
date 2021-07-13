// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../eval_on_dart_library.dart';
import '../theme.dart';
import '../ui/utils.dart';

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

const _hoverCardBorderWidth = 2.0;
const _hoverYOffset = 10;

class HoverCardData {
  HoverCardData({
    @required this.title,
    @required this.contents,
    this.width = HoverCardTooltip.defaultHoverWidth,
  });

  final String title;
  final Widget contents;
  final double width;
}

/// A card to display content while hovering over a widget.
///
/// This widget will automatically remove itself after the mouse has entered
/// and left its region.
///
/// Note that if a mouse has never entered, it will not remove itself.
class HoverCard {
  HoverCard({
    @required BuildContext context,
    @required PointerHoverEvent event,
    @required String title,
    @required Widget contents,
    @required double width,
  }) {
    final overlayState = Overlay.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final focusColor = Theme.of(context).focusColor;
    final hoverHeading = colorScheme.hoverTitleTextStyle;
    final position = event.position;

    _overlayEntry = OverlayEntry(builder: (context) {
      return Positioned(
        left: math.max(0, position.dx - (width / 2.0)),
        top: position.dy + _hoverYOffset,
        child: MouseRegion(
          onExit: (_) {
            remove();
          },
          onEnter: (_) {
            _hasMouseEntered = true;
          },
          child: Container(
            padding: const EdgeInsets.all(denseSpacing),
            decoration: BoxDecoration(
              color: colorScheme.defaultBackgroundColor,
              border: Border.all(
                color: focusColor,
                width: _hoverCardBorderWidth,
              ),
              borderRadius: BorderRadius.circular(defaultBorderRadius),
            ),
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: width,
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: hoverHeading,
                    textAlign: TextAlign.center,
                  ),
                ),
                Divider(color: colorScheme.hoverTextStyle.color),
                contents,
              ],
            ),
          ),
        ),
      );
    });
    overlayState.insert(_overlayEntry);
  }

  OverlayEntry _overlayEntry;

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
    @required this.enabled,
    @required this.onHover,
    @required this.child,
    this.disposable,
  });

  static const _hoverDelay = Duration(milliseconds: 500);
  static const defaultHoverWidth = 450.0;

  /// Whether the tooltip is currently enabled.
  final bool Function() enabled;

  /// Data to display when hovering over a particular point.
  final Future<HoverCardData> Function(PointerHoverEvent event) onHover;

  final Widget child;

  /// Disposable object to be disposed when the group is closed.
  final Disposable disposable;

  @override
  _HoverCardTooltipState createState() => _HoverCardTooltipState();
}

class _HoverCardTooltipState extends State<HoverCardTooltip> {
  /// A timer that shows a [HoverCard] with an evaluation result when completed.
  Timer _showTimer;

  /// A timer that removes a [HoverCard] when completed.
  Timer _removeTimer;

  /// Displays the evaluation result of a source code item.
  HoverCard _hoverCard;

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
      if (hoverCardData != null) {
        _hoverCard = HoverCard(
          context: context,
          event: event,
          title: hoverCardData.title,
          contents: hoverCardData.contents,
          width: hoverCardData.width,
        );
      }
    });
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
      child: widget.child,
    );
  }
}
