// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../screens/profiler/cpu_profile_service.dart';
import '../screens/profiler/profile_granularity.dart';
import '../shared/banner_messages.dart';
import '../shared/common_widgets.dart';
import '../shared/globals.dart';

/// DropdownButton that controls the value of the 'profile_period' vm flag.
///
/// This flag controls the rate at which the vm samples the CPU call stack.
class ProfileGranularityDropdown extends StatelessWidget {
  const ProfileGranularityDropdown({
    required this.screenId,
    required this.profileGranularityFlagNotifier,
  });

  final String screenId;

  final ValueNotifier<Flag> profileGranularityFlagNotifier;

  /// The key to identify the dropdown button.
  @visibleForTesting
  static const Key dropdownKey =
      Key('ProfileGranularityDropdown DropdownButton');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Flag>(
      valueListenable: profileGranularityFlagNotifier,
      builder: (context, flag, _) {
        // Use [ProfileGranularityExtension.fromValue] here so we can
        // guarantee that the value corresponds to one of the items in the
        // dropdown list. We default to [ProfileGranularity.medium] if the flag
        // value is not one of the three defaults in DevTools (50, 250, 1000).
        final safeValue =
            ProfileGranularityExtension.fromValue(flag.valueAsString ?? '')
                .value;
        // Set the vm flag value to the [safeValue] if we get to this state.
        if (safeValue != flag.valueAsString) {
          _onProfileGranularityChanged(safeValue);
        }

        final bannerMessageController =
            Provider.of<BannerMessagesController>(context);
        if (safeValue == highProfilePeriod) {
          bannerMessageController.addMessage(
            HighProfileGranularityMessage(screenId).build(context),
          );
        } else {
          bannerMessageController.removeMessageByKey(
            HighProfileGranularityMessage(screenId).key,
            screenId,
          );
        }
        return RoundedDropDownButton<String>(
          key: ProfileGranularityDropdown.dropdownKey,
          isDense: true,
          style: Theme.of(context).textTheme.bodyText2,
          value: safeValue,
          items: [
            _buildMenuItem(ProfileGranularity.low),
            _buildMenuItem(ProfileGranularity.medium),
            _buildMenuItem(ProfileGranularity.high),
          ],
          onChanged: _onProfileGranularityChanged,
        );
      },
    );
  }

  DropdownMenuItem<String> _buildMenuItem(ProfileGranularity granularity) {
    return DropdownMenuItem<String>(
      value: granularity.value,
      child: Text(granularity.display),
    );
  }

  Future<void> _onProfileGranularityChanged(String? newValue) async {
    ga.select(
      screenId,
      '${analytics_constants.profileGranularityPrefix}'
      '${ProfileGranularityExtension.fromValue(newValue ?? '').displayShort}',
    );
    await serviceManager.service.setProfilePeriod(newValue);
  }
}
