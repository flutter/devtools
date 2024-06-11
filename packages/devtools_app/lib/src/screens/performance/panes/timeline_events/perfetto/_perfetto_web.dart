// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_app_shared/web_utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../performance_utils.dart';
import '_perfetto_controller_web.dart';
import 'perfetto_controller.dart';

class Perfetto extends StatefulWidget {
  const Perfetto({
    super.key,
    required this.perfettoController,
  });

  final PerfettoController perfettoController;

  @override
  State<Perfetto> createState() => _PerfettoState();
}

class _PerfettoState extends State<Perfetto> with AutoDisposeMixin {
  late final PerfettoControllerImpl _perfettoController;

  late final _PerfettoViewController _viewController;

  @override
  void initState() {
    super.initState();
    _perfettoController = widget.perfettoController as PerfettoControllerImpl;
    _viewController = _PerfettoViewController(_perfettoController)..init();

    // If [_perfettoController.activeTrace.trace] has a null value, the trace
    // data has not yet been initialized.
    if (_perfettoController.activeTrace.traceBinary != null) {
      _loadActiveTrace();
    }
    addAutoDisposeListener(_perfettoController.activeTrace, _loadActiveTrace);

    _scrollToActiveTimeRange();
    addAutoDisposeListener(
      _perfettoController.activeScrollToTimeRange,
      _scrollToActiveTimeRange,
    );
  }

  void _loadActiveTrace() {
    assert(_perfettoController.activeTrace.traceBinary != null);
    unawaited(
      _viewController._loadPerfettoTrace(
        _perfettoController.activeTrace.traceBinary!,
      ),
    );
  }

