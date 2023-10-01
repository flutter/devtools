// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../service/service_extensions.dart' as extensions;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/connected_app.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/utils.dart';
import '../../performance_controller.dart';
import '../../performance_utils.dart';
import '../controls/enhance_tracing/enhance_tracing.dart';
import '../controls/enhance_tracing/enhance_tracing_controller.dart';
import '../controls/enhance_tracing/enhance_tracing_model.dart';
import 'frame_analysis_model.dart';

class FrameHints extends StatelessWidget {
  const FrameHints({
    Key? key,
    required this.frameAnalysis,
    required this.enhanceTracingController,
  }) : super(key: key);

  final FrameAnalysis frameAnalysis;

  final EnhanceTracingController enhanceTracingController;

  @override
  Widget build(BuildContext context) {
    final performanceController = Provider.of<PerformanceController>(context);
    final frame = frameAnalysis.frame;
    final displayRefreshRate =
        performanceController.flutterFramesController.displayRefreshRate.value;
    final showUiJankHints = frame.isUiJanky(displayRefreshRate);
    final showRasterJankHints = frame.isRasterJanky(displayRefreshRate);
    if (!(showUiJankHints || showRasterJankHints)) {
      return const Text('No suggestions for this frame - no jank detected.');
    }

    final saveLayerCount = frameAnalysis.saveLayerCount;
    final intrinsicOperationsCount = frameAnalysis.intrinsicOperationsCount;

    final uiHints = showUiJankHints
        ? [
            const Text('UI Jank Detected'),
            const SizedBox(height: denseSpacing),
            EnhanceTracingHint(
              longestPhase: frameAnalysis.longestUiPhase,
              enhanceTracingState: frameAnalysis.frame.enhanceTracingState,
              enhanceTracingController: enhanceTracingController,
            ),
            const SizedBox(height: densePadding),
            if (intrinsicOperationsCount > 0)
              IntrinsicOperationsHint(intrinsicOperationsCount),
          ]
        : [];
    final rasterHints = showRasterJankHints
        ? [
            const Text('Raster Jank Detected'),
            const SizedBox(height: denseSpacing),
            if (saveLayerCount > 0) CanvasSaveLayerHint(saveLayerCount),
            const SizedBox(height: denseSpacing),
            if (frame.hasShaderTime)
              ShaderCompilationHint(shaderTime: frame.shaderDuration),
            const SizedBox(height: denseSpacing),
            const RasterStatsHint(),
          ]
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...uiHints,
        if (showUiJankHints && showRasterJankHints)
          const SizedBox(height: defaultSpacing),
        ...rasterHints,
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({Key? key, required this.message}) : super(key: key);

  final Widget message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.lightbulb_outline,
          size: defaultIconSize,
        ),
        const SizedBox(width: denseSpacing),
        Expanded(child: message),
      ],
    );
  }
}

@visibleForTesting
class EnhanceTracingHint extends StatelessWidget {
  const EnhanceTracingHint({
    Key? key,
    required this.longestPhase,
    required this.enhanceTracingState,
    required this.enhanceTracingController,
  }) : super(key: key);

  /// The longest [FramePhase] for the [FlutterFrame] this hint is for.
  final FramePhase longestPhase;

  /// The [EnhanceTracingState] that was active while drawing the [FlutterFrame]
  /// that this hint is for.
  final EnhanceTracingState? enhanceTracingState;

