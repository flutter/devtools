// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/utils.dart';
import 'perfetto_controller.dart';
import 'tracing/model.dart';

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
/// [ui_web.platformViewRegistry.registerViewFactory]. Each new [html.IFrameElement]
/// must have a unique id in the [PlatformViewRegistry], which
/// [_viewIdIncrementer] is used to create.
var _viewIdIncrementer = 0;

/// Events that are passed between DevTools and the embedded Perfetto iFrame via
/// [window.postMessage].
enum EmbeddedPerfettoEvent {
  /// Id for an event Perfetto expects to verify the trace viewer is ready.
  ping('PING'),

  /// Id for an event that Perfetto will send back after receiving a [ping]
  /// event.
  pong('PONG'),

  /// Id for an event that signals to Perfetto that the modal help dialog should
  /// be opened.
  showHelp('SHOW-HELP'),

  /// Id for an event that signals to Perfetto that the CSS constants need to be
  /// re-initialized.
  reloadCssConstants('RELOAD-CSS-CONSTANTS'),

  /// Id for a [postMessage] request that is sent before trying to change the
  /// DevTools theme (see [devtoolsThemeChange]).
  ///
  /// Once the DevTools theme handler in the bundled Perfetto web app has been
  /// registered, a "pong" event [devtoolsThemePong] will be returned, at which
  /// point we can safely change the theme [devtoolsThemeChange].
  ///
  /// This message must be sent with the argument 'perfettoIgnore' set to true
  /// so that the message handler in the Perfetto codebase
  /// [post_message_handler.ts] will not try to handle this message and warn
  /// "Unknown postMessage() event received".
  devtoolsThemePing('DART-DEVTOOLS-THEME-PING'),

  /// Id for a [postMessage] response that should be received when the DevTools
  /// theme handler has been registered.
  ///
  /// We will send a "ping" event [devtoolsThemePing] to the DevTools theme
  /// handler in the bundled Perfetto web app, and the handler will return this
  /// "pong" event when it is ready. We must wait for this event to be returned
  /// before we can send a theme change request [devtoolsThemeChange].
  devtoolsThemePong('DART-DEVTOOLS-THEME-PONG'),

  /// Id for a [postMessage] request that is sent on DevTools theme changes.
  ///
  /// This message must be sent with the argument 'perfettoIgnore' set to true
  /// so that the message handler in the Perfetto codebase
  /// [post_message_handler.ts] will not try to handle this message and warn
  /// "Unknown postMessage() event received".
  devtoolsThemeChange('DART-DEVTOOLS-THEME-CHANGE');

  const EmbeddedPerfettoEvent(this.event);

  final String event;
}

class PerfettoControllerImpl extends PerfettoController {
  PerfettoControllerImpl(
    super.performanceController,
    super.timelineEventsController,
  );

  /// The view id for the Perfetto iFrame.
  ///
  /// See [_viewIdIncrementer] for an explanation of why we use an incrementer
  /// in the id.
  late final viewId = 'embedded-perfetto-${_viewIdIncrementer++}';

  /// Url when running Perfetto locally following the instructions here:
  /// https://perfetto.dev/docs/contributing/build-instructions#ui-development
  static const _debugPerfettoUrl = 'http://127.0.0.1:10000/$_embeddedModeQuery';

  /// These query parameters have side effects in the Perfetto web app.
  static const _embeddedModeQuery = '?mode=embedded&hideSidebar=true';

  /// Delay to allow the Perfetto UI to load a trace.
  ///
  /// This is a heuristic to continue blocking UI elements on the DevTools side
  /// while the trace is being posted to the Perfetto side (for example, the
  /// [RefreshTimelineEventsButton]).
  static const _postTraceDelay = Duration(milliseconds: 500);

