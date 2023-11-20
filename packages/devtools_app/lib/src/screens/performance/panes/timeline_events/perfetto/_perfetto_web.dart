// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_app_shared/web_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/helpers.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/utils.dart';
import '_perfetto_controller_web.dart';
import 'perfetto_controller.dart';

class Perfetto extends StatefulWidget {
  const Perfetto({
    Key? key,
    required this.perfettoController,
  }) : super(key: key);

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

    // If [_perfettoController.activeTraceEvents] has a null value, the trace
    // data has not yet been initialized.
    if (_perfettoController.activeTraceEvents.value != null) {
      _loadActiveTrace();
    }
    addAutoDisposeListener(
      _perfettoController.activeTraceEvents,
      _loadActiveTrace,
    );

    _scrollToActiveTimeRange();
    addAutoDisposeListener(
      _perfettoController.activeScrollToTimeRange,
      _scrollToActiveTimeRange,
    );
  }

  void _loadActiveTrace() {
    assert(_perfettoController.activeTraceEvents.value != null);
    _viewController._loadTrace(_perfettoController.activeTraceEvents.value!);
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

    unawaited(
      perfettoController.perfettoIFrame.onLoad.first.then((_) {
        _perfettoIFrameReady.complete();
      }),
    );

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

  void _loadTrace(List<TraceEventWrapper> devToolsTraceEvents) {
    final encodedJson = jsonEncode({
      'traceEvents': devToolsTraceEvents
          .map((eventWrapper) => eventWrapper.event.json)
          .toList(),
    });
    final buffer = Uint8List.fromList(encodedJson.codeUnits);

    ga.select(gac.performance, gac.PerformanceEvents.perfettoLoadTrace.name);
    _postMessage({
      'perfetto': {
        'buffer': buffer,
        'title': 'DevTools timeline trace',
        'keepApiOpen': true,
      },
    });
  }

  Future<void> _scrollToTimeRange(TimeRange? timeRange) async {
    if (timeRange == null) return;

    if (!timeRange.isWellFormed) {
      notificationService.push(
        'No timeline events available for the selected frame. Timeline '
        'events occurred too long ago before DevTools could access them. '
        'To avoid this, open the DevTools Performance page earlier.',
      );
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
    // included in the Perfetto build inside [packages/perfetto_ui_compiled/dist].
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
      if (messageData == EmbeddedPerfettoEvent.pong.event &&
          !_perfettoHandlerReady.isCompleted) {
        _perfettoHandlerReady.complete();
      }

      if (messageData == EmbeddedPerfettoEvent.devtoolsThemePong.event &&
          !_devtoolsThemeHandlerReady.isCompleted) {
        _devtoolsThemeHandlerReady.complete();
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
    _pollForThemeHandlerReady?.cancel();
    super.dispose();
  }
}
