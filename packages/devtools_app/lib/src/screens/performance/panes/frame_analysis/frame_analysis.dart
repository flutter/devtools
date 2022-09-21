// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../../../devtools_app.dart';
import '../../../../service/service_extension_widgets.dart';
import '../../../../service/service_extensions.dart' as extensions;
import '../rebuild_stats/rebuild_counts.dart';
import '../rebuild_stats/widget_rebuild.dart';
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
      return const Center(
        child: Text('No analysis data available for this frame.'),
      );
    }
    final rebuilds = rebuildCountModel.rebuildsForFrame(frameAnalysis.frame.id);

    return Padding(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          if (rebuilds == null || rebuilds.isEmpty)
            ValueListenableBuilder<bool>(
              valueListenable:
                  serviceManager.serviceExtensionManager.hasServiceExtension(
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
            )
        ],
      ),
    );
  }
}