  String get perfettoUrl {
    if (_debugUseLocalPerfetto) {
      return _debugPerfettoUrl;
    }
    final basePath = devtoolsAssetsBasePath(
      origin: window.location.origin,
      path: window.location.pathname,
    );
    final indexFilePath = ui_web.assetManager
        .getAssetUrl(devToolsExtensionPoints.perfettoIndexLocation);
    final baseUrl = '$basePath/$indexFilePath';
    return '$baseUrl$_embeddedModeQuery';
  }

  HTMLIFrameElement get perfettoIFrame => _perfettoIFrame;

  late final HTMLIFrameElement _perfettoIFrame;

  /// The Perfetto trace data that should be shown in the Perfetto trace viewer.
  ///
  /// This will start in a null state before the first trace is been loaded.
  final activeTrace = PerfettoTrace(null);

  /// The time range that should be scrolled to, or focused, in the Perfetto
  /// trace viewer.
  ValueListenable<TimeRange?> get activeScrollToTimeRange =>
      _activeScrollToTimeRange;
  final _activeScrollToTimeRange = ValueNotifier<TimeRange?>(null);

  /// Trace data that we should load, but have not yet since the trace viewer
  /// is not visible (i.e. [TimelineEventsController.isActiveFeature] is false).
  Uint8List? pendingTraceToLoad;

  /// Time range we should scroll to, but have not yet since the trace viewer
  /// is not visible (i.e. [TimelineEventsController.isActiveFeature] is false).
  TimeRange? pendingScrollToTimeRange;

  final perfettoPostEventStream = StreamController<String>.broadcast();

  bool _initialized = false;

  @override
  void init() {
    assert(
      !_initialized,
      'PerfettoController.init() should only be called once.',
    );
    _initialized = true;

    _perfettoIFrame = createIFrameElement()
      // This url is safe because we built it ourselves and it does not include
      // any user input.
      // ignore: unsafe_html
      ..src = perfettoUrl
      ..allow = 'usb';
    _perfettoIFrame.style
      ..border = 'none'
      ..height = '100%'
      ..width = '100%';

    final registered = ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _perfettoIFrame,
    );
    assert(registered, 'Failed to register view factory for $viewId.');
  }

  @override
  void dispose() async {
    await perfettoPostEventStream.close();
    processor.dispose();
    super.dispose();
  }

  @override
  void onBecomingActive() {
    assert(timelineEventsController.isActiveFeature);
    if (pendingTraceToLoad != null) {
      unawaited(loadTrace(pendingTraceToLoad!));
      pendingTraceToLoad = null;
    }
    if (pendingScrollToTimeRange != null) {
      scrollToTimeRange(pendingScrollToTimeRange!);
      pendingScrollToTimeRange = null;
    }
  }

  @override
  Future<void> loadTrace(Uint8List traceBinary) async {
    if (!timelineEventsController.isActiveFeature) {
      pendingTraceToLoad = traceBinary;
      return;
    }
    await ga.timeAsync(
      gac.performance,
      gac.PerformanceEvents.perfettoLoadTrace.name,
      asyncOperation: () async {
        // This captures the time that the Perfetto trace viewer takes to load
        // the trace. When we await the delay, this allows [activeTrace]'s
        // listeners to be notified, which triggers posting the new trace to
        // the iFrame. The main thread is not released until the iFrame is done
        // receiving the trace.
        pendingTraceToLoad = null;
        activeTrace.trace = traceBinary;
        await Future.delayed(_postTraceDelay);
      },
    );
  }

  @override
  void scrollToTimeRange(TimeRange timeRange) {
    if (!timelineEventsController.isActiveFeature) {
      pendingScrollToTimeRange = timeRange;
      return;
    }
    pendingScrollToTimeRange = null;
    _activeScrollToTimeRange.value = timeRange;
  }

  @override
  void showHelpMenu() {
    perfettoPostEventStream.add(EmbeddedPerfettoEvent.showHelp.event);
  }

  @override
  Future<void> clear() async {
    processor.clear();
    await loadTrace(Uint8List(0));
  }
}
