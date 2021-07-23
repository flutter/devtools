// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../debugger/codeview.dart';
import '../debugger/debugger_controller.dart';
import '../debugger/debugger_model.dart';
import '../globals.dart';
import '../history_manager.dart';
import '../history_viewport.dart';
import '../split.dart';
import '../utils.dart';
import '../vm_service_utils.dart';
import '../vm_service_wrapper.dart';
import 'object_tree_controller.dart';
import 'object_tree_selector.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_developer_tools_screen.dart';
import 'vm_service_private_extensions.dart';

class TestView extends VMDeveloperView {
  const TestView()
      : super(
          id,
          title: 'Object Inspector',
          icon: Icons.screen_search_desktop,
        );
  static const id = 'test';

  @override
  Widget build(BuildContext context) => TestViewBody();
}

/// Displays general information about the state of the Dart VM.
class TestViewBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: DartObjectInspector(),
        ),
      ],
    );
  }
}

class DartObjectInspector extends StatefulWidget {
  @override
  State<DartObjectInspector> createState() => _DartObjectInspectorState();

  static final history = HistoryManager<VMServiceObjectNode>();
  final controller = ObjectTreeController();
}

class _DartObjectInspectorState extends State<DartObjectInspector>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
    addAutoDisposeListener(
      widget.controller.selected,
      () {
        final node = widget.controller.selected.value;
        final currentNode = DartObjectInspector.history.current.value;
        if (node == null ||
            currentNode?.object == node.object ||
            currentNode?.object == node.script) {
          return;
        }
        DartObjectInspector.history.push(node);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: widget.controller,
      builder: (context, _) {
        final controller = Provider.of<ObjectTreeController>(context);
        return Split(
          axis: Axis.horizontal,
          initialFractions: const [0.3, 0.7],
          children: [
            ObjectTreePicker(
            ),
            HistoryViewport<VMServiceObjectNode>(
              history: DartObjectInspector.history,
              generateTitle: _titleBuilder,
              contentBuilder: (context, node) {
                final obj = node?.object;
                if (obj is ClassRef) {
                  return _ClassInspector(clazz: obj);
                } else if (obj is FuncRef) {
                  return _FunctionInspector(func: obj);
                } else if (obj is FieldRef) {
                  return _FieldInspector(field: obj);
                } else if (obj is ScriptRef) {
                  return _ScriptInspector(script: obj);
                } else if (obj is LibraryRef) {
                  return _LibraryInspector(lib: obj);
                } else {
                  return Container();
                }
              },
              onChange: (current, previous) {
                controller.selectNode(current);
              },
            ),
          ],
        );
      },
    );
  }

  String _titleBuilder(VMServiceObjectNode node) {
    final obj = node?.object;
    if (obj == null) {
      return 'N/A';
    }
    if (obj is ClassRef) {
      return 'class ${obj.name}';
    } else if (obj is FuncRef) {
      return 'Function ${obj.name}';
    } else if (obj is FieldRef) {
      return '${obj.declaredType.name} ${obj.name}';
    } else if (obj is ScriptRef) {
      return 'Script (${obj.uri.split('/').last})';
    } else if (obj is LibraryRef) {
      return obj.name;
    } else {
      return 'Unknown type';
    }
  }
}

class _InstancesStatistics {
  const _InstancesStatistics({
    @required this.reachableSize,
    @required this.retainedSize,
  });

  final int reachableSize;
  final int retainedSize;
}

class _ClassInspector extends StatelessWidget {
  const _ClassInspector({@required this.clazz});

  final ClassRef clazz;

