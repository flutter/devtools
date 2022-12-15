// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/utils.dart';
import 'perfetto_controller.dart';

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

  String get perfettoUrl {
    if (_debugUseLocalPerfetto) {
      return _debugPerfettoUrl;
    }
    final baseUrl = isExternalBuild
        ? '${html.window.location.origin}/assets/packages/perfetto_compiled/dist/index.html'
        : 'https://ui.perfetto.dev';
    return '$baseUrl$_embeddedModeQuery';
  }

  html.IFrameElement get perfettoIFrame => _perfettoIFrame;

  late final html.IFrameElement _perfettoIFrame;

  /// The set of trace events that should be shown in the Perfetto trace viewer.
  ValueListenable<List<TraceEventWrapper>> get activeTraceEvents =>
      _activeTraceEvents;
  final _activeTraceEvents = ValueNotifier<List<TraceEventWrapper>>([]);

  /// The time range that should be scrolled to, or focused, in the Perfetto
  /// trace viewer.
  ValueListenable<TimeRange?> get activeScrollToTimeRange =>
      _activeScrollToTimeRange;
  final _activeScrollToTimeRange = ValueNotifier<TimeRange?>(null);

  /// Trace events that we should load, but have not yet since the trace viewer
  /// is not visible (i.e. [TimelineEventsController.isActiveFeature] is false).
  List<TraceEventWrapper>? pendingTraceEventsToLoad;

  /// Time range we should scroll to, but have not yet since the trace viewer
  /// is not visible (i.e. [TimelineEventsController.isActiveFeature] is false).
  TimeRange? pendingScrollToTimeRange;

  bool _initialized = false;

  @override
  void init() {
    assert(
      !_initialized,
      'PerfettoController.init() should only be called once.',
    );
    _initialized = true;

    _perfettoIFrame = html.IFrameElement()
      // This url is safe because we built it ourselves and it does not include
      // any user input.
      // ignore: unsafe_html
      ..src = perfettoUrl
      ..allow = 'usb';
    _perfettoIFrame.style
      ..border = 'none'
      ..height = '100%'
      ..width = '100%';

    // ignore: undefined_prefixed_name
    final registered = ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _perfettoIFrame,
    );
    assert(registered, 'Failed to register view factory for $viewId.');
  }

  @override
  void onBecomingActive() {
    assert(timelineEventsController.isActiveFeature);
    if (pendingTraceEventsToLoad != null) {
      loadTrace(pendingTraceEventsToLoad!);
      pendingTraceEventsToLoad = null;
    }
    if (pendingScrollToTimeRange != null) {
      scrollToTimeRange(pendingScrollToTimeRange!);
      pendingScrollToTimeRange = null;
    }
  }

  @override
  void loadTrace(List<TraceEventWrapper> devToolsTraceEvents) {
    if (!timelineEventsController.isActiveFeature) {
      pendingTraceEventsToLoad = List.from(devToolsTraceEvents);
      return;
    }
    pendingTraceEventsToLoad = null;
    _activeTraceEvents.value = List.from(devToolsTraceEvents);
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
  void clear() {
    loadTrace([]);
  }
}
