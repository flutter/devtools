// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../constants.dart';

enum PerformanceEvents {
  refreshTimelineEvents,
  performanceOverlay,
  timelineFlameChartHelp,
  framesChartVisibility,
  selectFlutterFrame,
  traceEventProcessingTime,
  trackRebuilds,
  trackUserCreatedWidgetBuilds,
  trackPaints,
  trackLayouts,
  enhanceTracingButtonSmall,
  disableClipLayers,
  disableOpacityLayers,
  disablePhysicalShapeLayers,
  collectRasterStats,
  clearRasterStats,
  fullScreenLayerImage,
  clearRebuildStats,
  perfettoModeTraceEventProcessingTime('traceEventProcessingTime-perfettoMode'),
  perfettoLoadTrace,
  perfettoScrollToTimeRange,
  perfettoShowHelp,
  performanceSettings,
  traceCategories;

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
  impellerWikiLink,
}