  void _scrollToActiveTimeRange() {
    unawaited(
      _viewController._scrollToTimeRange(
        _perfettoController.activeScrollToTimeRange.value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: HtmlElementView(
        viewType: _perfettoController.viewId,
      ),
    );
  }

  @override
  void dispose() {
    _viewController.dispose();
    super.dispose();
  }
}

class _PerfettoViewController extends DisposableController
    with AutoDisposeControllerMixin {
  _PerfettoViewController(this.perfettoController);

  final PerfettoControllerImpl perfettoController;

  /// Completes when the perfetto iFrame has received the first event on the
  /// 'onLoad' stream.
  late final Completer<void> _perfettoIFrameReady;

  /// Whether the perfetto iFrame has been unloaded after loading.
  ///
  /// This is stored to prevent race conditions where the iFrame's content
  /// window has become null. This is set to true when the perfetto iFrame has
  /// received the first event on the 'unload' stream.
  bool _perfettoIFrameUnloaded = false;

  /// Completes when the Perfetto postMessage handler is ready, which is
  /// signaled by receiving a [_perfettoPong] event in response to sending a
  /// [_perfettoPing] event.
  late final Completer<void> _perfettoHandlerReady;

  /// Completes when the DevTools theme postMessage handler is ready, which is
  /// signaled by receiving a [_devtoolsThemePong] event in response to sending
  /// a [_devtoolsThemePing] event.
  late final Completer<void> _devtoolsThemeHandlerReady;

  /// Timer that will poll until [_perfettoHandlerReady] is complete or until
  /// [_pollUntilReadyTimeout] has passed.
  Timer? _pollForPerfettoHandlerReady;

  /// Timer that will poll until [_devtoolsThemeHandlerReady] is complete or
  /// until [_pollUntilReadyTimeout] has passed.
  Timer? _pollForThemeHandlerReady;

  static const _pollUntilReadyTimeout = Duration(seconds: 10);

  /// The listener that is added to DevTools' [window] to receive messages
  /// from the Perfetto iFrame.
  ///
  /// We need to store this in a variable so that the listener is properly
  /// removed in [dispose].
  EventListener? _handleMessageListener;

  void init() {
    _perfettoIFrameReady = Completer<void>();
    _perfettoHandlerReady = Completer<void>();
    _devtoolsThemeHandlerReady = Completer<void>();
    _perfettoIFrameUnloaded = false;

    unawaited(
      perfettoController.perfettoIFrame.onLoad.first.then((_) {
        _perfettoIFrameReady.complete();
      }),
    );

    // TODO(kenz): uncomment once https://github.com/dart-lang/web/pull/246 is
    // landed and package:web 0.6.0 is published.
    // unawaited(
    //   perfettoController.perfettoIFrame.onUnload.first.then((_) {
    //     if (_perfettoIFrameReady.isCompleted) {
    //       // Only set to true if this occurs after the iFrame has been loaded.
    //       _perfettoIFrameUnloaded = true;
    //     }
    //   }),
    // );

    window.addEventListener(
      'message',
      _handleMessageListener = _handleMessage.toJS,
    );

    unawaited(_loadStyle(preferences.darkModeTheme.value));
    addAutoDisposeListener(preferences.darkModeTheme, () async {
      await _loadStyle(preferences.darkModeTheme.value);
      reloadCssForThemeChange();
    });

    autoDisposeStreamSubscription(
      perfettoController.perfettoPostEventStream.stream.listen((event) async {
        if (event == EmbeddedPerfettoEvent.showHelp.event) {
          await _showHelp();
        }
      }),
    );
  }

  Future<void> _loadPerfettoTrace(Uint8List traceBinary) async {
    if (traceBinary.isEmpty) {
      // TODO(kenz): is there a better way to create an empty data set using the
      // protozero format? I think this is still using the legacy Chrome format.
      // We can't use `Trace()` because the Perfetto post message handler throws
      // an exception if an empty buffer is posted.
      traceBinary = Uint8List.fromList(
        jsonEncode({'traceEvents': []}).codeUnits,
      );
    }

    await _pingPerfettoUntilReady();
    ga.select(gac.performance, gac.PerformanceEvents.perfettoLoadTrace.name);
    _postMessage({
      'perfetto': {
        'buffer': traceBinary,
        'title': 'DevTools timeline trace',
        'keepApiOpen': true,
        'expandAllTrackGroups': true,
      },
    });
  }

  Future<void> _scrollToTimeRange(TimeRange? timeRange) async {
    if (timeRange == null) return;

    if (!timeRange.isWellFormed) {
      pushNoTimelineEventsAvailableWarning();
      return;
    }
    await _pingPerfettoUntilReady();
    ga.select(
      gac.performance,
      gac.PerformanceEvents.perfettoScrollToTimeRange.name,
    );
    _postMessage({
      'perfetto': {
        // Pass the values to Perfetto in seconds.
        'timeStart': timeRange.start!.inMicroseconds / 1000000,
        'timeEnd': timeRange.end!.inMicroseconds / 1000000,
        // The time range should take up 80% of the visible window.
        'viewPercentage': 0.8,
      },
    });
  }

  Future<void> _loadStyle(bool darkMode) async {
    // This message will be handled by [devtools_theme_handler.js], which is
    // included in the Perfetto build inside
    // [packages/perfetto_ui_compiled/dist].
    await _pingDevToolsThemeHandlerUntilReady();
    _postMessageWithId(
      EmbeddedPerfettoEvent.devtoolsThemeChange.event,
      perfettoIgnore: true,
      args: {
        'theme': darkMode ? 'dark' : 'light',
      },
    );
  }

  void reloadCssForThemeChange() {
    const maxReloadCalls = 3;
    var reloadCount = 0;

    // Send this message [maxReloadCalls] times to ensure that the CSS has been
    // updated by the time we ask Perfetto to reload the CSS constants.
    late final Timer pollingTimer;
    pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (reloadCount++ < maxReloadCalls) {
        _postMessage(EmbeddedPerfettoEvent.reloadCssConstants.event);
      } else {
        pollingTimer.cancel();
      }
    });
  }

  Future<void> _showHelp() async {
    await _pingPerfettoUntilReady();
    _postMessage(EmbeddedPerfettoEvent.showHelp.event);
  }

  void _postMessage(Object message) async {
    await _perfettoIFrameReady.future;
    if (_perfettoIFrameUnloaded) return;
    assert(
      perfettoController.perfettoIFrame.contentWindow != null,
      'Something went wrong. The iFrame\'s contentWindow is null after the'
      ' _perfettoIFrameReady future completed.',
    );
    perfettoController.perfettoIFrame.contentWindow!.postMessage(
      message.jsify(),
      perfettoController.perfettoUrl.toJS,
    );
  }

  void _postMessageWithId(
    String id, {
    Map<String, Object> args = const {},
    bool perfettoIgnore = false,
  }) {
    final message = <String, Object>{
      'msgId': id,
      if (perfettoIgnore) 'perfettoIgnore': true,
    }..addAll(args);
    _postMessage(message);
  }

  void _handleMessage(Event e) {
    if (e.isMessageEvent) {
      final messageData = ((e as MessageEvent).data as JSString).toDart;
      if (messageData == EmbeddedPerfettoEvent.pong.event) {
        _perfettoHandlerReady.safeComplete();
      }
      if (messageData == EmbeddedPerfettoEvent.devtoolsThemePong.event) {
        _devtoolsThemeHandlerReady.safeComplete();
      }
    }
  }

  Future<void> _pingPerfettoUntilReady() async {
    if (!_perfettoHandlerReady.isCompleted) {
      _pollForPerfettoHandlerReady =
          Timer.periodic(const Duration(milliseconds: 200), (_) {
        // Once the Perfetto UI is ready, Perfetto will receive this 'PING'
        // message and return a 'PONG' message, handled in [_handleMessage].
        _postMessage(EmbeddedPerfettoEvent.ping.event);
      });

      await _perfettoHandlerReady.future.timeout(
        _pollUntilReadyTimeout,
        onTimeout: () => _pollForPerfettoHandlerReady?.cancel(),
      );
      _pollForPerfettoHandlerReady?.cancel();
    }
  }

  Future<void> _pingDevToolsThemeHandlerUntilReady() async {
    if (!_devtoolsThemeHandlerReady.isCompleted) {
      _pollForThemeHandlerReady =
          Timer.periodic(const Duration(milliseconds: 200), (_) {
        // Once [devtools_theme_handler.js] is ready, it will receive this
        // 'PING-DEVTOOLS-THEME' message and return a 'PONG-DEVTOOLS-THEME'
        // message, handled in [_handleMessage].
        _postMessageWithId(
          EmbeddedPerfettoEvent.devtoolsThemePing.event,
          perfettoIgnore: true,
        );
      });

      await _devtoolsThemeHandlerReady.future.timeout(
        _pollUntilReadyTimeout,
        onTimeout: () => _pollForThemeHandlerReady?.cancel(),
      );
      _pollForThemeHandlerReady?.cancel();
    }
  }

  @override
  void dispose() {
    window.removeEventListener('message', _handleMessageListener);
    _handleMessageListener = null;
    _pollForPerfettoHandlerReady?.cancel();
    _pollForPerfettoHandlerReady = null;
    _pollForThemeHandlerReady?.cancel();
    _pollForThemeHandlerReady = null;
    super.dispose();
  }
}
