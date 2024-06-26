// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This is the Perfetto data from [samplePerformanceData] as data class objects.

// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:convert';

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_test/test_data.dart';
import 'package:fixnum/fixnum.dart';
import 'package:vm_service/vm_service.dart';

import '../../utils/test_utils.dart';

part '_perfetto_events_raw.dart';

PerfettoTimeline perfettoVmTimeline = PerfettoTimeline.parse({
  'trace': base64Encode(
    rawPerformanceData[OfflinePerformanceData.traceBinaryKey] as List<int>,
  ),
  'timeOriginMicros': 0,
  'timeExtentMicros': 800000000000,
})!;

Map<String, Object?> rawPerformanceData =
    (samplePerformanceData[ScreenMetaData.performance.id] as Map)
        .cast<String, Object?>();

final testUiTrackId = Int64(22787);
final testRasterTrackId = Int64(31491);

final testFrame0 = FlutterFrame.fromJson({
  'number': 0,
  'startTime': 10000,
  'elapsed': 20000,
  'build': 10000,
  'raster': 12000,
  'vsyncOverhead': 10,
});

final testFrame1 = FlutterFrame.fromJson({
  'number': 1,
  'startTime': 40000,
  'elapsed': 20000,
  'build': 16000,
  'raster': 16000,
  'vsyncOverhead': 1000,
});

final testFrame2 = FlutterFrame.fromJson({
  'number': 2,
  'startTime': 40000,
  'elapsed': 20000,
  'build': 16000,
  'raster': 16000,
  'vsyncOverhead': 1000,
});

final jankyFrame = FlutterFrame.fromJson({
  'number': 2,
  'startTime': 10000,
  'elapsed': 20000,
  'build': 18000,
  'raster': 18000,
  'vsyncOverhead': 1000,
});

final jankyFrameUiOnly = FlutterFrame.fromJson({
  'number': 3,
  'startTime': 10000,
  'elapsed': 20000,
  'build': 18000,
  'raster': 5000,
  'vsyncOverhead': 1000,
});

final jankyFrameRasterOnly = FlutterFrame.fromJson({
  'number': 4,
  'startTime': 10000,
  'elapsed': 20000,
  'build': 5000,
  'raster': 18000,
  'vsyncOverhead': 10,
});

final testFrameWithShaderJank = FlutterFrame.fromJson({
  'number': 5,
  'startTime': 10000,
  'elapsed': 200000,
  'build': 50000,
  'raster': 70000,
  'vsyncOverhead': 10,
})
  ..setEventFlow(FlutterFrame4.uiEventWithExtras)
  ..setEventFlow(timelineEventWithShaderJank);

final testFrameWithSubtleShaderJank = FlutterFrame.fromJson({
  'number': 6,
  'startTime': 10000,
  'elapsed': 200000,
  'build': 50000,
  'raster': 70000,
  'vsyncOverhead': 10,
})
  ..setEventFlow(FlutterFrame4.uiEventWithExtras)
  ..setEventFlow(timelineEventWithSubtleShaderJank);

final timelineEventWithSubtleShaderJank = testTimelineEvent(
  name: 'Rasterizer::DoDraw',
  type: TimelineEventType.raster,
  startMicros: 713834379092,
  endMicros: 713834382102,
  args: {'frame_number': '2', 'devtoolsTag': 'shaders'},
  endArgs: {},
);
final timelineEventWithShaderJank = testTimelineEvent(
  name: 'Rasterizer::DoDraw',
  type: TimelineEventType.raster,
  startMicros: 713834379092,
  endMicros: 713834389102,
  args: {'frame_number': '2', 'devtoolsTag': 'shaders'},
  endArgs: {},
);

/// Data for Frame (id: 2)
abstract class FlutterFrame2 {
  static final frame = FlutterFrame.fromJson({
    'number': 2,
    'startTime': 713834379092,
    'elapsed': 1730039,
    'build': 1709331,
    'raster': 20276,
    'vsyncOverhead': 252,
  })
    ..setEventFlow(uiEvent)
    ..setEventFlow(rasterEvent);

  static const uiEventAsString =
      '''  Animator::BeginFrame [713834379092 μs - 713834379102 μs]
''';

