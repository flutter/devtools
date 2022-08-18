// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;

import '../../../../../primitives/auto_dispose.dart';

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
  static const _debugPerfettoUrl = 'http://127.0.0.1:10000/';

  static const _perfettoPong = 'PONG';

  String get perfettoUrl =>
      _debugUseLocalPerfetto ? _debugPerfettoUrl : 'https://ui.perfetto.dev/';

  late final html.IFrameElement _perfettoIFrame;

  late final Completer<void> _perfettoReady;

  void init() {
    _perfettoReady = Completer();
    _perfettoIFrame = html.IFrameElement()
      ..src = perfettoUrl
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
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      if (e.data == _perfettoPong && !_perfettoReady.isCompleted) {
        _perfettoReady.complete();
      }
    }
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
    super.dispose();
  }
}
