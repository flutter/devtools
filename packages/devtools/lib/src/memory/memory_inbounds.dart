// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../tables.dart';
import '../trees.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';

import 'memory.dart';
import 'memory_protocol.dart';
import 'memory_service.dart';

class InboundsTree extends InstanceRefsView {
  InboundsTree(this._memoryScreen, InboundsTreeData theData, String className)
      : super(theData) {
    flex();
    layoutVertical();

    _init(className);
  }

  final MemoryScreen _memoryScreen;
  TreeTable<InboundsTreeNode> referencesTable;

  void _init(String className) {
    final title =
        '${inboundsTree.data.children.length} Instances of $className';

    final classNameColumn = ClassNameColumn(title)
      ..onNodeExpanded.listen((inboundNode) async {
        if (inboundNode.children.length == 1 &&
            inboundNode.children[0].isEmpty) {
          inboundNode.children.removeLast();
          // Make sure it's a known class (not abstract).
          if (!inboundNode.isEmpty) {
            final Spinner spinner = Spinner.centered();
            referencesTable.element.add(spinner);

            if (inboundNode.instanceHashCode == null &&
                inboundNode.instance != null) {
              // Need the hashCode.  It's slow - do it when needed.
              // TODO(terry): Needs to be used with real snapshot.
              final String instanceHashCode =
                  await _memoryScreen.computeInboundReference(
                inboundNode.instance.objectRef,
                inboundNode,
              );
              inboundNode.instanceHashCode = instanceHashCode;
            }

            final int instanceHashCode = _memoryScreen.isMemoryExperiment
                ? int.parse(inboundNode.instanceHashCode)
                : -1;

            final ClassHeapDetailStats classStats =
                _memoryScreen.findClass(inboundNode.name);

            // All instances of a class.
            List<InstanceSummary> instances =
                await _memoryScreen.findInstances(classStats);
            for (InstanceSummary instance in instances) {
              // Found the instance.
              final InboundReferences refs =
                  await getInboundReferences(instance.objectRef, 1000);

              if (_memoryScreen.isMemoryExperiment) {
                // TODO(terry): Temporary workaround since evaluate fails on expressions
                // TODO(terry): accessing a private field e.g., _extra.hashcode.
                if (await _memoryScreen.memoryController.matchObject(
                    instance.objectRef,
                    inboundNode.fieldName,
                    instanceHashCode)) {
                  // TODO(terry): Expensive need better VMService identity for objectRef.
                  // Get hashCode identity object id changes but hashCode is our identity.
                  var hashCodeResult;

                  hashCodeResult =
                      await evaluate(instance.objectRef, 'hashCode');

                  // Record we have a real instance too.
                  inboundNode.setInstance(
                      instance, hashCodeResult?.valueAsString);

                  final List<ClassHeapDetailStats> allClasses =
                      _memoryScreen.tableStack.first.data;

                  computeInboundRefs(allClasses, refs, (
                    String referenceName,
                    String owningAllocator,
                    bool owningAllocatorIsAbstract,
                  ) async {
                    if (!owningAllocatorIsAbstract &&
                        owningAllocator.isNotEmpty) {
                      var newRefNode = InboundsTreeNode(owningAllocator,
                          referenceName, hashCodeResult?.valueAsString);
                      inboundNode.addChild(newRefNode);
                      newRefNode.addChild(InboundsTreeNode.empty());
                    }
                  });
                }
              }
            }
            spinner.remove();
          }
        }

        referencesTable.expandNode(inboundNode);
      })
      ..onNodeCollapsed
          .listen((inboundNode) => referencesTable.collapseNode(inboundNode));

    referencesTable = TreeTable<InboundsTreeNode>.virtual()
      ..addColumn(classNameColumn)
      ..addColumn(FieldNameColumn())
      ..element.clazz('memory-table');

    referencesTable..setRows(<InboundsTreeNode>[]);

    referencesTable.onSelect.listen(_memoryScreen.select);

    add(referencesTable.element);
  }

  @override
  void rebuildView() {
    final InboundsTreeData providerData = this.inboundsTree;

// TODO(terry): Need root deepCopy?
//    final CpuStackFrame root = data.cpuProfileRoot.deepCopy();

    final List<InboundsTreeNode> rows = providerData.data.root.children.cast();
    // TODO(terry): Work around bug if children have a parent (which they do
    // TODO(terry): the TreeTable won't render.
    for (InboundsTreeNode row in rows) row.parent = null;

    referencesTable.setRows(rows);
  }

  @override
  void reset() => referencesTable.setRows(<InboundsTreeNode>[]);
}

class InboundsTreeData {
  InboundsTreeData();