  static const rasterEventAsString =
      '''  Rasterizer::DoDraw [713836088591 μs - 713836108931 μs]
    Rasterizer::DrawToSurfaces [713836088592 μs - 713836108917 μs]
      GPUSurfaceMetalImpeller::AcquireFrame [713836088607 μs - 713836093553 μs]
        SurfaceMTL::WrapCurrentMetalLayerDrawable [713836088654 μs - 713836093545 μs]
          WaitForNextDrawable [713836088655 μs - 713836093541 μs]
      CompositorContext::ScopedFrame::Raster [713836093557 μs - 713836093615 μs]
        LayerTree::Preroll [713836093580 μs - 713836093597 μs]
        IOSExternalViewEmbedder::PostPrerollAction [713836093598 μs - 713836093598 μs]
        LayerTree::Paint [713836093599 μs - 713836093615 μs]
      SurfaceFrame::Submit [713836093616 μs - 713836108864 μs]
        SurfaceFrame::BuildDisplayList [713836093616 μs - 713836093621 μs]
        DisplayListDispatcher::EndRecordingAsPicture [713836094185 μs - 713836094188 μs]
        Renderer::Render [713836094188 μs - 713836108846 μs]
          EntityPass::OnRender [713836094556 μs - 713836108700 μs]
            CreateGlyphAtlas [713836099800 μs - 713836108025 μs]
              CanAppendToExistingAtlas [713836099807 μs - 713836099810 μs]
              OptimumAtlasSizeForFontGlyphPairs [713836099811 μs - 713836099835 μs]
              CreateAtlasBitmap [713836099845 μs - 713836103975 μs]
              UploadGlyphTextureAtlas [713836103979 μs - 713836108020 μs]
''';

  static final uiEvent = animatorBeginFrameEvent;
  static final animatorBeginFrameEvent = testTimelineEvent(
    name: 'Animator::BeginFrame',
    type: TimelineEventType.ui,
    args: {'frame_number': '2'},
    endArgs: {},
    startMicros: 713834379092,
    endMicros: 713834379102,
  );

  static final rasterEvent = rasterizerDoDrawEvent
    ..addChild(
      rasterizerDrawToSurfacesEvent
        ..addAllChildren([
          gpuSurfaceMetalImpellerAcquireFrameEvent
            ..addChild(
              surfaceMTLWrapCurrentMetalLayerDrawableEvent
                ..addChild(
                  waitForNextDrawableEvent,
                ),
            ),
          compositorContextScopedFrameRasterEvent
            ..addAllChildren([
              layerTreePrerollEvent,
              iOSExternalViewEmbedderPostPrerollActionEvent,
              layerTreePaintEvent,
            ]),
          surfaceFrameSubmitEvent
            ..addAllChildren([
              surfaceFrameBuildDisplayListEvent,
              displayListDispatcherEndRecordingAsPictureEvent,
              rendererRenderEvent
                ..addChild(
                  entityPassOnRenderEvent
                    ..addChild(
                      createGlyphAtlasEvent
                        ..addAllChildren(
                          [
                            canAppendToExistingAtlasEvent,
                            optimumAtlasSizeForFontGlyphPairsEvent,
                            createAtlasBitmapEvent,
                            uploadGlyphTextureAtlasEvent,
                          ],
                        ),
                    ),
                ),
            ]),
        ]),
    );
  static final rasterizerDoDrawEvent = testTimelineEvent(
    name: 'Rasterizer::DoDraw',
    type: TimelineEventType.raster,
    args: {'frame_number': '2'},
    endArgs: {},
    startMicros: 713836088591,
    endMicros: 713836108931,
  );
  static final rasterizerDrawToSurfacesEvent = testTimelineEvent(
    name: 'Rasterizer::DrawToSurfaces',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836088592,
    endMicros: 713836108917,
  );
  static final gpuSurfaceMetalImpellerAcquireFrameEvent = testTimelineEvent(
    name: 'GPUSurfaceMetalImpeller::AcquireFrame',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836088607,
    endMicros: 713836093553,
  );
  static final surfaceMTLWrapCurrentMetalLayerDrawableEvent = testTimelineEvent(
    name: 'SurfaceMTL::WrapCurrentMetalLayerDrawable',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836088654,
    endMicros: 713836093545,
  );

