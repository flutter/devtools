// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../service/service_extension_widgets.dart';
import '../../../../service/service_extensions.dart' as extensions;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/feature_flags.dart';
import '../../../../shared/globals.dart';
import '../controls/enhance_tracing/enhance_tracing_controller.dart';
import '../rebuild_stats/rebuild_stats.dart';
import '../rebuild_stats/rebuild_stats_model.dart';
import 'frame_analysis_model.dart';
import 'frame_hints.dart';
import 'frame_time_visualizer.dart';

class FlutterFrameAnalysisView extends StatelessWidget {
  const FlutterFrameAnalysisView({
    Key? key,
    required this.frameAnalysis,
    required this.enhanceTracingController,
    required this.rebuildCountModel,
  }) : super(key: key);

  final FrameAnalysis? frameAnalysis;

  final EnhanceTracingController enhanceTracingController;

  final RebuildCountModel rebuildCountModel;

  @override
  Widget build(BuildContext context) {
    final frameAnalysis = this.frameAnalysis;
    if (frameAnalysis == null) {
      return const CenteredMessage(
        'No analysis data available for this frame. This means that the '
        'timeline events\nfor this frame occurred too long ago and DevTools '
        'could not access them.\n\nTo avoid this, open the DevTools Performance '
        'page earlier.',
      );
    }
    final rebuilds = rebuildCountModel.rebuildsForFrame(frameAnalysis.frame.id);
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
                  text: '${frameAnalysis.frame.id}',
                  style: theme.fixedFontStyle
                      .copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
          const PaddedDivider(
            padding: EdgeInsets.only(
              bottom: denseSpacing,
            ),
          ),
          // TODO(jacobr): we might have so many frame hints that this content
          // needs to scroll. Supporting that would be hard as the RebuildTable
          // also needs to scroll and the devtools table functionality does not
          // support the shrinkWrap property and has features that would make
          //it difficult to handle robustly.
          FrameHints(
            frameAnalysis: frameAnalysis,
            enhanceTracingController: enhanceTracingController,
          ),
          const PaddedDivider(
            padding: EdgeInsets.only(
              top: denseSpacing,
              bottom: denseSpacing,
            ),
          ),
          FrameTimeVisualizer(frameAnalysis: frameAnalysis),
          const PaddedDivider(
            padding: EdgeInsets.only(
              top: denseSpacing,
              bottom: denseSpacing,
            ),
          ),

          if (FeatureFlags.widgetRebuildstats) ...[
            if (rebuilds == null || rebuilds.isEmpty)
              ValueListenableBuilder<bool>(
                valueListenable: serviceConnection
                    .serviceManager.serviceExtensionManager
                    .hasServiceExtension(
                  extensions.trackRebuildWidgets.extension,
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
                            serviceExtension: extensions.trackRebuildWidgets,
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
                'No widget rebuilds occurred for widgets that were directly created in your project.',
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
