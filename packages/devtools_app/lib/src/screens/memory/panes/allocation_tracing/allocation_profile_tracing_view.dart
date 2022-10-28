// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../analytics/constants.dart' as analytics_constants;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/split.dart';
import '../../../../shared/theme.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RefreshButton(
              tooltip: 'Request the set of updated allocation traces',
              onPressed: () async {
                await controller.refresh();
              },
            ),
            const SizedBox(
              width: denseSpacing,
            ),
            ClearButton(
              tooltip: 'Clear the set of previously collected traces',
              onPressed: () async {
                await controller.clear();
              },
            ),
            const _ProfileHelpLink(),
          ],
        ),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: Split(
            axis: Axis.horizontal,
            initialFractions: const [0.25, 0.75],
            children: [
              AllocationTracingTable(
                controller: controller,
              ),
              OutlineDecoration(
                child: AllocationTracingTree(
                  controller: controller,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHelpLink extends StatelessWidget {
  const _ProfileHelpLink({Key? key}) : super(key: key);

  static const _documentationTopic = 'allocationTracing';

  @override
  Widget build(BuildContext context) {
    return HelpButtonWithDialog(
      gaScreen: analytics_constants.memory,
      gaSelection:
          analytics_constants.topicDocumentationButton(_documentationTopic),
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
            url: 'https://github.com/flutter/devtools/blob/master/'
                'packages/devtools_app/lib/src/screens/memory/panes/'
                'allocation_tracing/ALLOCATION_TRACING.md',
            gaScreenName: analytics_constants.memory,
            gaSelectedItemDescription:
                analytics_constants.topicDocumentationLink(_documentationTopic),
          )
        ],
      ),
    );
  }
}