  final EnhanceTracingController enhanceTracingController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Hint(
      message: RichText(
        maxLines: 2,
        text: TextSpan(
          text: '',
          children: [
            TextSpan(
              text: longestPhase.title,
              style: theme.fixedFontStyle,
            ),
            TextSpan(
              text: ' was the longest UI phase in this frame. ',
              style: theme.regularTextStyle,
            ),
            ..._hintForPhase(longestPhase, theme),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _hintForPhase(
    FramePhase phase,
    ThemeData theme,
  ) {
    final phaseType = phase.type;
    // TODO(kenz): when [enhanceTracingState] is not available, use heuristics
    // to detect whether tracing was enhanced for a frame (e.g. the depth or
    // quantity of child events under build / layout / paint).
    final tracingEnhanced =
        enhanceTracingState?.enhancedFor(phaseType) ?? false;
    switch (phaseType) {
      case FramePhaseType.build:
        return _enhanceTracingHint(
          settingTitle: extensions.profileWidgetBuilds.title,
          eventDescription: 'widget built',
          tracingEnhanced: tracingEnhanced,
          theme: theme,
        );
      case FramePhaseType.layout:
        return _enhanceTracingHint(
          settingTitle: extensions.profileRenderObjectLayouts.title,
          eventDescription: 'render object laid out',
          tracingEnhanced: tracingEnhanced,
          theme: theme,
        );
      case FramePhaseType.paint:
        return _enhanceTracingHint(
          settingTitle: extensions.profileRenderObjectPaints.title,
          eventDescription: 'render object painted',
          tracingEnhanced: tracingEnhanced,
          theme: theme,
        );
      default:
        return [];
    }
  }

  List<InlineSpan> _enhanceTracingHint({
    required String settingTitle,
    required String eventDescription,
    required bool tracingEnhanced,
    required ThemeData theme,
  }) {
    if (tracingEnhanced) {
      return [
        TextSpan(
          text: 'Since "$settingTitle" was enabled while this frame was drawn, '
              'you should be able to see timeline events for each '
              '$eventDescription.',
          style: theme.regularTextStyle,
        ),
      ];
    }
    final enhanceTracingButton = WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
        child: SmallEnhanceTracingButton(
          enhanceTracingController: enhanceTracingController,
        ),
      ),
    );
    return [
      TextSpan(
        text: 'Consider enabling "$settingTitle" from the ',
        style: theme.regularTextStyle,
      ),
      enhanceTracingButton,
      TextSpan(
        text: ' options above and reproducing the behavior in your app.',
        style: theme.regularTextStyle,
      ),
    ];
  }
}

@visibleForTesting
class SmallEnhanceTracingButton extends StatelessWidget {
  const SmallEnhanceTracingButton({
    Key? key,
    required this.enhanceTracingController,
  }) : super(key: key);

  final EnhanceTracingController enhanceTracingController;

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton(
      label: EnhanceTracingButton.title,
      icon: EnhanceTracingButton.icon,
      gaScreen: gac.performance,
      gaSelection: gac.PerformanceEvents.enhanceTracingButtonSmall.name,
      onPressed: enhanceTracingController.showEnhancedTracingMenu,
    );
  }
}

@visibleForTesting
class IntrinsicOperationsHint extends StatelessWidget {
  const IntrinsicOperationsHint(
    this.intrinsicOperationsCount, {
    Key? key,
  }) : super(key: key);

  static const _intrinsicOperationsDocs =
      'https://docs.flutter.dev/perf/best-practices#minimize-layout-passes-caused-by-intrinsic-operations';

  final int intrinsicOperationsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Hint(
      message: _ExpensiveOperationHint(
        docsUrl: _intrinsicOperationsDocs,
        gaScreenName: gac.performance,
        gaSelectedItemDescription:
            gac.PerformanceDocs.intrinsicOperationsDocs.name,
        message: TextSpan(
          children: [
            TextSpan(
              text: 'Intrinsic',
              style: theme.fixedFontStyle,
            ),
            TextSpan(
              text: ' passes were performed $intrinsicOperationsCount '
                  '${pluralize('time', intrinsicOperationsCount)} during this '
                  'frame.',
              style: theme.regularTextStyle,
            ),
          ],
        ),
      ),
    );
  }
}

// TODO(kenz): if the 'profileRenderObjectPaints' service extension is disabled,
// suggest that the user turn it on to get information about the render objects
// that are calling saveLayer. If the event has render object information in the
// args, display it in the hint.
@visibleForTesting
class CanvasSaveLayerHint extends StatelessWidget {
  const CanvasSaveLayerHint(
    this.saveLayerCount, {
    Key? key,
  }) : super(key: key);

