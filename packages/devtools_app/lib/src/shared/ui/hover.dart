// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common_widgets.dart';
import 'utils.dart';

double get _maxHoverCardHeight => scaleByFontFactor(250.0);

TextStyle get _hoverTitleTextStyle => fixBlurryText(
      TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: scaleByFontFactor(15.0),
        decoration: TextDecoration.none,
      ),
    );

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
    maxCardHeight ??= _maxHoverCardHeight;
    final overlayState = Overlay.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final focusColor = theme.focusColor;

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
                color: colorScheme.surface,
                border: Border.all(
                  color: focusColor,
                  width: hoverCardBorderSize,
                ),
                borderRadius: defaultBorderRadius,
              ),
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    SizedBox(
                      width: width,
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: _hoverTitleTextStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Divider(color: theme.focusColor),
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
  /// The card that is currently being displayed.
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

typedef AsyncGenerateHoverCardDataFunc = Future<HoverCardData?> Function({
  required PointerHoverEvent event,

  /// Returns true if the HoverCard is no longer visible.
  ///
  /// Use this callback to short circuit long running tasks.
  required bool Function() isHoverStale,
});

typedef SyncGenerateHoverCardDataFunc = HoverCardData Function(
  PointerHoverEvent event,
);

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
    super.key,
    required this.enabled,
    required this.asyncGenerateHoverCardData,
    required this.child,
    this.disposable,
    this.asyncTimeout,
  }) : generateHoverCardData = null;

  /// A [HoverCardTooltip] that generates it's [HoverCardData] synchronously.
  ///
  /// The [HoverCardData] generated from [generateHoverCardData] will be
  /// displayed in a [HoverCard].
  const HoverCardTooltip.sync({
    super.key,
    required this.enabled,
    required this.generateHoverCardData,
    required this.child,
    this.disposable,
  })  : asyncGenerateHoverCardData = null,
        asyncTimeout = null;

  static const _hoverDelay = Duration(milliseconds: 500);
  static double get defaultHoverWidth => scaleByFontFactor(450.0);

  /// Whether the tooltip is currently enabled.
  final bool Function() enabled;

  /// The callback that is used when the [HoverCard]'s data is only available
  /// asynchronously.
  final AsyncGenerateHoverCardDataFunc? asyncGenerateHoverCardData;

  /// The callback that is used when the [HoverCard]'s data is available
  /// synchronously.
  final SyncGenerateHoverCardDataFunc? generateHoverCardData;

  final Widget child;

  /// Disposable object to be disposed when the group is closed.
  final Disposable? disposable;

  /// If set, will only show the async hovercard after the timeout has elapsed.
  final int? asyncTimeout;

  @override
  State<HoverCardTooltip> createState() => _HoverCardTooltipState();
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
    if (!mounted) return;
    _hoverCardController.set(hoverCard: hoverCard);
    _currentHoverCard = hoverCard;
  }

  void _removeHoverCard(HoverCard hoverCard) {
    _hoverCardController.removeHoverCard(hoverCard);
  }

  void _onHover(PointerHoverEvent event) {
    _showTimer?.cancel();
    _showTimer = null;
    _removeTimer?.cancel();
    _removeTimer = null;

    if (!widget.enabled()) return;
    final asyncGenerateHoverCardData = widget.asyncGenerateHoverCardData;
    final generateHoverCardData = widget.generateHoverCardData;
    final asyncTimeout = widget.asyncTimeout;

    _showTimer = Timer(HoverCardTooltip._hoverDelay, () {
      if (asyncGenerateHoverCardData != null) {
        assert(generateHoverCardData == null);
        _showAsyncHoverCard(
          asyncGenerateHoverCardData: asyncGenerateHoverCardData,
          event: event,
          asyncTimeout: asyncTimeout,
        );
      } else {
        _setHoverCardFromData(
          generateHoverCardData!(event),
          context: context,
          event: event,
        );
      }
    });
  }

  void _showAsyncHoverCard({
    required AsyncGenerateHoverCardDataFunc asyncGenerateHoverCardData,
    required PointerHoverEvent event,
    int? asyncTimeout,
  }) async {
    HoverCard? spinnerHoverCard;
    final hoverCardDataFuture = asyncGenerateHoverCardData(
      event: event,
      isHoverStale: () =>
          spinnerHoverCard != null &&
          !_hoverCardController.isHoverCardStillActive(spinnerHoverCard),
    );
    final hoverCardDataCompleter = _hoverCardDataCompleter(hoverCardDataFuture);
    // If we have set the async hover card to show up only after a timeout,
    // then race the timeout against generating the hover card data. If
    // generating the data completes first, immediately show the hover card
    // (or return early if there is no data).
    if (asyncTimeout != null) {
      await Future.any([
        _timeoutCompleter(asyncTimeout).future,
        hoverCardDataCompleter.future,
      ]);

      if (hoverCardDataCompleter.isCompleted) {
        final data = await hoverCardDataCompleter.future;
        // If we get no data back, then don't show a hover card.
        if (data == null) return;
        // Otherwise, show a hover card immediately.
        // ignore: use_build_context_synchronously, requires investigation
        return _setHoverCardFromData(
          data,
          // ignore: use_build_context_synchronously, requires investigation
          context: context,
          event: event,
        );
      }
    }
    // The data on the card is fetched asynchronously, so show a spinner
    // while we wait for it.
    // ignore: use_build_context_synchronously, requires investigation
    spinnerHoverCard = HoverCard.fromHoverEvent(
      // ignore: use_build_context_synchronously, requires investigation
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
    final hoverCardData = await hoverCardDataCompleter.future;

    if (!_hoverCardController.isHoverCardStillActive(spinnerHoverCard)) {
      // The hovercard became stale while fetching it's data. So it should
      // no longer be shown.
      return;
    }
    if (hoverCardData == null) {
      // No data was provided so remove the spinner
      _removeHoverCard(spinnerHoverCard);
      return;
    }

    // ignore: use_build_context_synchronously, requires investigation
    return _setHoverCardFromData(
      hoverCardData,
      // ignore: use_build_context_synchronously, requires investigation
      context: context,
      event: event,
    );
  }

  void _setHoverCardFromData(
    HoverCardData hoverCardData, {
    required BuildContext context,
    required PointerHoverEvent event,
  }) {
    if (hoverCardData.position == HoverCardPosition.cursor) {
      return _setHoverCard(
        HoverCard.fromHoverEvent(
          context: context,
          title: hoverCardData.title,
          contents: hoverCardData.contents,
          width: hoverCardData.width,
          event: event,
          hoverCardController: _hoverCardController,
        ),
      );
    }
    return _setHoverCard(
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

  Completer _timeoutCompleter(int timeout) {
    final completer = Completer();
    Timer(Duration(milliseconds: timeout), () {
      completer.complete();
    });
    return completer;
  }

  Completer<HoverCardData?> _hoverCardDataCompleter(
    Future<HoverCardData?> hoverCardDataFuture,
  ) {
    final completer = Completer<HoverCardData?>();
    unawaited(
      hoverCardDataFuture.then(
        (data) => completer.complete(data),
        onError: (_) => completer.complete(null),
      ),
    );
    return completer;
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
