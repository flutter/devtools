// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../constants.dart';

enum PerformanceEvents {
  refreshTimelineEvents,
  includeCpuSamplesInTimeline,
  performanceOverlay,
  timelineFlameChartHelp,
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
