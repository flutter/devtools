// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/history_manager.dart';
import '../../shared/common_widgets.dart';
import '../../shared/history_viewport.dart';
import '../../shared/utils.dart';
import '../debugger/program_explorer_controller.dart';
import 'vm_class_screen.dart';
import 'vm_class_screen_controller.dart';
import 'vm_developer_common_widgets.dart';

/// Displays the VM information for the currently selected object in the
/// program explorer.
class ObjectViewport extends StatelessWidget {
  ObjectViewport({
    Key? key,
    required this.controller,
    required this.objectHistory,
    this.initialObject, //main library
  }) : super(key: key);

  static double get rowHeight => scaleByFontFactor(20.0);
  static double get assumedCharacterWidth => scaleByFontFactor(16.0);

  final ProgramExplorerController controller;
  final ObjRef? initialObject;
  final ObjectHistory objectHistory;
  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(true);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _refreshing,
      builder: (context, refreshing, _) {
        return HistoryViewport<ObjRef>(
          history: objectHistory,
          controls: [
            ToolbarAction(
              icon: Icons.refresh,
              onPressed: () {
                _refreshing.value = !_refreshing.value;
              },
              tooltip: 'Refresh',
            )
          ],
          generateTitle: (currentObjRef) {
            return currentObjRef == null
                ? 'No object selected.'
                : _getViewportTitle(currentObjRef);
          },
          contentBuilder: (context, _) {
            final currentObjRef = objectHistory.current.value;
            return currentObjRef == null
                ? const SizedBox.shrink()
                : _buildObjectScreen(currentObjRef);
          },
        );
      },
    );
  }
}

String _getViewportTitle(ObjRef objRef) {
  if (objRef is ClassRef) return objRef.type + ' ' + (objRef.name ?? '<name>');
  if (objRef is FuncRef) return objRef.type + ' ' + (objRef.name ?? '<name>');
  if (objRef is FieldRef) return objRef.type + ' ' + (objRef.name ?? '<name>');
  if (objRef is LibraryRef)
    return objRef.type + ' ' + (objRef.name ?? '<name>');
  if (objRef is ScriptRef) return 'Script @ ' + (objRef.uri ?? '<name>');
  return '<unrecognized object>';
}

//Calls the object VM statistics card builder according to the VM Object type.
Widget _buildObjectScreen(ObjRef objRef) {
  if (objRef is ClassRef) {
    return VmClassScreen(
      controller: ClassScreenController(objRef),
    );
  }
  if (objRef is FuncRef)
    return const VMInfoCard(title: 'TO-DO: Display Function object data');
  if (objRef is FieldRef)
    return const VMInfoCard(title: 'TO-DO: Display Field object data');
  if (objRef is LibraryRef)
    return const VMInfoCard(title: 'TO-DO: Display Library object data');
  if (objRef is ScriptRef)
    return const VMInfoCard(title: 'TO-DO: Display Script object data');
  return const SizedBox.shrink();
}

/// Manages the history of selected ObjRefs to make them accessible on a HistoryViewport.
class ObjectHistory extends HistoryManager<ObjRef> {
  final _openedObjects = <ObjRef>{};

  bool get hasObjects => _openedObjects.isNotEmpty;

  void pushEntry(ObjRef ref) async {
    if (ref == current.value) return;

    while (hasNext) {
      pop();
    }

    _openedObjects.add(ref);

    push(ref);
  }

  Iterable<ObjRef> get openedObjects => _openedObjects.toList().reversed;
}