  static final waitForNextDrawableEvent = testTimelineEvent(
    name: 'WaitForNextDrawable',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836088655,
    endMicros: 713836093541,
  );
  static final compositorContextScopedFrameRasterEvent = testTimelineEvent(
    name: 'CompositorContext::ScopedFrame::Raster',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836093557,
    endMicros: 713836093615,
  );
  static final layerTreePrerollEvent = testTimelineEvent(
    name: 'LayerTree::Preroll',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836093580,
    endMicros: 713836093597,
  );
  static final iOSExternalViewEmbedderPostPrerollActionEvent =
      testTimelineEvent(
    name: 'IOSExternalViewEmbedder::PostPrerollAction',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836093598,
    endMicros: 713836093598,
  );
  static final layerTreePaintEvent = testTimelineEvent(
    name: 'LayerTree::Paint',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836093599,
    endMicros: 713836093615,
  );
  static final surfaceFrameSubmitEvent = testTimelineEvent(
    name: 'SurfaceFrame::Submit',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836093616,
    endMicros: 713836108864,
  );
  static final surfaceFrameBuildDisplayListEvent = testTimelineEvent(
    name: 'SurfaceFrame::BuildDisplayList',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836093616,
    endMicros: 713836093621,
  );
  static final displayListDispatcherEndRecordingAsPictureEvent =
      testTimelineEvent(
    name: 'DisplayListDispatcher::EndRecordingAsPicture',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836094185,
    endMicros: 713836094188,
  );
  static final rendererRenderEvent = testTimelineEvent(
    name: 'Renderer::Render',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836094188,
    endMicros: 713836108846,
  );
  static final entityPassOnRenderEvent = testTimelineEvent(
    name: 'EntityPass::OnRender',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836094556,
    endMicros: 713836108700,
  );
  static final createGlyphAtlasEvent = testTimelineEvent(
    name: 'CreateGlyphAtlas',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836099800,
    endMicros: 713836108025,
  );
  static final canAppendToExistingAtlasEvent = testTimelineEvent(
    name: 'CanAppendToExistingAtlas',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836099807,
    endMicros: 713836099810,
  );
  static final optimumAtlasSizeForFontGlyphPairsEvent = testTimelineEvent(
    name: 'OptimumAtlasSizeForFontGlyphPairs',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836099811,
    endMicros: 713836099835,
  );
  static final createAtlasBitmapEvent = testTimelineEvent(
    name: 'CreateAtlasBitmap',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836099845,
    endMicros: 713836103975,
  );
  static final uploadGlyphTextureAtlasEvent = testTimelineEvent(
    name: 'UploadGlyphTextureAtlas',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836103979,
    endMicros: 713836108020,
  );
}

/// Data for Frame (id: 4)
abstract class FlutterFrame4 {
  static final frame = FlutterFrame.fromJson(_frameJson)
    ..setEventFlow(uiEvent)
    ..setEventFlow(rasterEvent);

  /// A frame with extra timeline events for the purpose of testing.
  ///
  /// Some events included in [uiEventWithExtras] and [rasterEventWithExtras]
  /// are not part of the original trace from with [FlutterFrame4] was formed.
  static final frameWithExtras = FlutterFrame.fromJson(_frameJson)
    ..setEventFlow(uiEventWithExtras)
    ..setEventFlow(rasterEvent);

  static final _frameJson = {
    'number': 4,
    'startTime': 713836200160,
    'elapsed': 23605,
    'build': 6515,
    'raster': 4386,
    'vsyncOverhead': 12625,
  };

  static const uiEventAsString =
      '''  Animator::BeginFrame [713836200161 μs - 713836206957 μs]
    LAYOUT (root) [713836202351 μs - 713836202383 μs]
      LAYOUT [713836202373 μs - 713836202380 μs]
    UPDATING COMPOSITING BITS (root) [713836202387 μs - 713836202402 μs]
      UPDATING COMPOSITING BITS [713836202397 μs - 713836202400 μs]
    PAINT (root) [713836202408 μs - 713836202429 μs]
      PAINT [713836202422 μs - 713836202427 μs]
    COMPOSITING [713836202440 μs - 713836206727 μs]
      Animator::Render [713836206671 μs - 713836206714 μs]
    SEMANTICS (root) [713836206752 μs - 713836206828 μs]
      SEMANTICS [713836206785 μs - 713836206825 μs]
    FINALIZE TREE [713836206834 μs - 713836206878 μs]
    POST_FRAME [713836206903 μs - 713836206925 μs]
''';

