// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

part of '../constants.dart';

enum PerformanceEvents {
  refreshTimelineEvents,
  includeCpuSamplesInTimeline,
  performanceOverlay,
  framesChartVisibility,
  selectFlutterFrame,
  trackRebuilds,
  trackUserCreatedWidgetBuilds,
  trackPaints,
  trackLayouts,
  profilePlatformChannels,
  enhanceTracingButtonSmall,
  disableClipLayers,
  disableOpacityLayers,
  disablePhysicalShapeLayers,
  countWidgetBuilds('trackRebuildWidgets'),
  collectRasterStats,
  clearRasterStats,
  fullScreenLayerImage,
  clearRebuildStats,
  perfettoLoadTrace,
  perfettoScrollToTimeRange,
  perfettoShowHelp,
  performanceSettings,
  timelineSettings,
  openDataFile,
  loadDataFromFile,
  // Timing events.
  perfettoModeTraceEventProcessingTime('traceEventProcessingTime-perfettoMode'),
  getPerfettoVMTimelineWithCpuSamplesTime,
  getPerfettoVMTimelineTime;

  const PerformanceEvents([this.nameOverride]);

  final String? nameOverride;
}

enum PerformanceDocs {
  flutterPerformanceDocs,
  performanceOverlayDocs,
  trackWidgetBuildsDocs,
  trackPaintsDocs,
  trackLayoutsDocs,
  disableClipLayersDocs,
  disableOpacityLayersDocs,
  disablePhysicalShapeLayersDocs,
  canvasSaveLayerDocs,
  intrinsicOperationsDocs,
  shaderCompilationDocs,
  shaderCompilationDocsTooltipLink,
  impellerDocsLink,
  impellerDocsLinkFromRasterStats,
  platformChannelsDocs,
}