  static const _saveLayerDocs =
      'https://docs.flutter.dev/perf/best-practices#use-savelayer-thoughtfully';

  final int saveLayerCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Hint(
      message: _ExpensiveOperationHint(
        docsUrl: _saveLayerDocs,
        gaScreenName: gac.performance,
        gaSelectedItemDescription: gac.PerformanceDocs.canvasSaveLayerDocs.name,
        message: TextSpan(
          children: [
            TextSpan(
              text: 'Canvas.saveLayer()',
              style: theme.fixedFontStyle,
            ),
            TextSpan(
              text: ' was called $saveLayerCount '
                  '${pluralize('time', saveLayerCount)} during this frame.',
              style: theme.regularTextStyle,
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
class ShaderCompilationHint extends StatelessWidget {
  const ShaderCompilationHint({
    Key? key,
    required this.shaderTime,
  }) : super(key: key);

  final Duration shaderTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Hint(
      message: _ExpensiveOperationHint(
        docsUrl: preCompileShadersDocsUrl,
        gaScreenName: gac.performance,
        gaSelectedItemDescription:
            gac.PerformanceDocs.shaderCompilationDocs.name,
        message: TextSpan(
          children: [
            TextSpan(
              text: durationText(
                shaderTime,
                unit: DurationDisplayUnit.milliseconds,
              ),
              style: theme.fixedFontStyle,
            ),
            TextSpan(
              text: ' of shader compilation occurred during this frame.',
              style: theme.regularTextStyle,
            ),
          ],
        ),
        childrenSpans: serviceConnection.serviceManager.connectedApp!.isIosApp
            ? [
                TextSpan(
                  text:
                      ' Note: pre-compiling shaders is a legacy solution with many '
                      'pitfalls. Try ',
                  style: theme.regularTextStyle,
                ),
                LinkTextSpan(
                  link: Link(
                    display: 'Impeller',
                    url: impellerWikiUrl,
                    gaScreenName: gac.performance,
                    gaSelectedItemDescription:
                        gac.PerformanceDocs.impellerWikiLink.name,
                  ),
                  context: context,
                ),
                TextSpan(
                  text: ' instead!',
                  style: theme.regularTextStyle,
                ),
              ]
            : [],
      ),
    );
  }
}

@visibleForTesting
class RasterStatsHint extends StatelessWidget {
  const RasterStatsHint({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Hint(
      message: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Consider using the',
              style: theme.regularTextStyle,
            ),
            TextSpan(
              text: ' Raster Stats ',
              style: theme.subtleFixedFontStyle,
            ),
            TextSpan(
              text: 'tab to identify rendering layers that are expensive to '
                  'rasterize.',
              style: theme.regularTextStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensiveOperationHint extends StatelessWidget {
  const _ExpensiveOperationHint({
    Key? key,
    required this.message,
    required this.docsUrl,
    required this.gaScreenName,
    required this.gaSelectedItemDescription,
    this.childrenSpans = const <TextSpan>[],
  }) : super(key: key);

  final TextSpan message;
  final String docsUrl;
  final String gaScreenName;
  final String gaSelectedItemDescription;
  final List<TextSpan> childrenSpans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        children: [
          message,
          TextSpan(
            text: ' This may ',
            style: theme.regularTextStyle,
          ),
          LinkTextSpan(
            context: context,
            link: Link(
              display: 'negatively affect your app\'s performance',
              url: docsUrl,
              gaScreenName: gaScreenName,
              gaSelectedItemDescription:
                  'frameAnalysis_$gaSelectedItemDescription',
            ),
          ),
          TextSpan(
            text: '.',
            style: theme.regularTextStyle,
          ),
          ...childrenSpans,
        ],
      ),
    );
  }
}
