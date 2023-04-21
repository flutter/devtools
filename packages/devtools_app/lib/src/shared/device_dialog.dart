// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import 'common_widgets.dart';
import 'connected_app.dart';
import 'dialogs.dart';
import 'globals.dart';
import 'primitives/auto_dispose.dart';
import 'primitives/utils.dart';
import 'routing.dart';
import 'table/table.dart';
import 'table/table_data.dart';
import 'theme.dart';
import 'utils.dart';

class DeviceDialog extends StatelessWidget {
  const DeviceDialog({super.key, required this.connectedApp});

  final ConnectedApp connectedApp;

  @override
  Widget build(BuildContext context) {
    const boldText = TextStyle(fontWeight: FontWeight.bold);
    final theme = Theme.of(context);

    final VM? vm = serviceManager.vm;

    if (vm == null) return const SizedBox();

    final connectionDescriptionEntries =
        generateDeviceDescription(vm, connectedApp);

    // TODO(kenz): set actions alignment to `spaceBetween` if
    // https://github.com/flutter/flutter/issues/69708 is fixed.
    return DevToolsDialog(
      title: const DialogTitleText('Device Info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var entry in connectionDescriptionEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: denseRowSpacing),
              child: Row(
                children: [
                  Text('${entry.title}: ', style: boldText),
                  SelectableText(
                    entry.description,
                    style: theme.subtleTextStyle,
                  ),
                  if (entry.actions.isNotEmpty) ...entry.actions,
                ],
              ),
            ),
        ],
      ),
      actions: [
        _connectToNewAppButton(context),
        if (connectedApp.isRunningOnDartVM!) _ViewVMFlagsButton(),
        const DialogCloseButton(),
      ],
    );
  }

  Widget _connectToNewAppButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        DevToolsRouterDelegate.of(context).navigateHome(
          clearUriParam: true,
          clearScreenParam: true,
        );
        Navigator.of(context, rootNavigator: true).pop('dialog');
      },
      child: Text(connectToNewAppText.toUpperCase()),
    );
  }
}

class _ViewVMFlagsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DialogTextButton(
      onPressed: () {
        Navigator.of(context, rootNavigator: true).pop('dialog');
        unawaited(
          showDialog(
            context: context,
            builder: (context) => const VMFlagsDialog(),
          ),
        );
      },
      child: Text('View VM Flags'.toUpperCase()),
    );
  }
}

class VMFlagsDialog extends StatefulWidget {
  const VMFlagsDialog({super.key});

  @override
  _VMFlagsDialogState createState() => _VMFlagsDialogState();
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
    addAutoDisposeListener(serviceManager.vmFlagManager.flags, () {
      setState(() {
        _updateFromController();
      });
    });
  }

  void _updateFromController() {
    flags = (serviceManager.vmFlagManager.flags.value?.flags ?? [])
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
