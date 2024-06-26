// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/globals.dart';
import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to ICData objects in the Dart VM.
class VmICDataDisplay extends StatefulWidget {
  const VmICDataDisplay({
    super.key,
    required this.controller,
    required this.icData,
  });

  final ObjectInspectorViewController controller;
  final ICDataObject icData;

  @override
  State<VmICDataDisplay> createState() => _VmICDataDisplayState();
}

class _VmICDataDisplayState extends State<VmICDataDisplay> {
  final argumentsDescriptor = <ObjRef?>[];
  final entries = <ObjRef?>[];

  late Future<void> _initialized;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(VmICDataDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.icData == oldWidget.icData) {
      return;
    }
    _initialize();
  }

  void _initialize() async {
    argumentsDescriptor.clear();
    entries.clear();

    void populateLists(Instance argDescriptor, Instance entryList) {
      argumentsDescriptor.addAll(argDescriptor.elements!.cast<ObjRef?>());
      entries.addAll(entryList.elements!.cast<ObjRef?>());
    }

    final icData = widget.icData.obj;
    final icDataArgsDescriptor = icData.argumentsDescriptor;
    final icDataEntries = icData.entries;
    if (icDataArgsDescriptor is Instance && icDataEntries is Instance) {
      populateLists(icDataArgsDescriptor, icDataEntries);
      _initialized = Future.value();
      return;
    }

    final isolateId = serviceConnection
        .serviceManager.isolateManager.selectedIsolate.value!.id!;
    final service = serviceConnection.serviceManager.service!;
    final argumentsDescriptorFuture = service
        .getObject(isolateId, icData.argumentsDescriptor.id!)
        .then((e) => e as Instance);
    final entriesFuture = service
        .getObject(isolateId, icData.entries.id!)
        .then((e) => e as Instance);
    _initialized = Future.wait([
      argumentsDescriptorFuture,
      entriesFuture,
    ]).then(
      (result) => populateLists(result[0], result[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialized,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CenteredCircularProgressIndicator();
        }
        return VmObjectDisplayBasicLayout(
          controller: widget.controller,
          object: widget.icData,
          generalDataRows: [
            ...vmObjectGeneralDataRows(widget.controller, widget.icData),
            selectableTextBuilderMapEntry(
              'Selector',
              widget.icData.obj.selector,
            ),
            serviceObjectLinkBuilderMapEntry(
              controller: widget.controller,
              key: 'Owner',
              object: widget.icData.obj.owner,
            ),
          ],
          expandableWidgets: [
            ExpansionTileInstanceList(
              controller: widget.controller,
              title: 'Arguments Descriptor',
              elements: argumentsDescriptor,
            ),
            ExpansionTileInstanceList(
              controller: widget.controller,
              title: 'Entries',
              elements: entries,
            ),
          ],
        );
      },
    );
  }
}
