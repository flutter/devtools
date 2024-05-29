// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../service/service_extension_widgets.dart';
import '../../../../service/service_extensions.dart' as extensions;
import '../../../../shared/feature_flags.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/primitives/utils.dart';
import '../controls/enhance_tracing/enhance_tracing_controller.dart';
import '../flutter_frames/flutter_frame_model.dart';
import '../rebuild_stats/rebuild_stats.dart';
import '../rebuild_stats/rebuild_stats_model.dart';
import 'frame_hints.dart';
import 'frame_time_visualizer.dart';

class FlutterFrameAnalysisView extends StatelessWidget {
  const FlutterFrameAnalysisView({
    super.key,
    required this.frame,
    required this.enhanceTracingController,
    required this.rebuildCountModel,
    required this.displayRefreshRateNotifier,
  });

  final FlutterFrame frame;

  final EnhanceTracingController enhanceTracingController;

  final RebuildCountModel rebuildCountModel;

  final ValueListenable<double> displayRefreshRateNotifier;

  @override
  Widget build(BuildContext context) {
    final frameAnalysis = frame.frameAnalysis;
    final rebuilds = rebuildCountModel.rebuildsForFrame(frame.id);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Flutter frame: ',
                  style: theme.regularTextStyle,
                ),
                TextSpan(
                  text: '${frame.id}',
                  style: theme.fixedFontStyle
                      .copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          const PaddedDivider(
            padding: EdgeInsets.only(bottom: denseSpacing),
          ),
          if (frameAnalysis == null) ...[
            const Text(
              'No timeline event analysis data available for this frame. This '
              'means that the timeline events for this frame occurred too long '
              'ago and DevTools could not access them. To avoid this, open the '
              'DevTools Performance page earlier.',
            ),
          ] else ...[
            // TODO(jacobr): we might have so many frame hints that this content
            // needs to scroll. Supporting that would be hard as the RebuildTable
            // also needs to scroll and the devtools table functionality does not
            // support the shrinkWrap property and has features that would make
            //it difficult to handle robustly.
            ValueListenableBuilder(
              valueListenable: displayRefreshRateNotifier,
              builder: (context, refreshRate, _) {
                return FrameHints(
                  frameAnalysis: frameAnalysis,
                  enhanceTracingController: enhanceTracingController,
                  displayRefreshRate: refreshRate,
                );
              },
            ),
            const PaddedDivider(
              padding: EdgeInsets.symmetric(vertical: denseSpacing),
            ),
            FrameTimeVisualizer(frameAnalysis: frameAnalysis),
          ],
          if (FeatureFlags.widgetRebuildStats) ...[
            const PaddedDivider(
              padding: EdgeInsets.only(top: denseSpacing),
            ),
            if (rebuilds.isNullOrEmpty)
              ValueListenableBuilder<bool>(
                valueListenable: serviceConnection
                    .serviceManager.serviceExtensionManager
                    .hasServiceExtension(
                  extensions.trackWidgetBuildCounts.extension,
                ),
                builder: (context, hasExtension, _) {
                  if (hasExtension) {
                    return Row(
                      children: [
                        const Text(
                          'To see widget rebuilds for Flutter frames, enable',
                        ),
                        Flexible(
                          child: ServiceExtensionCheckbox(
                            serviceExtension: extensions.trackWidgetBuildCounts,
                            showDescription: false,
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            if (rebuilds == null)
              const Text(
                'Rebuild information not available for this frame.',
              )
            else if (rebuilds.isEmpty)
              const Text(
                'No widget rebuilds occurred for widgets that were directly '
                'created in your project.',
              )
            else
              Expanded(
                child: RebuildTable(
                  metricNames: const ['Rebuild Count'],
                  metrics: combineStats([rebuilds]),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
