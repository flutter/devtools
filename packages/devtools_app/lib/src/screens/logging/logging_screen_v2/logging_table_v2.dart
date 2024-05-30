// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logging_model.dart';
import 'logging_table_row.dart';

/// A builder that includes an Offset to draw the context menu at.
typedef ContextMenuBuilder = Widget Function(
  BuildContext context,
  Offset offset,
);

class LoggingTableV2 extends StatefulWidget {
  /// Creates a screen that demonstrates the TableView widget.
  const LoggingTableV2({super.key, required this.model});

  final LoggingTableModel model;

  @override
  State<LoggingTableV2> createState() => _LoggingTableV2State();
}

class _LoggingTableV2State extends State<LoggingTableV2> {
  late final ScrollController _verticalController = ScrollController();
  final Set<int> selections = <int>{};
  final Map<int, double> cachedOffets = {};
  final normalTextStyle = const TextStyle(color: Colors.black, fontSize: 14.0);
  String lastSearch = '';
  final metadataTextStyle = const TextStyle(
    color: Colors.black,
    fontStyle: FontStyle.italic,
    fontSize: 12.0,
  );
  double maxWidth = 0.0;

  @override
  void initState() {
    super.initState();
    // On web, disable the browser's context menu since this example uses a custom
    // Flutter-rendered context menu.
    if (kIsWeb) {
      unawaited(BrowserContextMenu.disableContextMenu());
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      unawaited(BrowserContextMenu.enableContextMenu());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Filter',
                ),
                onSubmitted: (value) {},
              ),
            ),
            const Expanded(
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Search',
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: _LoggingTableContextMenu(
            child: _LoggingTableContents(
              model: widget.model,
              verticalController: _verticalController,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoggingTableContents extends StatefulWidget {
  _LoggingTableContents({
    required this.model,
    required ScrollController verticalController,
  }) : _verticalController = verticalController;

  static const _millisecondsUntilCacheProgressShows = 500;
  static const _millisecondsUntilCacheProgressHelperShows = 2000;

  final LoggingTableModel model;
  final ScrollController _verticalController;

  @override
  State<_LoggingTableContents> createState() => _LoggingTableContentsState();
}

class _LoggingTableContentsState extends State<_LoggingTableContents> {
  final Stopwatch _progressStopwatch = Stopwatch();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.model.tableWidth = constraints.maxWidth;
        _progressStopwatch.reset();
        return ListenableBuilder(
          listenable: widget.model.cacheLoadProgress,
          builder: (context, _) {
            final cacheLoadProgress = widget.model.cacheLoadProgress.value;
            if (cacheLoadProgress != null) {
              double progress = cacheLoadProgress;
              if (!_progressStopwatch.isRunning) {
                _progressStopwatch.start();
              }

              if (_progressStopwatch.elapsedMilliseconds <
                  _LoggingTableContents._millisecondsUntilCacheProgressShows) {
                progress = 0.0;
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Resizing... this will only take a moment.',
                    ),
                    const SizedBox(height: defaultSpacing),
                    SizedBox(
                      width: defaultLinearProgressIndicatorWidth,
                      height: defaultLinearProgressIndicatorHeight,
                      child: LinearProgressIndicator(
                        value: progress,
                      ),
                    ),
                    const SizedBox(height: defaultSpacing),
                    if (_progressStopwatch.elapsedMilliseconds >
                        _LoggingTableContents
                            ._millisecondsUntilCacheProgressHelperShows)
                      const Text(
                        'To make this process faster, then reduce the "Log Retention" setting.',
                      ),
                  ],
                ),
              );
            } else {
              _progressStopwatch.stop();
              _progressStopwatch.reset();
              return Scrollbar(
                thumbVisibility: true,
                controller: widget._verticalController,
                child: ListenableBuilder(
                  listenable: widget.model,
                  builder: (context, _) {
                    return CustomScrollView(
                      controller: widget._verticalController,
                      slivers: <Widget>[
                        SliverVariedExtentList.builder(
                          itemCount: widget.model.logCount,
                          itemBuilder: (context, index) {
                            return LoggingTableRow(
                              index: index,
                              data: widget.model.getFilteredLog(index),
                              isSelected: false,
                            );
                          },
                          itemExtentBuilder: (index, _) =>
                              widget.model.getFilteredLogHeight(index),
                        ),
                      ],
                    );
                  },
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _progressStopwatch.stop();
  }
}

class _LoggingTableContextMenu extends StatelessWidget {
  const _LoggingTableContextMenu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _ContextMenuRegion(
      contextMenuBuilder: (context, offset) {
        // The custom context menu will look like the default context menu
        // on the current platform with a single 'Print' button.
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(
            primaryAnchor: offset,
          ),
          buttonItems: <ContextMenuButtonItem>[
            ContextMenuButtonItem(
              onPressed: () {
                ContextMenuController.removeAny();
                _showDialog(context, 'You copied selected rows');
              },
              label: 'Copy Selected Rows',
            ),
            ContextMenuButtonItem(
              onPressed: () {
                ContextMenuController.removeAny();
                _showDialog(
                  context,
                  'You copied selected rows with metadata',
                );
              },
              label: 'Copy Selected Rows with Metadata',
            ),
            ContextMenuButtonItem(
              onPressed: () {
                ContextMenuController.removeAny();
                _showDialog(
                  context,
                  'Hiding items with the same address',
                );
              },
              label: 'Hide items with same Address',
            ),
            ContextMenuButtonItem(
              onPressed: () {
                ContextMenuController.removeAny();
                _showDialog(
                  context,
                  'Showing items with the same address',
                );
              },
              label: 'Show items with same Address',
            ),
          ],
        );
      },
      child: child,
    );
  }

  void _showDialog(BuildContext context, String message) {
    unawaited(
      Navigator.of(context).push(
        DialogRoute<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(title: Text(message)),
        ),
      ),
    );
  }
}

/// Shows and hides the context menu based on user gestures.
///
/// By default, shows the menu on right clicks and long presses.
class _ContextMenuRegion extends StatefulWidget {
  /// Creates an instance of [_ContextMenuRegion].
  const _ContextMenuRegion({
    required this.child,
    required this.contextMenuBuilder,
  });

  /// Builds the context menu.
  final ContextMenuBuilder contextMenuBuilder;

  /// The child widget that will be listened to for gestures.
  final Widget child;

  @override
  State<_ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<_ContextMenuRegion> {
  Offset? _longPressOffset;

  final ContextMenuController _contextMenuController = ContextMenuController();

  static bool get _longPressEnabled {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  void _onSecondaryTapUp(TapUpDetails details) {
    _show(details.globalPosition);
  }

  void _onTap() {
    if (!_contextMenuController.isShown) {
      return;
    }
    _hide();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _longPressOffset = details.globalPosition;
  }

  void _onLongPress() {
    assert(_longPressOffset != null);
    _show(_longPressOffset!);
    _longPressOffset = null;
  }

  void _show(Offset position) {
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        return widget.contextMenuBuilder(context, position);
      },
    );
  }

  void _hide() {
    _contextMenuController.remove();
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: _onSecondaryTapUp,
      onTap: _onTap,
      onLongPress: _longPressEnabled ? _onLongPress : null,
      onLongPressStart: _longPressEnabled ? _onLongPressStart : null,
      child: widget.child,
    );
  }
}
