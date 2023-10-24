// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/common_widgets.dart';
import '../../../../shared/globals.dart';
import '../../../../shared/ui/filter.dart';
import '../../cpu_profile_model.dart';
import '../../cpu_profiler_controller.dart';
import '../../profiler_screen_controller.dart';

final profilerScreenSearchFieldKey =
    GlobalKey(debugLabel: 'ProfilerScreenSearchFieldKey');

class CpuProfileFilterDialog extends StatelessWidget {
  const CpuProfileFilterDialog({required this.controller, Key? key})
      : super(key: key);

  static const filterQueryInstructions = '''
Type a filter query to show or hide specific stack frames.

Any text that is not paired with an available filter key below will be queried against all categories (method, uri).

Available filters:
    'uri', 'u'       (e.g. 'uri:my_dart_package/some_lib.dart', '-u:some_lib_to_hide')

Example queries:
    'someMethodName uri:my_dart_package,b_dart_package'
    '.toString -uri:flutter'
''';

  final CpuProfilerController controller;

  @override
  Widget build(BuildContext context) {
    return FilterDialog<CpuStackFrame>(
      controller: controller,
      queryInstructions: filterQueryInstructions,
    );
  }
}

/// DropdownButton that controls the value of
/// [ProfilerScreenController.userTagFilter].
class UserTagDropdown extends StatelessWidget {
  const UserTagDropdown(this.controller, {super.key});

  final CpuProfilerController controller;

  @override
  Widget build(BuildContext context) {
    const filterByTag = 'Filter by tag:';
    return ValueListenableBuilder<String>(
      valueListenable: controller.userTagFilter,
      builder: (context, userTag, _) {
        final userTags = controller.userTags;
        final tooltip = userTags.isNotEmpty
            ? 'Filter the CPU profile by the given UserTag'
            : 'No UserTags found for this CPU profile';
        return SizedBox(
          height: defaultButtonHeight,
          child: DevToolsTooltip(
            message: tooltip,
            child: ValueListenableBuilder<bool>(
              valueListenable: preferences.vmDeveloperModeEnabled,
              builder: (context, vmDeveloperModeEnabled, _) {
                return RoundedDropDownButton<String>(
                  isDense: true,
                  style: Theme.of(context).textTheme.bodyMedium,
                  value: userTag,
                  items: [
                    _buildMenuItem(
                      display:
                          '$filterByTag ${CpuProfilerController.userTagNone}',
                      value: CpuProfilerController.userTagNone,
                    ),
                    // We don't want to show the 'Default' tag if it is the only
                    // tag available. The 'none' tag above is equivalent in this
                    // case.
                    if (!(userTags.length == 1 &&
                        userTags.first == UserTag.defaultTag.label)) ...[
                      for (final tag in userTags)
                        _buildMenuItem(
                          display: '$filterByTag $tag',
                          value: tag,
                        ),
                      _buildMenuItem(
                        display: 'Group by: User Tag',
                        value: CpuProfilerController.groupByUserTag,
                      ),
                    ],
                    if (vmDeveloperModeEnabled)
                      _buildMenuItem(
                        display: 'Group by: VM Tag',
                        value: CpuProfilerController.groupByVmTag,
                      ),
                  ],
                  onChanged: userTags.isEmpty ||
                          (userTags.length == 1 &&
                              userTags.first == UserTag.defaultTag.label)
                      ? null
                      : (String? tag) => _onUserTagChanged(tag!),
                );
              },
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<String> _buildMenuItem({
    required String display,
    required String value,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      child: Text(display),
    );
  }

  void _onUserTagChanged(String newTag) async {
    try {
      await controller.loadDataWithTag(newTag);
    } catch (e) {
      notificationService.push(e.toString());
    }
  }
}

/// DropdownButton that controls the value of
/// [ProfilerScreenController.viewType].
class ModeDropdown extends StatelessWidget {
  const ModeDropdown(this.controller, {super.key});

  final CpuProfilerController controller;

  @override
  Widget build(BuildContext context) {
    const mode = 'View:';
    return ValueListenableBuilder<CpuProfilerViewType>(
      valueListenable: controller.viewType,
      builder: (context, viewType, _) {
        final tooltip = viewType == CpuProfilerViewType.function
            ? 'Display the profile in terms of the Dart call stack '
                '(i.e., inlined frames are expanded)'
            : 'Display the profile in terms of native stack frames '
                '(i.e., inlined frames are not expanded, display code objects '
                'rather than individual functions)';
        return SizedBox(
          height: defaultButtonHeight,
          child: DevToolsTooltip(
            message: tooltip,
            child: RoundedDropDownButton<CpuProfilerViewType>(
              isDense: true,
              style: Theme.of(context).textTheme.bodyMedium,
              value: viewType,
              items: [
                _buildMenuItem(
                  display: '$mode ${CpuProfilerViewType.function}',
                  value: CpuProfilerViewType.function,
                ),
                _buildMenuItem(
                  display: '$mode ${CpuProfilerViewType.code}',
                  value: CpuProfilerViewType.code,
                ),
              ],
              onChanged: (type) => controller.updateViewForType(type!),
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<CpuProfilerViewType> _buildMenuItem({
    required String display,
    required CpuProfilerViewType value,
  }) {
    return DropdownMenuItem<CpuProfilerViewType>(
      value: value,
      child: Text(display),
    );
  }
}
