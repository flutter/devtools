// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../screens/profiler/cpu_profile_service.dart';
import '../../screens/profiler/sampling_rate.dart';
import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as gac;
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../globals.dart';
import '../theme.dart';

/// DropdownButton that controls the value of the 'profile_period' vm flag.
///
/// This flag controls the rate at which the vm samples the CPU call stack.
class CpuSamplingRateDropdown extends StatelessWidget {
  const CpuSamplingRateDropdown({
    required this.screenId,
    required this.profilePeriodFlagNotifier,
  });

  final String screenId;

  final ValueNotifier<Flag> profilePeriodFlagNotifier;

  /// The key to identify the dropdown button.
  @visibleForTesting
  static const Key dropdownKey = Key('CpuSamplingRateDropdown DropdownButton');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Flag>(
      valueListenable: profilePeriodFlagNotifier,
      builder: (context, flag, _) {
        // Use [CpuSamplingFrequencyExtension.fromValue] here so we can
        // guarantee that the value corresponds to one of the items in the
        // dropdown list. We default to [CpuSamplingFrequency.medium] if the
        // flag value is not one of the three defaults in DevTools
        // (50, 250, 1000).
        final safeValue =
            CpuSamplingRateExtension.fromValue(flag.valueAsString ?? '').value;
        // Set the vm flag value to the [safeValue] if we get to this state.
        if (safeValue != flag.valueAsString) {
          unawaited(_onSamplingFrequencyChanged(safeValue));
        }

        final bannerMessageController =
            Provider.of<BannerMessagesController>(context);
        if (safeValue == highProfilePeriod) {
          bannerMessageController.addMessage(
            HighCpuSamplingRateMessage(screenId).build(context),
          );
        } else {
          bannerMessageController.removeMessageByKey(
            HighCpuSamplingRateMessage(screenId).key,
            screenId,
          );
        }
        return SizedBox(
          height: defaultButtonHeight,
          child: DevToolsTooltip(
            message:
                'The frequency at which the CPU profiler will sample the call stack',
            child: RoundedDropDownButton<String>(
              key: CpuSamplingRateDropdown.dropdownKey,
              isDense: true,
              style: Theme.of(context).textTheme.bodyMedium,
              value: safeValue,
              items: [
                _buildMenuItem(CpuSamplingRate.low),
                _buildMenuItem(CpuSamplingRate.medium),
                _buildMenuItem(CpuSamplingRate.high),
              ],
              onChanged: _onSamplingFrequencyChanged,
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<String> _buildMenuItem(CpuSamplingRate samplingRate) {
    return DropdownMenuItem<String>(
      value: samplingRate.value,
      child: Text(samplingRate.display),
    );
  }

  Future<void> _onSamplingFrequencyChanged(String? newValue) async {
    ga.select(
      screenId,
      '${gac.cpuSamplingRatePrefix}'
      '${CpuSamplingRateExtension.fromValue(newValue ?? '').displayShort}',
    );
    await serviceManager.service!.setProfilePeriod(
      newValue ?? mediumProfilePeriod,
    );
  }
}
