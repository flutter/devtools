// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../primitives/history_manager.dart';
import '../../shared/common_widgets.dart';
import '../../shared/history_viewport.dart';
import 'object_inspector_view_controller.dart';
import 'vm_class_display.dart';
import 'vm_code_display.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_field_display.dart';
import 'vm_function_display.dart';
import 'vm_object_model.dart';
import 'vm_script_display.dart';

/// Displays the VM information for the currently selected object in the
/// program explorer.
class ObjectViewport extends StatelessWidget {
  const ObjectViewport({
    Key? key,
    required this.controller,
  }) : super(key: key);

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
}

@visibleForTesting
String viewportTitle(VmObject? object) {
  if (object == null) {
    return 'No object selected.';
  }

  return '${object.obj.type} ${object.name ?? '<name>'}';
}

/// Calls the object VM statistics card builder according to the VM Object type.
@visibleForTesting
Widget buildObjectDisplay(VmObject obj) {
  if (obj is ClassObject) {
    return VmClassDisplay(
      clazz: obj,
    );
  }
  if (obj is FuncObject) {
    return VmFuncDisplay(function: obj);
  }
  if (obj is FieldObject) {
    return VmFieldDisplay(field: obj);
  }
  if (obj is LibraryObject) {
    return const VMInfoCard(title: 'TO-DO: Display Library object data');
  }
  if (obj is ScriptObject) {
    return VmScriptDisplay(script: obj);
  }
  if (obj is InstanceObject) {
    return const VMInfoCard(title: 'TO-DO: Display Instance object data');
  }
  if (obj is CodeObject) {
    return VmCodeDisplay(
      code: obj,
    );
  }
  return const SizedBox.shrink();
}

/// Manages the history of selected ObjRefs to make them accessible on a
/// HistoryViewport.
class ObjectHistory extends HistoryManager<VmObject> {
  void pushEntry(VmObject object) {
    if (object == current.value) return;

    while (hasNext) {
      pop();
    }

    push(object);
  }
}