  static const rasterEventAsString =
      '''  Rasterizer::DoDraw [713836206748 μs - 713836211160 μs]
    Rasterizer::DrawToSurfaces [713836206750 μs - 713836211143 μs]
      GPUSurfaceMetalImpeller::AcquireFrame [713836206755 μs - 713836210203 μs]
        SurfaceMTL::WrapCurrentMetalLayerDrawable [713836206763 μs - 713836210196 μs]
          WaitForNextDrawable [713836206764 μs - 713836210193 μs]
      CompositorContext::ScopedFrame::Raster [713836210206 μs - 713836210251 μs]
        LayerTree::Preroll [713836210219 μs - 713836210225 μs]
        IOSExternalViewEmbedder::PostPrerollAction [713836210226 μs - 713836210226 μs]
        LayerTree::Paint [713836210240 μs - 713836210250 μs]
      SurfaceFrame::Submit [713836210251 μs - 713836211118 μs]
        SurfaceFrame::BuildDisplayList [713836210251 μs - 713836210254 μs]
        DisplayListDispatcher::EndRecordingAsPicture [713836210613 μs - 713836210616 μs]
        Renderer::Render [713836210616 μs - 713836211105 μs]
          EntityPass::OnRender [713836210642 μs - 713836211061 μs]
            CreateGlyphAtlas [713836210893 μs - 713836210899 μs]
''';

  static final uiEvent = animatorBeginFrameEvent
    ..addAllChildren([
      layoutRootEvent..addChild(layoutEvent),
      updatingCompositingBitsRootEvent..addChild(updatingCompositingBitsEvent),
      paintRootEvent..addChild(paintEvent),
      compositingEvent..addChild(animatorRenderEvent),
      semanticsRootEvent..addChild(semanticsEvent),
      finalizeTreeEvent,
      postFrameEvent,
    ]);

  static FlutterTimelineEvent uiEventWithExtras = animatorBeginFrameEvent
      .shallowCopy()
    ..addAllChildren([
      buildEvent, // Extra, not part of original trace.
      layoutRootEvent.shallowCopy()
        ..addChild(
          layoutEvent.shallowCopy()
            ..addAllChildren(
              [
                buildChild1Event, // Extra, not part of original trace.
                buildChild2Event, // Extra, not part of original trace.

                renderBoxIntrinsics, // Extra, not part of original trace.
                renderFlexIntrinsics, // Extra, not part of original trace.
              ],
            ),
        ),
      updatingCompositingBitsRootEvent.shallowCopy()
        ..addChild(updatingCompositingBitsEvent.shallowCopy()),
      paintRootEvent.shallowCopy()
        ..addChild(
          paintEvent.shallowCopy()
            ..addChild(
              saveLayerEvent, // Extra, not part of original trace.
            ),
        ),
      compositingEvent.shallowCopy()
        ..addChild(animatorRenderEvent.shallowCopy()),
      semanticsRootEvent.shallowCopy()..addChild(semanticsEvent.shallowCopy()),
      finalizeTreeEvent.shallowCopy(),
      postFrameEvent.shallowCopy(),
    ]);

