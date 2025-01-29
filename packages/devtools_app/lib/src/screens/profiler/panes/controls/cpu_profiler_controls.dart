// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:developer';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/globals.dart';
import '../../cpu_profiler_controller.dart';
import '../../profiler_screen_controller.dart';

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
        final tooltip =
            userTags.isNotEmpty
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
                  onChanged:
                      userTags.isEmpty ||
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
    return DropdownMenuItem<String>(value: value, child: Text(display));
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
        final tooltip =
            viewType == CpuProfilerViewType.function
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
