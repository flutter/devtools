// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

/// Displays basic properties about an VM service object of an unknown type.
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
      child: VmObjectDisplayBasicLayout(
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
      ),
    );
  }
}