  static final animatorBeginFrameEvent = testTimelineEvent(
    name: 'Animator::BeginFrame',
    type: TimelineEventType.ui,
    args: {'frame_number': '4'},
    endArgs: {},
    startMicros: 713836200161,
    endMicros: 713836206957,
  );
  static final layoutRootEvent = testTimelineEvent(
    name: 'LAYOUT (root)',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202351,
    endMicros: 713836202383,
  );
  static final layoutEvent = testTimelineEvent(
    name: 'LAYOUT',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202352,
    endMicros: 713836202382,
  );
  static final updatingCompositingBitsRootEvent = testTimelineEvent(
    name: 'UPDATING COMPOSITING BITS (root)',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202387,
    endMicros: 713836202402,
  );
  static final updatingCompositingBitsEvent = testTimelineEvent(
    name: 'UPDATING COMPOSITING BITS',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202397,
    endMicros: 713836202400,
  );
  static final paintRootEvent = testTimelineEvent(
    name: 'PAINT (root)',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202408,
    endMicros: 713836202429,
  );
  static final paintEvent = testTimelineEvent(
    name: 'PAINT',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202422,
    endMicros: 713836202427,
  );
  static final compositingEvent = testTimelineEvent(
    name: 'COMPOSITING',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202440,
    endMicros: 713836206727,
  );
  static final animatorRenderEvent = testTimelineEvent(
    name: 'Animator::Render',
    type: TimelineEventType.ui,
    args: {
      'frame_number': '4',
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836206671,
    endMicros: 713836206714,
  );
  static final semanticsRootEvent = testTimelineEvent(
    name: 'SEMANTICS (root)',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836206752,
    endMicros: 713836206828,
  );
  static final semanticsEvent = testTimelineEvent(
    name: 'SEMANTICS',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836206785,
    endMicros: 713836206825,
  );
  static final finalizeTreeEvent = testTimelineEvent(
    name: 'FINALIZE TREE',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836206834,
    endMicros: 713836206878,
  );
  static final postFrameEvent = testTimelineEvent(
    name: 'POST_FRAME',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836206903,
    endMicros: 713836206925,
  );

  // Extra events for this frame that were not part of the original trace.
  static final buildEvent = testTimelineEvent(
    name: 'BUILD',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836201251,
    endMicros: 713836202251,
  );
  static final buildChild1Event = testTimelineEvent(
    name: 'BUILD',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202374,
    endMicros: 713836202376,
  );
  static final buildChild2Event = testTimelineEvent(
    name: 'BUILD',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836202377,
    endMicros: 713836202379,
  );
  static final saveLayerEvent = testTimelineEvent(
    name: 'ui.Canvas::saveLayer (Recorded)',
    type: TimelineEventType.ui,
    args: {
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {},
    startMicros: 713836202423,
    endMicros: 713836202426,
  );
  static final renderBoxIntrinsics = testTimelineEvent(
    name: 'RenderBox intrinsics',
    type: TimelineEventType.raster,
    args: {
      'intrinsics dimension': 'maxWidth',
      'intrinsics argument': '500.0',
      'isolateId': 'isolates/3152451962062387',
      'isolateGroupId': 'isolateGroups/12069909095439033329',
    },
    endArgs: {},
    startMicros: 713836202354,
    endMicros: 713836202356,
  );
  static final renderFlexIntrinsics = testTimelineEvent(
    name: 'RenderFlex intrinsics',
    type: TimelineEventType.raster,
    args: {
      'intrinsics dimension': 'maxHeight',
      'intrinsics argument': '375.0',
      'isolateId': 'isolates/3152451962062387',
      'isolateGroupId': 'isolateGroups/12069909095439033329',
    },
    endArgs: {},
    startMicros: 713836202358,
    endMicros: 713836202360,
  );

  static final rasterEvent = rasterizerDoDrawEvent
    ..addChild(
      rasterizerDrawToSurfacesEvent
        ..addAllChildren([
          gpuSurfaceMetalImpellerAcquireFrameEvent
            ..addChild(
              surfaceMTLWrapCurrentMetalLayerDrawableEvent
                ..addChild(
                  waitForNextDrawableEvent,
                ),
            ),
          compositorContextScopedFrameRasterEvent
            ..addAllChildren([
              layerTreePrerollEvent,
              iOSExternalViewEmbedderPostPrerollActionEvent,
              layerTreePaintEvent,
            ]),
          surfaceFrameSubmitEvent
            ..addAllChildren([
              surfaceFrameBuildDisplayListEvent,
              displayListDispatcherEndRecordingAsPictureEvent,
              rendererRenderEvent
                ..addChild(
                  entityPassOnRenderEvent
                    ..addChild(
                      createGlyphAtlasEvent,
                    ),
                ),
            ]),
        ]),
    );

  // static final rasterEventWithExtras = rasterizerDoDrawEvent.shallowCopy()
  //   ..addChild(
  //     rasterizerDrawToSurfacesEvent.shallowCopy()
  //       ..addAllChildren([
  //         gpuSurfaceMetalImpellerAcquireFrameEvent.shallowCopy()
  //           ..addChild(
  //             surfaceMTLWrapCurrentMetalLayerDrawableEvent.shallowCopy()
  //               ..addChild(
  //                 waitForNextDrawableEvent.shallowCopy(),
  //               ),
  //           ),
  //         compositorContextScopedFrameRasterEvent.shallowCopy()
  //           ..addAllChildren([
  //             layerTreePrerollEvent.shallowCopy(),
  //             iOSExternalViewEmbedderPostPrerollActionEvent.shallowCopy(),
  //             layerTreePaintEvent.shallowCopy()
  //               ..addAllChildren([
  //                 renderBoxIntrinsics, // Extra, not part of original trace.
  //                 renderFlexIntrinsics, // Extra, not part of original trace.
  //               ]),
  //           ]),
  //         surfaceFrameSubmitEvent.shallowCopy()
  //           ..addAllChildren([
  //             surfaceFrameBuildDisplayListEvent.shallowCopy(),
  //             displayListDispatcherEndRecordingAsPictureEvent.shallowCopy(),
  //             rendererRenderEvent.shallowCopy()
  //               ..addChild(
  //                 entityPassOnRenderEvent.shallowCopy()
  //                   ..addChild(
  //                     createGlyphAtlasEvent.shallowCopy(),
  //                   ),
  //               ),
  //           ]),
  //       ]),
  //   );

  static final rasterizerDoDrawEvent = testTimelineEvent(
    name: 'Rasterizer::DoDraw',
    type: TimelineEventType.raster,
    args: {'frame_number': '4'},
    endArgs: {},
    startMicros: 713836206748,
    endMicros: 713836211160,
  );
  static final rasterizerDrawToSurfacesEvent = testTimelineEvent(
    name: 'Rasterizer::DrawToSurfaces',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836206750,
    endMicros: 713836211143,
  );
  static final gpuSurfaceMetalImpellerAcquireFrameEvent = testTimelineEvent(
    name: 'GPUSurfaceMetalImpeller::AcquireFrame',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836206755,
    endMicros: 713836210203,
  );
  static final surfaceMTLWrapCurrentMetalLayerDrawableEvent = testTimelineEvent(
    name: 'SurfaceMTL::WrapCurrentMetalLayerDrawable',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836206763,
    endMicros: 713836210196,
  );
  static final waitForNextDrawableEvent = testTimelineEvent(
    name: 'WaitForNextDrawable',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836206764,
    endMicros: 713836210193,
  );
  static final compositorContextScopedFrameRasterEvent = testTimelineEvent(
    name: 'CompositorContext::ScopedFrame::Raster',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210206,
    endMicros: 713836210251,
  );
  static final layerTreePrerollEvent = testTimelineEvent(
    name: 'LayerTree::Preroll',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210219,
    endMicros: 713836210225,
  );
  static final iOSExternalViewEmbedderPostPrerollActionEvent =
      testTimelineEvent(
    name: 'IOSExternalViewEmbedder::PostPrerollAction',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210226,
    endMicros: 713836210226,
  );
  static final layerTreePaintEvent = testTimelineEvent(
    name: 'LayerTree::Paint',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210240,
    endMicros: 713836210250,
  );
  static final surfaceFrameSubmitEvent = testTimelineEvent(
    name: 'SurfaceFrame::Submit',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210251,
    endMicros: 713836211118,
  );
  static final surfaceFrameBuildDisplayListEvent = testTimelineEvent(
    name: 'SurfaceFrame::BuildDisplayList',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210251,
    endMicros: 713836210254,
  );
  static final displayListDispatcherEndRecordingAsPictureEvent =
      testTimelineEvent(
    name: 'DisplayListDispatcher::EndRecordingAsPicture',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210613,
    endMicros: 713836210616,
  );
  static final rendererRenderEvent = testTimelineEvent(
    name: 'Renderer::Render',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210616,
    endMicros: 713836211105,
  );
  static final entityPassOnRenderEvent = testTimelineEvent(
    name: 'EntityPass::OnRender',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210642,
    endMicros: 713836211061,
  );
  static final createGlyphAtlasEvent = testTimelineEvent(
    name: 'CreateGlyphAtlas',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836210893,
    endMicros: 713836210899,
  );
}

/// Data for Frame (id: 6)
abstract class FlutterFrame6 {
  static final frame = FlutterFrame.fromJson(_frameJson)
    ..setEventFlow(uiEvent)
    ..setEventFlow(rasterEvent);

  static final frameWithoutTimelineEvents = FlutterFrame.fromJson(_frameJson);

  static const _frameJson = {
    'number': 6,
    'startTime': 713836329948,
    'elapsed': 2843,
    'build': 745,
    'raster': 883,
    'vsyncOverhead': 1108,
  };

  static const uiEventAsString =
      '''  Animator::BeginFrame [713836329948 μs - 713836331003 μs]
    LAYOUT (root) [713836330239 μs - 713836330280 μs]
      LAYOUT [713836330262 μs - 713836330277 μs]
    UPDATING COMPOSITING BITS (root) [713836330284 μs - 713836330307 μs]
      UPDATING COMPOSITING BITS [713836330302 μs - 713836330306 μs]
    PAINT (root) [713836330324 μs - 713836330348 μs]
      PAINT [713836330337 μs - 713836330346 μs]
    COMPOSITING [713836330357 μs - 713836330723 μs]
      Animator::Render [713836330691 μs - 713836330716 μs]
    SEMANTICS (root) [713836330738 μs - 713836330844 μs]
      SEMANTICS [713836330783 μs - 713836330842 μs]
    FINALIZE TREE [713836330848 μs - 713836330920 μs]
    POST_FRAME [713836330964 μs - 713836330989 μs]
''';

  static const rasterEventAsString =
      '''  Rasterizer::DoDraw [713836330790 μs - 713836331692 μs]
    Rasterizer::DrawToSurfaces [713836330791 μs - 713836331684 μs]
      GPUSurfaceMetalImpeller::AcquireFrame [713836330801 μs - 713836330844 μs]
        SurfaceMTL::WrapCurrentMetalLayerDrawable [713836330814 μs - 713836330839 μs]
          WaitForNextDrawable [713836330817 μs - 713836330836 μs]
      CompositorContext::ScopedFrame::Raster [713836330846 μs - 713836330888 μs]
        LayerTree::Preroll [713836330862 μs - 713836330870 μs]
        IOSExternalViewEmbedder::PostPrerollAction [713836330870 μs - 713836330870 μs]
        LayerTree::Paint [713836330870 μs - 713836330888 μs]
      SurfaceFrame::Submit [713836330888 μs - 713836331669 μs]
        SurfaceFrame::BuildDisplayList [713836330889 μs - 713836330894 μs]
        DisplayListDispatcher::EndRecordingAsPicture [713836331274 μs - 713836331276 μs]
        Renderer::Render [713836331277 μs - 713836331661 μs]
          EntityPass::OnRender [713836331302 μs - 713836331633 μs]
            CreateGlyphAtlas [713836331499 μs - 713836331505 μs]
''';

  static final uiEvent = animatorBeginFrameEvent
    ..addAllChildren([
      layoutRootEvent..addChild(layoutEvent),
      updatingCompositingBitsRootEvent..addChild(updatingCompositingBitsEvent),
      paintRootEvent..addChild(paintEvent),
      compositingEvent..addChild(animatorRenderEvent),
      semanticsRootEvent..addChild(semanticsEvent),
      finalizeTreeEvent,
      postFrameEvent,
    ]);

  static final animatorBeginFrameEvent = testTimelineEvent(
    name: 'Animator::BeginFrame',
    type: TimelineEventType.ui,
    args: {'frame_number': '6'},
    endArgs: {},
    startMicros: 713836329948,
    endMicros: 713836331003,
  );

  static final layoutRootEvent = testTimelineEvent(
    name: 'LAYOUT (root)',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330239,
    endMicros: 713836330280,
  );

  static final layoutEvent = testTimelineEvent(
    name: 'LAYOUT',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330262,
    endMicros: 713836330277,
  );

  static final updatingCompositingBitsRootEvent = testTimelineEvent(
    name: 'UPDATING COMPOSITING BITS (root)',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330284,
    endMicros: 713836330307,
  );

  static final updatingCompositingBitsEvent = testTimelineEvent(
    name: 'UPDATING COMPOSITING BITS',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330302,
    endMicros: 713836330306,
  );

  static final paintRootEvent = testTimelineEvent(
    name: 'PAINT (root)',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330324,
    endMicros: 713836330348,
  );

  static final paintEvent = testTimelineEvent(
    name: 'PAINT',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330337,
    endMicros: 713836330346,
  );

  static final compositingEvent = testTimelineEvent(
    name: 'COMPOSITING',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330357,
    endMicros: 713836330723,
  );

  static final animatorRenderEvent = testTimelineEvent(
    name: 'Animator::Render',
    type: TimelineEventType.ui,
    args: {
      'frame_number': '6',
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330691,
    endMicros: 713836330716,
  );

  static final semanticsRootEvent = testTimelineEvent(
    name: 'SEMANTICS (root)',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330738,
    endMicros: 713836330844,
  );

  static final semanticsEvent = testTimelineEvent(
    name: 'SEMANTICS',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330783,
    endMicros: 713836330842,
  );

  static final finalizeTreeEvent = testTimelineEvent(
    name: 'FINALIZE TREE',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330848,
    endMicros: 713836330920,
  );

  static final postFrameEvent = testTimelineEvent(
    name: 'POST_FRAME',
    type: TimelineEventType.ui,
    args: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    endArgs: {
      'Dart Arguments': {},
      'isolateId': 'isolates/7995498257369867',
      'isolateGroupId': 'isolateGroups/828486766866208',
    },
    startMicros: 713836330964,
    endMicros: 713836330989,
  );

  static final rasterEvent = rasterizerDoDrawEvent
    ..addChild(
      rasterizerDrawToSurfacesEvent
        ..addAllChildren([
          gpuSurfaceMetalImpellerAcquireFrameEvent
            ..addChild(
              surfaceMTLWrapCurrentMetalLayerDrawableEvent
                ..addChild(
                  waitForNextDrawableEvent,
                ),
            ),
          compositorContextScopedFrameRasterEvent
            ..addAllChildren([
              layerTreePrerollEvent,
              iOSExternalViewEmbedderPostPrerollActionEvent,
              layerTreePaintEvent,
            ]),
          surfaceFrameSubmitEvent
            ..addAllChildren([
              surfaceFrameBuildDisplayListEvent,
              displayListDispatcherEndRecordingAsPictureEvent,
              rendererRenderEvent
                ..addChild(
                  entityPassOnRenderEvent
                    ..addChild(
                      createGlyphAtlasEvent,
                    ),
                ),
            ]),
        ]),
    );

  static final rasterizerDoDrawEvent = testTimelineEvent(
    name: 'Rasterizer::DoDraw',
    type: TimelineEventType.raster,
    args: {'frame_number': '6'},
    endArgs: {},
    startMicros: 713836330790,
    endMicros: 713836331692,
  );

  static final rasterizerDrawToSurfacesEvent = testTimelineEvent(
    name: 'Rasterizer::DrawToSurfaces',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330791,
    endMicros: 713836331684,
  );

  static final gpuSurfaceMetalImpellerAcquireFrameEvent = testTimelineEvent(
    name: 'GPUSurfaceMetalImpeller::AcquireFrame',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330801,
    endMicros: 713836330844,
  );

  static final surfaceMTLWrapCurrentMetalLayerDrawableEvent = testTimelineEvent(
    name: 'SurfaceMTL::WrapCurrentMetalLayerDrawable',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330814,
    endMicros: 713836330839,
  );

  static final waitForNextDrawableEvent = testTimelineEvent(
    name: 'WaitForNextDrawable',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330817,
    endMicros: 713836330836,
  );

  static final compositorContextScopedFrameRasterEvent = testTimelineEvent(
    name: 'CompositorContext::ScopedFrame::Raster',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330846,
    endMicros: 713836330888,
  );

  static final layerTreePrerollEvent = testTimelineEvent(
    name: 'LayerTree::Preroll',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330862,
    endMicros: 713836330870,
  );

  static final iOSExternalViewEmbedderPostPrerollActionEvent =
      testTimelineEvent(
    name: 'IOSExternalViewEmbedder::PostPrerollAction',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330870,
    endMicros: 713836330870,
  );

  static final layerTreePaintEvent = testTimelineEvent(
    name: 'LayerTree::Paint',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330870,
    endMicros: 713836330888,
  );

  static final surfaceFrameSubmitEvent = testTimelineEvent(
    name: 'SurfaceFrame::Submit',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330888,
    endMicros: 713836331669,
  );

  static final surfaceFrameBuildDisplayListEvent = testTimelineEvent(
    name: 'SurfaceFrame::BuildDisplayList',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836330889,
    endMicros: 713836330894,
  );

  static final displayListDispatcherEndRecordingAsPictureEvent =
      testTimelineEvent(
    name: 'DisplayListDispatcher::EndRecordingAsPicture',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836331274,
    endMicros: 713836331276,
  );

  static final rendererRenderEvent = testTimelineEvent(
    name: 'Renderer::Render',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836331277,
    endMicros: 713836331661,
  );

  static final entityPassOnRenderEvent = testTimelineEvent(
    name: 'EntityPass::OnRender',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836331302,
    endMicros: 713836331633,
  );

  static final createGlyphAtlasEvent = testTimelineEvent(
    name: 'CreateGlyphAtlas',
    type: TimelineEventType.raster,
    args: {},
    endArgs: {},
    startMicros: 713836331499,
    endMicros: 713836331505,
  );
}
