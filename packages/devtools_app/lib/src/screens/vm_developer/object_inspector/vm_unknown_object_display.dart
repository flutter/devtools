// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../../shared/common_widgets.dart';
import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

class VmUnknownObjectDisplay extends StatelessWidget {
  const VmUnknownObjectDisplay({
    super.key,
    required this.controller,
    required this.object,
  });

  final ObjectInspectorViewController controller;
  final UnknownObject object;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration.onlyBottom(
      child: _UnknownObjectViewer(
        controller: controller,
        object: object,
      ),
    );
  }
}

class _UnknownObjectViewer extends StatelessWidget {
  const _UnknownObjectViewer({
    required this.controller,
    required this.object,
  });

  final ObjectInspectorViewController controller;
  final UnknownObject object;

  @override
  Widget build(BuildContext context) {
    return VmObjectDisplayBasicLayout(
      controller: controller,
      object: object,
      generalDataRows: [
        serviceObjectLinkBuilderMapEntry(
          controller: controller,
          key: 'Object Class',
          object: object.obj.classRef!,
        ),
        shallowSizeRowBuilder(object),
        reachableSizeRowBuilder(object),
        retainedSizeRowBuilder(object),
      ],
    );
  }
}
