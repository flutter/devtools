// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../../../app.dart';
import '../../../../../primitives/auto_dispose.dart';
import '../../../../../primitives/trace_event.dart';
import '../../../../../primitives/utils.dart';
import '../../../../../shared/globals.dart';

/// Flag to enable embedding an instance of the Perfetto UI running on
/// localhost.
///
/// The version running on localhost will not include the DevTools styling
/// modifications for dark mode, as those CSS changes are defined in
/// [devtools_app/assets/perfetto] and will not be served with the Perfetto web
/// app running locally.
const _debugUseLocalPerfetto = false;

class PerfettoController extends DisposableController
    with AutoDisposeControllerMixin {
  static const viewId = 'embedded-perfetto';

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

  late final Completer<void> _perfettoReady;

  late final Completer<void> _devtoolsThemeHandlerReady;

  void init() {
    _perfettoReady = Completer();
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

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _perfettoIFrame,
    );

    html.window.addEventListener('message', _handleMessage);

    if (isExternalBuild) {
      _loadInitialStyle();
      addAutoDisposeListener(preferences.darkModeTheme, () async {
        _loadStyle(preferences.darkModeTheme.value);
      });
    }
  }

  Future<void> loadTrace(List<TraceEventWrapper> devToolsTraceEvents) async {
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

  Future<void> _loadInitialStyle() async {
    if (!isExternalBuild) return;
    await _pingDevToolsThemeHandlerUntilReady();
    _loadStyle(preferences.darkModeTheme.value);
  }

  void _loadStyle(bool darkMode) {
    if (!isExternalBuild) return;
    // This message will be handled by [devtools_theme_handler.js], which is
    // included in the Perfetto build inside [packages/perfetto_compiled/dist].
    _postMessageWithId(
      _devtoolsThemeChange,
      perfettoIgnore: true,
      args: {
        'theme': '${darkMode ? 'dark' : 'light'}',
      },
    );
  }

  void _postMessage(dynamic message) async {
    await _perfettoIFrameReady();
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
      if (e.data == _perfettoPong && !_perfettoReady.isCompleted) {
        _perfettoReady.complete();
      }

      if (e.data == _devtoolsThemePong &&
          !_devtoolsThemeHandlerReady.isCompleted) {
        _devtoolsThemeHandlerReady.complete();
      }
    }
  }

  Future<void> _perfettoIFrameReady() async {
    if (_perfettoIFrame.contentWindow == null) {
      await _perfettoIFrame.onLoad.first;
      assert(
        _perfettoIFrame.contentWindow != null,
        'Something went wrong. The iFrame\'s contentWindow is null after the'
        ' onLoad event.',
      );
    }
  }

  Future<void> _pingPerfettoUntilReady() async {
    while (!_perfettoReady.isCompleted) {
      await Future.delayed(const Duration(microseconds: 100), () async {
        // Once the Perfetto UI is ready, Perfetto will receive this 'PING'
        // message and return a 'PONG' message, handled in [_handleMessage].
        _postMessage(_perfettoPing);
      });
    }
  }

  Future<void> _pingDevToolsThemeHandlerUntilReady() async {
    if (!isExternalBuild) return;
    while (!_devtoolsThemeHandlerReady.isCompleted) {
      await Future.delayed(const Duration(microseconds: 100), () async {
        // Once [devtools_theme_handler.js] is ready, it will receive this
        // 'PING-DEVTOOLS-THEME' message and return a 'PONG-DEVTOOLS-THEME'
        // message, handled in [_handleMessage].
        _postMessageWithId(_devtoolsThemePing, perfettoIgnore: true);
      });
    }
  }

  Future<void> clear() async {
    await loadTrace([]);
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
    super.dispose();
  }
}