  InboundsTreeData.test() {
    final treeNode00 = InboundsTreeNode('class_0_0', 'field_0');
    final treeNode01 = InboundsTreeNode('class_0_1', 'field_1');
    final treeNode02 = InboundsTreeNode('class_0_2', 'field_2');
    final treeNode03 = InboundsTreeNode('class_0_3', 'field_3');
    final treeNode04 = InboundsTreeNode('class_0_4', 'field_4');
    final treeNode05 = InboundsTreeNode('class_0_5', 'field_5');

    final treeNode10 = InboundsTreeNode('class_1', 'field_a');
    final treeNode11 = InboundsTreeNode('class_1_1', 'field_b');
    final treeNode12 = InboundsTreeNode('class_1_2', 'field_c');
    final treeNode13 = InboundsTreeNode('class_1_3', 'field_d');
    final treeNode14 = InboundsTreeNode('class_4_4', 'field_e');
    final treeNode15 = InboundsTreeNode('class_1_5', 'field_f');

    final terryStuff = InboundsTreeNode(
        'TerryStuff allocated TerryExtra', 'extra [object/14752]');
    final shrineAppState1 = InboundsTreeNode('_ShrineAppState', '_stuff');
    final shrineAppState2 = InboundsTreeNode('_ShrineAppState', '_stuff2');
    final statefulElement1 = InboundsTreeNode('StatefulElement', 'state');
    final hashmapEntry1 = InboundsTreeNode('_HashMapEntry', '_key');
    final singleChildrenObjectElement1 =
        InboundsTreeNode('SingleChildrenObjectElement', '_child');
    final statefulElement2 = InboundsTreeNode('StatefulElement', 'state');
    final hashmapEntry2 = InboundsTreeNode('_HashMapEntry', '_key');
    final singleChildrenObjectElement2 =
        InboundsTreeNode('SingleChildrenObjectElement', '_child');

    data = InboundsTreeNode.root()
      ..addChild(treeNode00
        ..addChild(treeNode01)
        ..addChild(treeNode02
          ..addChild(treeNode03)
          ..addChild(treeNode04)
          ..addChild(treeNode05)))
      ..addChild(treeNode10
        ..addChild(treeNode11)
        ..addChild(treeNode12)
        ..addChild(treeNode13)
        ..addChild(treeNode14)
        ..addChild(treeNode15))
      ..addChild(terryStuff
        ..addChild(shrineAppState1
          ..addChild(statefulElement1
            ..addChild(hashmapEntry1..addChild(singleChildrenObjectElement1))))
        ..addChild(shrineAppState2
          ..addChild(statefulElement2
            ..addChild(
                hashmapEntry2..addChild(singleChildrenObjectElement2)))));
  }

  InboundsTreeNode data;
}

class InboundsTreeNode extends TreeNode<InboundsTreeNode> {
  InboundsTreeNode(this._name, this._fieldName, [this.instanceHashCode]);
  InboundsTreeNode.instance(this._instance, [this.instanceHashCode])
      : _name = _instance.objectRef,
        _fieldName = '';
  InboundsTreeNode.root()
      : _name = 'Instances',
        _fieldName = '',
        instanceHashCode = null;
  InboundsTreeNode.empty()
      : _name = null,
        _fieldName = null,
        instanceHashCode = null;

  String _name;

  InstanceSummary _instance;

  InstanceSummary get instance => _instance;

  String get name => _name;

  /// isNew signals objectRef (object/###) has changed.
  void setInstance(InstanceSummary theInstance, String hashCode,
      [bool isNew = false]) {
    _instance = theInstance;
    instanceHashCode = hashCode;
    _name = _name.split(' ')[0]; // Throw away instance objectRef name.
    _name = (isNew && !isInboundEntry)
        ? _instance.objectRef
        : '$name (${instance.objectRef})';
  }

  final String _fieldName;

  String get fieldName => _fieldName;

  bool get isInboundEntry => _fieldName?.isNotEmpty;

  String instanceHashCode;

  bool get isEmpty =>
      _name == null && _fieldName == null && instanceHashCode == null;
}

abstract class InstanceRefsView extends CoreElement {
  InstanceRefsView(this.inboundsTree) : super('div', classes: 'memory-table');

  final InboundsTreeData inboundsTree;

  bool viewNeedsRebuild = false;

  void rebuildView();

  void reset();

  void update({bool showLoadingSpinner = false}) async {
    if (inboundsTree == null) return;

    // Update the view if it is visible. Otherwise, mark the view as needing a
    // rebuild.
    if (!isHidden) {
      if (showLoadingSpinner) {
        final Spinner spinner = Spinner.centered();
        add(spinner);

        // Awaiting this future ensures the spinner pops up in between switching
        // profiler views. Without this, the UI is laggy and the spinner never
        // appears.
        await Future.delayed(const Duration(microseconds: 1));

        rebuildView();
        spinner.remove();
      } else {
        rebuildView();
      }
    } else {
      viewNeedsRebuild = true;
    }
  }

  void show() {
    hidden(false);
    if (viewNeedsRebuild) {
      viewNeedsRebuild = false;
      update(showLoadingSpinner: true);
    }
  }

  void hide() => hidden(true);
}

class ClassNameColumn extends TreeColumn<InboundsTreeNode> {
  ClassNameColumn(String title) : super(title);

  static const maxClassNameLength = 75;

  @override
  dynamic getValue(InboundsTreeNode dataObject) => dataObject.name;

  @override
  String getDisplayValue(InboundsTreeNode dataObject) {
    String name = dataObject.name;
    if (name.length > maxClassNameLength) {
      return name.substring(0, maxClassNameLength) + '...';
    }
    return name;
  }

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(InboundsTreeNode dataObject) =>
      '${dataObject.name} . ${dataObject.fieldName}';
}

//class FieldNameColumn extends TreeColumn<InboundsTreeNode> {
class FieldNameColumn extends Column<InboundsTreeNode> {
  FieldNameColumn() : super('Field Reference');

  static const maxFieldNameLength = 25;

  @override
  dynamic getValue(InboundsTreeNode dataObject) => dataObject.fieldName;

  @override
  String getDisplayValue(InboundsTreeNode dataObject) {
    String fieldName = dataObject.fieldName;
    if (fieldName.length > maxFieldNameLength) {
      return fieldName.substring(0, maxFieldNameLength) + '...';
    }
    return fieldName;
  }

  @override
  bool get supportsSorting => false;

  @override
  String getTooltip(InboundsTreeNode dataObject) =>
      '${dataObject.fieldName} OF ${dataObject.name}';
}
