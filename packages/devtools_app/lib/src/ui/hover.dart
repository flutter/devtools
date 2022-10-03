// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../shared/common_widgets.dart';
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
    required HoverCardController hoverCardController,
    String? title,
    double? maxCardHeight,
  }) {
    maxCardHeight ??= maxHoverCardHeight;
    final overlayState = Overlay.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final focusColor = Theme.of(context).focusColor;
    final hoverHeading = colorScheme.hoverTitleTextStyle;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx,
          top: position.dy,
          child: MouseRegion(
            onExit: (_) {
              hoverCardController.removeHoverCard(this);
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
                  width: hoverCardBorderWidth,
                ),
                borderRadius: BorderRadius.circular(defaultBorderRadius),
              ),
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Container(
                      width: width,
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: hoverHeading,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Divider(color: colorScheme.hoverTextStyle.color),
                  ],
                  SingleChildScrollView(
                    child: Container(
                      constraints: BoxConstraints(maxHeight: maxCardHeight!),
                      child: contents,
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
    required HoverCardController hoverCardController,
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
          hoverCardController: hoverCardController,
        );

  late OverlayEntry _overlayEntry;

  bool _isRemoved = false;

  bool _hasMouseEntered = false;

  /// Attempts to remove the HoverCard from the screen.
  ///
  /// The HoverCard will not be removed if the mouse is currently inside the
  /// widget.
  /// Returns whether or not the HoverCard was removed.
  bool maybeRemove() {
    if (!_hasMouseEntered) {
      remove();
      return true;
    }
    return false;
  }

  /// Removes the HoverCard even if the mouse is in the corresponding mouse
  /// region.
  void remove() {
    if (!_isRemoved) _overlayEntry.remove();
    _isRemoved = true;
  }
}

/// Ensures that only one [HoverCard] is ever displayed at a time.
class HoverCardController {
  /// The card that is currenty being displayed.
  HoverCard? _currentHoverCard;

  /// Sets [hoverCard] as the most recently displayed [HoverCard].
  ///
  /// [hoverCard] is the most recently displayed [HoverCard].
  void set({required HoverCard hoverCard}) {
    _currentHoverCard?.remove();
    _currentHoverCard = hoverCard;
  }

  /// If the mouse is outside of [_currentHoverCard] then then it will be removed.
  void maybeRemoveHoverCard(HoverCard hoverCard) {
    if (isHoverCardStillActive(hoverCard)) {
      final wasRemoved = _currentHoverCard?.maybeRemove();
      if (wasRemoved == true) {
        _currentHoverCard = null;
      }
    }
  }

  /// Remove [hoverCard] if it is currently active.
  void removeHoverCard(HoverCard hoverCard) {
    if (isHoverCardStillActive(hoverCard)) {
      _currentHoverCard?.remove();
      _currentHoverCard = null;
    }
  }

  /// Checks if the [hoverCard] is still the active [HoverCard].
  bool isHoverCardStillActive(HoverCard hoverCard) {
    return _currentHoverCard == hoverCard;
  }
}

/// A hover card based tooltip.
class HoverCardTooltip extends StatefulWidget {
  /// A [HoverCardTooltip] that generates it's [HoverCardData] asynchronously.
  ///
  /// [asyncGenerateHoverCardData] is used to generate the data that will
  /// display in the final [HoverCard]. While that data is being generated,
  /// a [HoverCard] with a spinner will show. If any [HoverCardData] returned
  /// from [asyncGenerateHoverCardData] the spinner [HoverCard] will be replaced
  /// with one containing the generated [HoverCardData].
  const HoverCardTooltip.async({
    required this.enabled,
    required this.asyncGenerateHoverCardData,
    required this.child,
    this.disposable,
  }) : generateHoverCardData = null;

  /// A [HoverCardTooltip] that generates it's [HoverCardData] synchronously.
  ///
  /// The [HoverCardData] generated from [generateHoverCardData] will be
  /// displayed in a [HoverCard].
  const HoverCardTooltip.sync({
    required this.enabled,
    required this.generateHoverCardData,
    required this.child,
    this.disposable,
  }) : asyncGenerateHoverCardData = null;

  static const _hoverDelay = Duration(milliseconds: 500);
  static double get defaultHoverWidth => scaleByFontFactor(450.0);

  /// Whether the tooltip is currently enabled.
  final bool Function() enabled;

  /// The callback that is used when the [HoverCard]'s data is only available
  /// asynchronously.
  final Future<HoverCardData?> Function({
    required PointerHoverEvent event,

    /// Returns true if the HoverCard is no longer visible.
    ///
    /// Use this callback to short circuit long running tasks.
    required bool Function() isHoverStale,
  })? asyncGenerateHoverCardData;

  /// The callback that is used when the [HoverCard]'s data is available
  /// synchronously.
  final HoverCardData Function(
    PointerHoverEvent event,
  )? generateHoverCardData;

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

  HoverCard? _currentHoverCard;

  late HoverCardController _hoverCardController;

  void _onHoverExit() {
    _showTimer?.cancel();
    _removeTimer = Timer(HoverCardTooltip._hoverDelay, () {
      if (_currentHoverCard != null) {
        _hoverCardController.maybeRemoveHoverCard(_currentHoverCard!);
      }
    });
  }

  void _setHoverCard(HoverCard hoverCard) {
    _hoverCardController.set(hoverCard: hoverCard);
    _currentHoverCard = hoverCard;
  }

  void _onHover(PointerHoverEvent event) {
    _showTimer?.cancel();
    _showTimer = null;
    _removeTimer?.cancel();
    _removeTimer = null;

    if (!widget.enabled()) return;
    _showTimer = Timer(HoverCardTooltip._hoverDelay, () async {
      HoverCardData? hoverCardData;

      if (widget.asyncGenerateHoverCardData != null) {
        assert(widget.generateHoverCardData == null);
        // The data on the card is fetched asynchronously, so show a spinner
        // while we wait for it.
        final spinnerHoverCard = HoverCard.fromHoverEvent(
          context: context,
          contents: const CenteredCircularProgressIndicator(),
          width: HoverCardTooltip.defaultHoverWidth,
          event: event,
          hoverCardController: _hoverCardController,
        );

        _setHoverCard(
          spinnerHoverCard,
        );

        // The spinner is showing, we can now generate the HoverCardData
        hoverCardData = await widget.asyncGenerateHoverCardData!(
          event: event,
          isHoverStale: () =>
              !_hoverCardController.isHoverCardStillActive(spinnerHoverCard),
        );

        if (!_hoverCardController.isHoverCardStillActive(spinnerHoverCard)) {
          // The hovercard became stale while fetching it's data. So it should
          // no longer be shown.
          return;
        }
      } else {
        assert(widget.generateHoverCardData != null);

        hoverCardData = widget.generateHoverCardData!(event);
      }

      if (hoverCardData != null) {
        if (!mounted) return;

        if (hoverCardData.position == HoverCardPosition.cursor) {
          _setHoverCard(
            HoverCard.fromHoverEvent(
              context: context,
              title: hoverCardData.title,
              contents: hoverCardData.contents,
              width: hoverCardData.width,
              event: event,
              hoverCardController: _hoverCardController,
            ),
          );
        } else {
          _setHoverCard(
            HoverCard(
              context: context,
              title: hoverCardData.title,
              contents: hoverCardData.contents,
              width: hoverCardData.width,
              position: _calculateTooltipPosition(hoverCardData.width),
              hoverCardController: _hoverCardController,
            ),
          );
        }
      }
    });
  }

  Offset _calculateTooltipPosition(double width) {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
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
    if (_currentHoverCard != null) {
      // If the widget that triggered the hovercard is disposed, then the
      // HoverCard should be removed from the screen
      _hoverCardController.removeHoverCard(_currentHoverCard!);
    }
    widget.disposable?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hoverCardController = Provider.of<HoverCardController>(context);
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
