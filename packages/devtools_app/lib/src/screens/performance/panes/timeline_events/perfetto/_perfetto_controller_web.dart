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

  static const _devtoolsThemePing = 'DART-DEVTOOLS-THEME-PING';

  static const _devtoolsThemePong = 'DART-DEVTOOLS-THEME-PONG';

  /// Id for a [postMessage] request that is sent on DevTools theme changes.
  ///
  /// This id is marked in the Perfetto UI codebase [post_message_handler.ts] as
  /// trusted. This ensures that the embedded Perfetto web app does not try to
  /// handle this message and warn "Unknown postMessage() event received".
  ///
  /// Any changes to this string must also be applied in
  /// [post_message_handler.ts] in the Perfetto codebase.
  static const _devtoolsThemeChange = 'DART-DEVTOOLS-THEME-CHANGE';

  String get _perfettoUrl {
    if (_debugUseLocalPerfetto) {
      return _debugPerfettoUrl;
    }
    final baseUrl = isExternalBuild
        ? '${html.window.location.origin}/packages/perfetto_compiled/dist/index.html'
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
      args: {
        'theme': '${darkMode ? 'dark' : 'light'}',
      },
    );
  }

  void _postMessage(dynamic message) {
    _perfettoIFrame.contentWindow!.postMessage(
      message,
      _perfettoUrl,
    );
  }

  void _postMessageWithId(String id, {Map<String, dynamic> args = const {}}) {
    final message = <String, dynamic>{
      'msgId': id,
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
        _postMessageWithId(_devtoolsThemePing);
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
