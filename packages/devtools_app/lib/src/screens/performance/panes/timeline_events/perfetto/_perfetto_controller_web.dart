// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../../primitives/auto_dispose.dart';
import '../../../../../primitives/trace_event.dart';
import '../../../../../primitives/utils.dart';
import '../../../../../shared/globals.dart';
import '../../../performance_controller.dart';

/// Flag to enable embedding an instance of the Perfetto UI running on
/// localhost.
///
/// The version running on localhost will not include the DevTools styling
/// modifications for dark mode, as those CSS changes are defined in
/// [devtools_app/assets/perfetto] and will not be served with the Perfetto web
/// app running locally.
const _debugUseLocalPerfetto = false;

/// Incrementer for the Perfetto iFrame view that will live for the entire
/// DevTools lifecycle.
///
/// A new instance of [PerfettoController] will be created for each connected
/// app and for each load of offline data. Each time [PerfettoController.init]
/// is called, we create a new [html.IFrameElement] and register it to
/// [PerfettoController.viewId] via
/// [ui.platformViewRegistry.registerViewFactory]. Each new [html.IFrameElement]
/// must have a unique id in the [PlatformViewRegistry], which
/// [_viewIdIncrementer] is used to create.
var _viewIdIncrementer = 0;

class PerfettoController extends DisposableController
    with AutoDisposeControllerMixin {
  PerfettoController(this.performanceController);

  final PerformanceController performanceController;

  late final viewId = 'embedded-perfetto-${_viewIdIncrementer++}';

  /// Url when running Perfetto locally following the instructions here:
  /// https://perfetto.dev/docs/contributing/build-instructions#ui-development
  static const _debugPerfettoUrl = 'http://127.0.0.1:10000/$_embeddedModeQuery';

  static const _embeddedModeQuery = '?mode=embedded&hideSidebar=true';

  static const _perfettoPing = 'PING';

  static const _perfettoPong = 'PONG';

  /// Id for a [postMessage] request that is sent before trying to change the
  /// DevTools theme (see [_devtoolsThemeChange]).
  ///
  /// Once the DevTools theme handler in the bundled Perfetto web app has been
  /// registered, a "pong" event [_devtoolsThemePong] will be returned, at which
  /// point we can safely change the theme [_devtoolsThemeChange].
  ///
  /// This message must be sent with the argument 'perfettoIgnore' set to true
  /// so that the message handler in the Perfetto codebase
  /// [post_message_handler.ts] will not try to handle this message and warn
  /// "Unknown postMessage() event received".
  static const _devtoolsThemePing = 'DART-DEVTOOLS-THEME-PING';

  /// Id for a [postMessage] response that should be received when the DevTools
  /// theme handler has been registered.
  ///
  /// We will send a "ping" event [_devtoolsThemePing] to the DevTools theme
  /// handler in the bundled Perfetto web app, and the handler will return this
  /// "pong" event when it is ready. We must wait for this event to be returned
  /// before we can send a theme change request [_devtoolsThemeChange].
  static const _devtoolsThemePong = 'DART-DEVTOOLS-THEME-PONG';

  /// Id for a [postMessage] request that is sent on DevTools theme changes.
  ///
  /// This message must be sent with the argument 'perfettoIgnore' set to true
  /// so that the message handler in the Perfetto codebase
  /// [post_message_handler.ts] will not try to handle this message and warn
  /// "Unknown postMessage() event received".
  static const _devtoolsThemeChange = 'DART-DEVTOOLS-THEME-CHANGE';

  String get _perfettoUrl {
    if (_debugUseLocalPerfetto) {
      return _debugPerfettoUrl;
    }
    final baseUrl = isExternalBuild
        ? '${html.window.location.origin}/assets/packages/perfetto_compiled/dist/index.html'
        : 'https://ui.perfetto.dev';
    return '$baseUrl$_embeddedModeQuery';
  }

  late final html.IFrameElement _perfettoIFrame;

  /// Completes when the perfetto iFrame has recevied the first event on the
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

  /// Trace events that we should load, but have not yet since the trace viewer
  /// is not visible (i.e. [TimelineEventsController.isActiveFeature] is false).
  List<TraceEventWrapper>? pendingTraceEventsToLoad;

  /// Time range we should scroll to, but have not yet since the trace viewer
  /// is not visible (i.e. [TimelineEventsController.isActiveFeature] is false).
  TimeRange? pendingScrollToTimeRange;

  /// Boolean value representing the pending theme change we that we should
  /// apply, but have not yet since the trace viewer is not visible (i.e.
  /// [TimelineEventsController.isActiveFeature] is false).
  bool? pendingLoadDarkMode;

  void init() {
    _perfettoIFrameReady = Completer();
    _perfettoHandlerReady = Completer();
    _devtoolsThemeHandlerReady = Completer();
    _perfettoIFrame = html.IFrameElement()
      // This url is safe because we built it ourselves and it does not include
      // any user input.
      // ignore: unsafe_html
      ..src = _perfettoUrl
      ..allow = 'usb';
    _perfettoIFrame.style
      ..border = 'none'
      ..height = '100%'
      ..width = '100%';

    unawaited(
      _perfettoIFrame.onLoad.first.then((_) {
        _perfettoIFrameReady.complete();
      }),
    );

    // ignore: undefined_prefixed_name
    final registered = ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _perfettoIFrame,
    );
    assert(registered, 'Failed to register view factory for $viewId.');

    html.window.addEventListener('message', _handleMessage);

    if (isExternalBuild) {
      unawaited(_loadStyle(preferences.darkModeTheme.value));
      addAutoDisposeListener(preferences.darkModeTheme, () async {
        await _loadStyle(preferences.darkModeTheme.value);
      });
    }
  }

  Future<void> onBecomingActive() async {
    if (pendingLoadDarkMode != null) {
      unawaited(_loadStyle(pendingLoadDarkMode!));
    }
    if (pendingTraceEventsToLoad != null) {
      await loadTrace(pendingTraceEventsToLoad!);
      pendingTraceEventsToLoad = null;
    }
    if (pendingScrollToTimeRange != null) {
      await scrollToTimeRange(pendingScrollToTimeRange!);
      pendingScrollToTimeRange = null;
    }
  }

  Future<void> loadTrace(List<TraceEventWrapper> devToolsTraceEvents) async {
    if (!performanceController.timelineEventsController.isActiveFeature) {
      pendingTraceEventsToLoad = List.from(devToolsTraceEvents);
      return;
    }
    pendingTraceEventsToLoad = null;

    await _pingPerfettoUntilReady();

    final encodedJson = jsonEncode({
      'traceEvents': devToolsTraceEvents
          .map((eventWrapper) => eventWrapper.event.json)
          .toList(),
    });
    final buffer = Uint8List.fromList(encodedJson.codeUnits);

    _postMessage({
      'perfetto': {
        'buffer': buffer,
        'title': 'DevTools timeline trace',
        'keepApiOpen': true,
      }
    });
  }

  Future<void> scrollToTimeRange(TimeRange timeRange) async {
    if (!performanceController.timelineEventsController.isActiveFeature) {
      pendingScrollToTimeRange = timeRange;
      return;
    }
    pendingScrollToTimeRange = null;

    if (!timeRange.isWellFormed) {
      notificationService.push(
        'No timeline events available for the selected frame. Timeline '
        'events occurred too long ago before DevTools could access them. '
        'To avoid this, open the DevTools Performance page sooner.',
      );
      return;
    }
    await _pingPerfettoUntilReady();
    _postMessage({
      'perfetto': {
        // Pass the values to Perfetto in seconds.
        'timeStart': timeRange.start!.inMicroseconds / 1000000,
        'timeEnd': timeRange.end!.inMicroseconds / 1000000,
        // The time range should take up 80% of the visible window.
        'viewPercentage': 0.8,
      }
    });
  }

  Future<void> _loadStyle(bool darkMode) async {
    if (!isExternalBuild) return;
    if (!performanceController.timelineEventsController.isActiveFeature) {
      pendingLoadDarkMode = darkMode;
      return;
    }
    pendingLoadDarkMode = null;

    // This message will be handled by [devtools_theme_handler.js], which is
    // included in the Perfetto build inside [packages/perfetto_compiled/dist].
    await _pingDevToolsThemeHandlerUntilReady();
    _postMessageWithId(
      _devtoolsThemeChange,
      perfettoIgnore: true,
      args: {
        'theme': '${darkMode ? 'dark' : 'light'}',
      },
    );
  }

  void _postMessage(dynamic message) async {
    await _perfettoIFrameReady.future;
    assert(
      _perfettoIFrame.contentWindow != null,
      'Something went wrong. The iFrame\'s contentWindow is null after the'
      ' _perfettoIFrameReady future completed.',
    );
    _perfettoIFrame.contentWindow!.postMessage(
      message,
      _perfettoUrl,
    );
  }

  void _postMessageWithId(
    String id, {
    Map<String, dynamic> args = const {},
    bool perfettoIgnore = false,
  }) {
    final message = <String, dynamic>{
      'msgId': id,
      if (perfettoIgnore) 'perfettoIgnore': true,
    }..addAll(args);
    _postMessage(message);
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      if (e.data == _perfettoPong && !_perfettoHandlerReady.isCompleted) {
        _perfettoHandlerReady.complete();
      }

      if (e.data == _devtoolsThemePong &&
          !_devtoolsThemeHandlerReady.isCompleted) {
        _devtoolsThemeHandlerReady.complete();
      }
    }
  }

  Future<void> _pingPerfettoUntilReady() async {
    if (!_perfettoHandlerReady.isCompleted) {
      _pollForPerfettoHandlerReady =
          Timer.periodic(const Duration(milliseconds: 200), (_) async {
        // Once the Perfetto UI is ready, Perfetto will receive this 'PING'
        // message and return a 'PONG' message, handled in [_handleMessage].
        _postMessage(_perfettoPing);
      });

      // Timeout after [_pollUntilReadyTimeout] has passed.
      await Future.any([
        _perfettoHandlerReady.future,
        Future.delayed(_pollUntilReadyTimeout),
      ]).then((_) => _pollForPerfettoHandlerReady?.cancel());
    }
  }

  Future<void> _pingDevToolsThemeHandlerUntilReady() async {
    if (!isExternalBuild) return;
    if (!_devtoolsThemeHandlerReady.isCompleted) {
      _pollForThemeHandlerReady =
          Timer.periodic(const Duration(milliseconds: 200), (_) async {
        // Once [devtools_theme_handler.js] is ready, it will receive this
        // 'PING-DEVTOOLS-THEME' message and return a 'PONG-DEVTOOLS-THEME'
        // message, handled in [_handleMessage].
        _postMessageWithId(_devtoolsThemePing, perfettoIgnore: true);
      });

      // Timeout after [_pollUntilReadyTimeout] has passed.
      await Future.any([
        _devtoolsThemeHandlerReady.future,
        Future.delayed(_pollUntilReadyTimeout),
      ]).then((_) => _pollForThemeHandlerReady?.cancel());
    }
  }

  Future<void> clear() async {
    await loadTrace([]);
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
    _pollForPerfettoHandlerReady?.cancel();
    _pollForThemeHandlerReady?.cancel();
    super.dispose();
  }
}