  Future<_InstancesStatistics> _getInstancesStatistics() async {
    final service = serviceManager.service;
    final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;

    final reachableSize = await service.getReachableSize(isolateId, clazz.id);
    final retainedSize = await service.getRetainedSize(isolateId, clazz.id);

    return _InstancesStatistics(
      reachableSize: int.parse(reachableSize.valueAsString),
      retainedSize: int.parse(retainedSize.valueAsString),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;

    final clazzFuture = serviceManager.service
        .getObject(isolateId, clazz.id)
        .then((e) => e as Class);

    final typeFuture = clazzFuture
        .then(
          (clazz) => serviceManager.service.getObject(
            isolateId,
            clazz.classRef.id,
          ),
        )
        .then((e) => e as Class);

    final scriptFuture = clazzFuture
        .then(
          (clazz) => serviceManager.service.getObject(
            isolateId,
            clazz.location.script.id,
          ),
        )
        .then((e) => e as Script);

    final instancesStatisticsFuture = _getInstancesStatistics();
    return FutureBuilder<List>(
      future: Future.wait([
        clazzFuture,
        typeFuture,
        scriptFuture,
        instancesStatisticsFuture,
      ]),
      builder: (context, snapshot) {
        Widget body;
        if (snapshot.connectionState == ConnectionState.done) {
          final clazz = snapshot.data[0];
          final type = snapshot.data[1];
          final script = snapshot.data[2];
          final instancesStats = snapshot.data[3];
          body = Column(
            children: [
              VMInfoList(
                title: 'Details',
                rowKeyValues: _buildClassDetails(
                  clazz,
                  type,
                  script,
                ),
              ),
              VMInfoList(
                title: 'Instances',
                rowKeyValues: [
                  const MapEntry('Currently allocated', '0 (TODO)'),
                  //MapEntry('Strongly ')
                  MapEntry(
                    'Reachable size',
                    prettyPrintBytes(
                      instancesStats.reachableSize,
                      kbFractionDigits: 3,
                      includeUnit: true,
                    ),
                  ),
                  MapEntry(
                    'Retained Size',
                    prettyPrintBytes(
                      instancesStats.retainedSize,
                      kbFractionDigits: 3,
                      includeUnit: true,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Flexible(
          child: ServiceObjectInspector(
            body: body,
          ),
        );
      },
    );
  }

  List<MapEntry> _buildClassDetails(Class clazz, Class type, Script script) {
    return [
      if (clazz.vmName != null && clazz.name != clazz.vmName)
        MapEntry('Internal Name', clazz.vmName),
      MapEntry('Class     ', clazz.name),
      MapEntry('Library   ', LibraryReference(clazz?.library)),
      MapEntry('Script    ', ScriptReference(script, clazz)),
      if (clazz?.superClass != null)
        MapEntry('Superclass', ClassReference(clazz?.superClass)),
      if (clazz?.superType != null)
        MapEntry('Supertype ', TypeReference(clazz.superType)),
      if (clazz?.mixin != null)
        MapEntry('Mixin     ', MixinReference(clazz.mixin)),
      if (clazz?.interfaces != null && clazz.interfaces.isNotEmpty)
        MapEntry(
          'Implements',
          clazz.interfaces.map((i) => ClassReference(i.typeClass)).toList(),
        ),
      MapEntry(
        'Shallow Size',
        prettyPrintBytes(
          clazz.size,
          kbFractionDigits: 3,
          includeUnit: true,
        ),
      ),
    ];
  }
}

class _FunctionInspector extends StatelessWidget {
  const _FunctionInspector({@required this.func});

  final FuncRef func;

  @override
  Widget build(BuildContext context) {
    final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;
    final funcFuture = serviceManager.service
        .getObject(isolateId, func.id)
        .then((e) => e as Func);

    return Flexible(
      child: ServiceObjectInspector(
        body: FutureBuilder<List>(
          future: Future.wait([
            funcFuture,
          ]),
          builder: (context, snapshot) {
            if (snapshot.data == null) {
              return Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const CenteredCircularProgressIndicator(),
              );
            }
            final func = snapshot.data[0];
            return VMInfoList(
              title: 'Details',
              rowKeyValues: [
                MapEntry('Name', func.name),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FieldInspector extends StatelessWidget {
  const _FieldInspector({@required this.field});

  final FieldRef field;

  @override
  Widget build(BuildContext context) {
    final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;
    final fieldFuture = serviceManager.service
        .getObject(isolateId, field.id)
        .then((e) => e as Field);

    return FutureBuilder<Field>(
      future: fieldFuture,
      builder: (context, snapshot) {
        final field = snapshot.data;
        Widget body;
        if (snapshot.connectionState == ConnectionState.done) {
          body = VMInfoList(
            title: 'Details',
            rowKeyValues: [
              MapEntry('Name', field.name),
            ],
          );
        }
        return Flexible(
          child: ServiceObjectInspector(
            body: body,
          ),
        );
      },
    );
  }
}

class _ScriptInspector extends StatelessWidget {
  const _ScriptInspector({@required this.script});

  final ScriptRef script;

  @override
  Widget build(BuildContext context) {
    final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;
    final scriptFuture = serviceManager.service
        .getObject(isolateId, script.id)
        .then((e) => e as Script);

    return FutureBuilder<Script>(
      future: scriptFuture,
      builder: (context, snapshot) {
        final script = snapshot.data;
        Widget body;
        if (snapshot.connectionState == ConnectionState.done) {
          body = VMInfoList(
            title: 'Details',
            rowKeyValues: [
              MapEntry('URI', script.uri),
            ],
          );
        }
        return Flexible(
          child: ServiceObjectInspector(
            body: body,
          ),
        );
      },
    );
  }
}

class _LibraryInspector extends StatelessWidget {
  const _LibraryInspector({@required this.lib});

  final LibraryRef lib;

  @override
  Widget build(BuildContext context) {
    final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;
    final libFuture = serviceManager.service
        .getObject(isolateId, lib.id)
        .then((e) => e as Library);

    return FutureBuilder<Library>(
      future: libFuture,
      builder: (context, snapshot) {
        final lib = snapshot.data;
        Widget body;
        if (snapshot.connectionState == ConnectionState.done) {
          body = VMInfoList(
            title: 'Details',
            rowKeyValues: [
              MapEntry('URI', lib.uri),
            ],
          );
        }
        return Flexible(
          child: ServiceObjectInspector(
            body: body,
          ),
        );
      },
    );
  }
}

class ServiceObjectInspector extends StatefulWidget {
  const ServiceObjectInspector({
    @required this.body,
  });

  final Widget body;

  @override
  State<ServiceObjectInspector> createState() => _ServiceObjectInspectorState();
}

class _ServiceObjectInspectorState extends State<ServiceObjectInspector>
    with AutoDisposeMixin {
  DebuggerController debuggerController;
  ObjectTreeController objectTreeController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debuggerController = Provider.of<DebuggerController>(context);
    objectTreeController = Provider.of<ObjectTreeController>(context);
    addAutoDisposeListener(
      objectTreeController.selected,
      _updateScriptPosition,
    );
  }

  void _updateScriptPosition() {
    final selected = objectTreeController.selected.value;
    if (selected != null) {
      ScriptRef script;
      int tokenPos = 0;
      if ((selected.object == null && selected.script != null) ||
          selected.object is ScriptRef) {
        script = selected.script;
      } else if (selected.object is ScriptRef ||
          selected.object is LibraryRef) {
        return;
      } else {
        final location = (selected.object as dynamic).location;
        tokenPos = location.tokenPos;
        script = location.script;
      }
      final isolateId = serviceManager.isolateManager.selectedIsolate.value.id;
      serviceManager.service
          .getObject(isolateId, script.id)
          .then((obj) => obj as Script)
          .then(
        (script) {
          final loc = ScriptLocation(
            script,
            location: SourcePosition.calculatePosition(
              script,
              tokenPos,
            ),
          );
          debuggerController.showScriptLocation(loc);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DebuggerController>(context);
    return Split(
      axis: Axis.vertical,
      initialFractions: const [0.5, 0.5],
      children: [
        if (widget.body == null)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: const CenteredCircularProgressIndicator(),
          )
        else
          OutlineDecoration(
            child: Scrollbar(
              child: SingleChildScrollView(
                child: widget.body,
              ),
            ),
          ),
        ValueListenableBuilder(
          valueListenable: controller.currentParsedScript,
          builder: (context, parsedScript, _) {
            return CodeView(
              controller: controller,
              parsedScript: parsedScript,
              showHistory: false,
              centerScrollingPosition: false,
              scriptRef: parsedScript.script,
            );
          },
        ),
      ],
    );
  }
}
