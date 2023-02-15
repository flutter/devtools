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
class VmSubtypeTestCacheDisplay extends StatefulWidget {
  const VmSubtypeTestCacheDisplay({
    required this.controller,
    required this.subtypeTestCache,
  });

  final ObjectInspectorViewController controller;
  final SubtypeTestCacheObject subtypeTestCache;

  @override
  State<VmSubtypeTestCacheDisplay> createState() =>
      _VmSubtypeTestCacheDisplayState();
}

class _VmSubtypeTestCacheDisplayState extends State<VmSubtypeTestCacheDisplay> {
  final entries = <ObjRef?>[];

  late Future<void> _initialized;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(VmSubtypeTestCacheDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subtypeTestCache == oldWidget.subtypeTestCache) {
      return;
    }
    _initialize();
  }

  void _initialize() async {
    entries.clear();

    final subtypeTestCache = widget.subtypeTestCache.obj;
    final cache = subtypeTestCache.cache;
    if (cache is Instance) {
      entries.addAll(cache.elements!.cast<ObjRef?>());
      _initialized = Future.value();
      return;
    }

    final isolateId = serviceManager.isolateManager.selectedIsolate.value!.id!;
    final service = serviceManager.service!;
    _initialized = service
        .getObject(isolateId, cache.id!)
        .then((e) => entries.addAll((e as Instance).elements!.cast<ObjRef?>()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialized,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const CenteredCircularProgressIndicator();
        return VmObjectDisplayBasicLayout(
          controller: widget.controller,
          object: widget.subtypeTestCache,
          generalDataRows: [
            ...vmObjectGeneralDataRows(
              widget.controller,
              widget.subtypeTestCache,
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
