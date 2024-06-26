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
/// related to list-like VM objects (e.g., subtype test cache, WeakArray, etc).
class VmSimpleListDisplay<T extends VmListObject> extends StatefulWidget {
  const VmSimpleListDisplay({
    super.key,
    required this.controller,
    required this.vmObject,
  });

  final ObjectInspectorViewController controller;
  final T vmObject;

  @override
  State<VmSimpleListDisplay> createState() => _VmSimpleListDisplayState();
}

class _VmSimpleListDisplayState extends State<VmSimpleListDisplay> {
  final entries = <Response?>[];

  late Future<void> _initialized;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(VmSimpleListDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vmObject == oldWidget.vmObject) {
      return;
    }
    _initialize();
  }

  void _initialize() async {
    entries.clear();
    final elementsInstance = widget.vmObject.elementsAsInstance;
    if (elementsInstance != null) {
      if (elementsInstance is Instance) {
        entries.addAll(elementsInstance.elements!.cast<Response?>());
        _initialized = Future.value();
        return;
      }

      final isolateId = serviceConnection
          .serviceManager.isolateManager.selectedIsolate.value!.id!;
      final service = serviceConnection.serviceManager.service!;
      _initialized = service.getObject(isolateId, elementsInstance.id!).then(
            (e) => entries.addAll((e as Instance).elements!.cast<Response?>()),
          );
      return;
    }
    final elementsList = widget.vmObject.elementsAsList;
    assert(
      elementsList != null,
      'One of elementsAsList or elementsAsInstance must be non-null',
    );
    entries.addAll(elementsList!);
    _initialized = Future.value();
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
          object: widget.vmObject,
          generalDataRows: [
            ...vmObjectGeneralDataRows(
              widget.controller,
              widget.vmObject,
            ),
          ],
          expandableWidgets: [
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
