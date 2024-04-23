// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/history_viewport.dart';
import '../../../shared/primitives/history_manager.dart';
import 'object_inspector_view_controller.dart';
import 'vm_class_display.dart';
import 'vm_code_display.dart';
import 'vm_field_display.dart';
import 'vm_function_display.dart';
import 'vm_ic_data_display.dart';
import 'vm_instance_display.dart';
import 'vm_library_display.dart';
import 'vm_object_model.dart';
import 'vm_object_pool_display.dart';
import 'vm_script_display.dart';
import 'vm_simple_list_display.dart';
import 'vm_unknown_object_display.dart';

/// Displays the VM information for the currently selected object in the
/// program explorer.
class ObjectViewport extends StatelessWidget {
  const ObjectViewport({
    super.key,
    required this.controller,
  });

  final ObjectInspectorViewController controller;

  @override
  Widget build(BuildContext context) {
    return HistoryViewport<VmObject>(
      history: controller.objectHistory,
      controls: [
        ToolbarRefresh(onPressed: controller.refreshObject),
      ],
      generateTitle: viewportTitle,
      contentBuilder: (context, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: controller.refreshing,
          builder: (context, refreshing, _) {
            late Widget child;

            if (refreshing) {
              child = const CenteredCircularProgressIndicator();
            } else {
              final currentObject = controller.objectHistory.current.value;
              child = currentObject == null
                  ? const SizedBox.shrink()
                  : buildObjectDisplay(currentObject);
            }

            return Expanded(child: child);
          },
        );
      },
    );
  }

  @visibleForTesting
  static String viewportTitle(VmObject? object) {
    if (object == null) {
      return 'No object selected.';
    }

    if (object.obj is Instance) {
      final instance = object.obj as Instance;
      return 'Instance of ${instance.classRef!.name}';
    }

    if (object is UnknownObject) {
      return 'Instance of VM type ${object.name}';
    }

    return '${object.obj.type} ${object.name ?? ''}'.trim();
  }

  /// Calls the object VM statistics card builder according to the VM Object type.
  @visibleForTesting
  Widget buildObjectDisplay(VmObject obj) {
    if (obj is ClassObject) {
      return VmClassDisplay(
        controller: controller,
        clazz: obj,
      );
    }
    if (obj is FuncObject) {
      return VmFuncDisplay(
        controller: controller,
        function: obj,
      );
    }
    if (obj is FieldObject) {
      return VmFieldDisplay(
        controller: controller,
        field: obj,
      );
    }
    if (obj is LibraryObject) {
      return VmLibraryDisplay(
        controller: controller,
        library: obj,
      );
    }
    if (obj is ScriptObject) {
      return VmScriptDisplay(
        controller: controller,
        script: obj,
      );
    }
    if (obj is InstanceObject) {
      return VmInstanceDisplay(
        controller: controller,
        instance: obj,
      );
    }
    if (obj is CodeObject) {
      return VmCodeDisplay(
        controller: controller,
        code: obj,
      );
    }
    if (obj is ObjectPoolObject) {
      return VmObjectPoolDisplay(
        controller: controller,
        objectPool: obj,
      );
    }
    if (obj is ICDataObject) {
      return VmICDataDisplay(
        controller: controller,
        icData: obj,
      );
    }
    if (obj is VmListObject) {
      return VmSimpleListDisplay(
        controller: controller,
        vmObject: obj,
      );
    }
    if (obj is UnknownObject) {
      return VmUnknownObjectDisplay(
        controller: controller,
        object: obj,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Manages the history of selected ObjRefs to make them accessible on a
/// HistoryViewport.
class ObjectHistory extends HistoryManager<VmObject> {
  void pushEntry(VmObject object) {
    if (object.obj == current.value?.obj) return;
    while (hasNext) {
      pop();
    }
    push(object);
  }
}
