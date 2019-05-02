// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import '../memory/memory_controller.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';

typedef MemoryDescriber = Future<String> Function(BoundField variable);

class MemoryDataView implements CoreElementView {
  MemoryDataView(this._memoryController, MemoryDescriber variableDescriber) {
    _items = SelectableTree<BoundField>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..clazz('debugger-items-list')
      ..clazz('memory-inspector-items-list');

    _items.setChildProvider(new MemoryDataChildProvider(_memoryController));

    _items.setRenderer((BoundField field) {
      final String name = field.decl.name;
      final dynamic value = field.value;

      String valueStr;

      if (value is InstanceRef) {
        if (value.valueAsString == null) {
          valueStr = value.classRef.name;
        } else {
          valueStr = value.valueAsString;
          if (value.valueAsStringIsTruncated) {
            valueStr += '...';
          }
          if (value.kind == InstanceKind.kString) {
            valueStr = "'$valueStr'";
          }
        }

        if (value.kind == InstanceKind.kList) {
          valueStr = '[${value.length}] $valueStr';
        } else if (value.kind == InstanceKind.kMap) {
          valueStr = '{ ${value.length} } $valueStr';
        } else if (value.kind != null && value.kind.endsWith('List')) {
          // Uint8List, Uint16List, ...
          valueStr = '[${value.length}] $valueStr';
        }
      } else if (value is Sentinel) {
        valueStr = value.valueAsString;
      } else if (value is TypeArgumentsRef) {
        valueStr = value.name;
      } else {
        valueStr = value.toString();
      }

      final CoreElement element = li(c: 'memory-instance-data-list-item')
        ..add([
          span(text: name),
          span(text: ' $valueStr', c: 'subtle'),
        ]);

      StreamSubscription sub;

      sub = element.element.onMouseOver.listen((e) {
        // TODO(devoncarew): Call toString() only after a short dwell.
        sub.cancel();
        variableDescriber(field).then((String desc) {
          element.tooltip = desc;
        });
      });

      return element;
    });
  }

  MemoryController _memoryController;
  SelectableTree<BoundField> _items;

  List<BoundField> get items => _items.items;

  @override
  CoreElement get element => _items;

  void showFields(List<BoundField> fields) {
    // AsyncCausal frames don't have local vars.
    _items.setItems(fields);
  }

  void clearFields() {
    _items.setItems(<BoundField>[]);
  }
}

class MemoryDataChildProvider extends ChildProvider<BoundField> {
  MemoryDataChildProvider(this._memoryController);

  final MemoryController _memoryController;

  @override
  bool hasChildren(BoundField item) =>
      item.value is InstanceRef && item.value.valueAsString == null;

  @override
  Future<List<BoundField>> getChildren(BoundField item) async {
    final BoundField field = item;

    if (field.value != null && field.value is InstanceRef) {
      switch (field.value.kind) {
        case InstanceKind.kPlainInstance:
          final Instance instance =
              await _memoryController.getObject(field.value.id);
          return instance.fields;
          break;
        case InstanceKind.kList:
          final Instance instance =
              await _memoryController.getObject(field.value.id);
          final List<BoundField> result = [];

          int index = 0;
          for (dynamic value in instance.elements) {
            result.add(new BoundField()
              ..decl = (FieldRef()..name = '[$index]')
              ..value = value);
            index++;
          }
          return result;
          break;
        case InstanceKind.kMap:
          final Instance instance =
          await _memoryController.getObject(field.value.id);

          final List<BoundField> result = [];
          for (dynamic value in instance.associations) {
            result.add(new BoundField()
              // TODO(terry): Need to handle nested objects for keys/values.
              ..decl = (FieldRef()..name = '[${value.key.valueAsString}]')
              ..value = value.value.valueAsString);
          }
          return result;
          break;
        case InstanceKind.kStackTrace:
          print('TODO(terry): Handle StackTrace type.');
          break;
        case InstanceKind.kClosure:
          print('TODO(terry): Handle Closure type.');
          break;
        // TODO(terry): Do we need to handle WeakProperty, Type, TypeParameter,
        // TODO(terry): TypeDef or BoundedType?
      }
    }

    return [];
  }
}
