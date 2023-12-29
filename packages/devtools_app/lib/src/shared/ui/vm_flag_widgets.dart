// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../screens/profiler/cpu_profile_service.dart';
import '../../screens/profiler/sampling_rate.dart';
import '../analytics/constants.dart' as gac;
import '../banner_messages.dart';
import '../common_widgets.dart';
import '../globals.dart';
import '../primitives/utils.dart';
import '../table/table.dart';
import '../table/table_data.dart';
import 'drop_down_button.dart';
import 'hover.dart';

/// DropdownButton that controls the value of the 'profile_period' vm flag.
///
/// This flag controls the rate at which the vm samples the CPU call stack.
class CpuSamplingRateDropdown extends StatelessWidget {
  const CpuSamplingRateDropdown({
    super.key,
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

        if (safeValue == highProfilePeriod) {
          bannerMessages.addMessage(
            HighCpuSamplingRateMessage(screenId).build(context),
          );
        } else {
          bannerMessages.removeMessageByKey(
            HighCpuSamplingRateMessage(screenId).key,
            screenId,
          );
        }

        return AnalyticsDropDownButton(
          key: CpuSamplingRateDropdown.dropdownKey,
          gaScreen: screenId,
          isDense: true,
          gaDropDownId: gac.CpuProfilerEvents.profileGranularity.name,
          message:
              'The frequency at which the CPU profiler will sample the call stack',
          value: safeValue,
          items: [
            _buildMenuItem(CpuSamplingRate.low),
            _buildMenuItem(CpuSamplingRate.medium),
            _buildMenuItem(CpuSamplingRate.high),
          ],
          onChanged: _onSamplingFrequencyChanged,
        );
      },
    );
  }

  ({DropdownMenuItem<String> item, String gaId}) _buildMenuItem(
    CpuSamplingRate samplingRate,
  ) {
    return (
      item: DropdownMenuItem<String>(
        value: samplingRate.value,
        child: DevToolsTooltip(
          message: 'One sample every ${samplingRate.value} microseconds.',
          child: Text(samplingRate.display),
        ),
      ),
      gaId: samplingRate.displayShort,
    );
  }

  Future<void> _onSamplingFrequencyChanged(String? newValue) async {
    await serviceConnection.serviceManager.service!.setProfilePeriod(
      newValue ?? mediumProfilePeriod,
    );
  }
}

class ViewVmFlagsButton extends StatelessWidget {
  const ViewVmFlagsButton({
    super.key,
    required this.gaScreen,
    this.elevated = false,
    this.minScreenWidthForTextBeforeScaling,
  });

  final String gaScreen;

  final bool elevated;

  final double? minScreenWidthForTextBeforeScaling;

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton(
      elevated: elevated,
      label: 'View VM flags',
      icon: Icons.flag_rounded,
      gaScreen: gaScreen,
      gaSelection: gac.HomeScreenEvents.viewVmFlags.name,
      minScreenWidthForTextBeforeScaling: minScreenWidthForTextBeforeScaling,
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop('dialog');
        unawaited(
          showDialog(
            context: context,
            builder: (context) => const VMFlagsDialog(),
          ),
        );
      },
    );
  }
}

class VMFlagsDialog extends StatefulWidget {
  const VMFlagsDialog({super.key});

  @override
  State<VMFlagsDialog> createState() => _VMFlagsDialogState();
}

class _VMFlagsDialogState extends State<VMFlagsDialog> with AutoDisposeMixin {
  late final TextEditingController filterController;

  var flags = <_DialogFlag>[];

  var filteredFlags = <_DialogFlag>[];

  @override
  void initState() {
    super.initState();

    filterController = TextEditingController();
    addAutoDisposeListener(filterController, () {
      setState(() {
        _refilter();
      });
    });

    _updateFromController();
    addAutoDisposeListener(serviceConnection.vmFlagManager.flags, () {
      setState(() {
        _updateFromController();
      });
    });
  }

  void _updateFromController() {
    flags = (serviceConnection.vmFlagManager.flags.value?.flags ?? [])
        .map((flag) => _DialogFlag(flag))
        .toList();
    _refilter();
  }

  void _refilter() {
    final filter = filterController.text.trim().toLowerCase();

    filteredFlags = filter.isEmpty
        ? flags
        : flags.where((flag) => flag.filterText.contains(filter)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: Row(
        children: [
          const DialogTitleText('VM Flags'),
          const Expanded(child: SizedBox(width: denseSpacing)),
          SizedBox(
            width: defaultSearchFieldWidth,
            height: defaultTextFieldHeight,
            child: TextField(
              controller: filterController,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: 'Filter',
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 875,
            height: 375,
            child: _FlagTable(filteredFlags),
          ),
        ],
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}

class _FlagTable extends StatelessWidget {
  const _FlagTable(this.flags);

  final List<_DialogFlag> flags;

  static final name = _NameColumn();
  static final description = _DescriptionColumn();
  static final value = _ValueColumn();
  static final columns = <ColumnData<_DialogFlag>>[name, description, value];

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      child: FlatTable<_DialogFlag>(
        keyFactory: (_DialogFlag flag) => ValueKey<String?>(flag.name),
        data: flags,
        dataKey: 'vm-flags',
        columns: columns,
        defaultSortColumn: name,
        defaultSortDirection: SortDirection.ascending,
      ),
    );
  }
}

class _NameColumn extends ColumnData<_DialogFlag> {
  _NameColumn()
      : super(
          'Name',
          fixedWidthPx: scaleByFontFactor(180),
        );

  @override
  String getValue(_DialogFlag dataObject) => dataObject.name ?? '';
}

class _DescriptionColumn extends ColumnData<_DialogFlag> {
  _DescriptionColumn()
      : super.wide(
          'Description',
          minWidthPx: scaleByFontFactor(100),
        );

  @override
  String getValue(_DialogFlag dataObject) => dataObject.description ?? '';

  @override
  String getTooltip(_DialogFlag dataObject) => getValue(dataObject);
}

class _ValueColumn extends ColumnData<_DialogFlag> {
  _ValueColumn()
      : super(
          'Value',
          fixedWidthPx: scaleByFontFactor(160),
          alignment: ColumnAlignment.right,
        );

  @override
  String getValue(_DialogFlag dataObject) => dataObject.value ?? '';
}

class _DialogFlag {
  _DialogFlag(this.flag)
      : filterText = '${flag.name?.toLowerCase()}\n'
            '${flag.comment?.toLowerCase()}\n'
            '${flag.valueAsString?.toLowerCase()}';

  final Flag flag;
  final String filterText;

  String? get name => flag.name;

  String? get description => flag.comment;

  String? get value => flag.valueAsString;
}
