// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/split.dart';
import '../../../../shared/theme.dart';

import '../../shared/primitives/simple_elements.dart';
import 'allocation_profile_class_table.dart';
import 'allocation_profile_tracing_tree.dart';
import 'allocation_profile_tracing_view_controller.dart';

class AllocationProfileTracingView extends StatefulWidget {
  const AllocationProfileTracingView({
    Key? key,
  }) : super(key: key);

  @override
  State<AllocationProfileTracingView> createState() =>
      AllocationProfileTracingViewState();
}

class AllocationProfileTracingViewState
    extends State<AllocationProfileTracingView> {
  late final AllocationProfileTracingViewController controller;

  @override
  void initState() {
    super.initState();
    controller = AllocationProfileTracingViewController();
    unawaited(controller.initialize());
  }

  @override
  Widget build(BuildContext context) {
    final isProfileMode =
        serviceManager.connectedApp?.isProfileBuildNow ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TracingControls(
          isProfileMode: isProfileMode,
          controller: controller,
        ),
        Expanded(
          child: isProfileMode
              ? OutlineDecoration.onlyTop(
                  child: const Center(
                    child: Text(
                      'Allocation tracing is temporary disabled in profile mode.\n'
                      'Run the application in debug mode to trace allocations.',
                    ),
                  ),
                )
              : OutlineDecoration.onlyTop(
                  child: Split(
                    axis: Axis.horizontal,
                    initialFractions: const [0.25, 0.75],
                    children: [
                      OutlineDecoration.onlyRight(
                        child: AllocationTracingTable(
                          controller: controller,
                        ),
                      ),
                      OutlineDecoration.onlyLeft(
                        child: AllocationTracingTree(
                          controller: controller,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _TracingControls extends StatelessWidget {
  const _TracingControls({
    required this.isProfileMode,
    required this.controller,
  });

  final bool isProfileMode;

  final AllocationProfileTracingViewController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(denseSpacing),
      child: Row(
        children: [
          RefreshButton(
            tooltip: 'Request the set of updated allocation traces',
            onPressed: isProfileMode
                ? null
                : () async {
                    ga.select(
                      gac.memory,
                      gac.MemoryEvent.tracingRefresh,
                    );
                    await controller.refresh();
                  },
          ),
          const SizedBox(
            width: denseSpacing,
          ),
          ClearButton(
            tooltip: 'Clear the set of previously collected traces',
            onPressed: isProfileMode
                ? null
                : () async {
                    ga.select(
                      gac.memory,
                      gac.MemoryEvent.tracingClear,
                    );
                    await controller.clear();
                  },
          ),
          const _ProfileHelpLink(),
        ],
      ),
    );
  }
}

class _ProfileHelpLink extends StatelessWidget {
  const _ProfileHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = gac.MemoryEvent.tracingHelp;

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: gac.memory,
      gaSelection: gac.topicDocumentationButton(_documentationTopic),
      dialogTitle: 'Memory Allocation Tracing Help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'The allocation tracing tab allows for toggling allocation\n'
            'tracing for specific types, which records the locations of\n'
            'allocations of instances of traced types within the\n'
            'currently selected isolate.\n'
            '\n'
            'Allocation sites of traced types can be viewed by refreshing\n'
            'the tracing profile before selecting the traced type from the\n'
            'list, displaying a condensed view of locations where objects\n'
            'were allocated.',
          ),
          MoreInfoLink(
            url: DocLinks.trace.value,
            gaScreenName: gac.memory,
            gaSelectedItemDescription:
                gac.topicDocumentationLink(_documentationTopic),
          )
        ],
      ),
    );
  }
}
