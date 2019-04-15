// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import '../debugger/debugger_state.dart';
import '../ui/custom.dart';
import '../ui/elements.dart';

typedef VariableDescriber = Future<String> Function(BoundVariable variable);

class VariablesView implements CoreElementView {
  VariablesView(
      DebuggerState debuggerState, VariableDescriber variableDescriber) {
    _items = SelectableTree<BoundVariable>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..clazz('debugger-items-list');

    _items.setChildProvider(new VariablesChildProvider(debuggerState));

    _items.setRenderer((BoundVariable variable) {
      final String name = variable.name;
      final dynamic value = variable.value;

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

      final CoreElement element = li(c: 'list-item')
        ..add([
          span(text: name),
          span(text: ' $valueStr', c: 'subtle'),
        ]);

      StreamSubscription sub;

      sub = element.element.onMouseOver.listen((e) {
        // TODO(devoncarew): Call toString() only after a short dwell.
        sub.cancel();
        variableDescriber(variable).then((String desc) {
          element.tooltip = desc;
        });
      });

      return element;
    });
  }

  SelectableTree<BoundVariable> _items;

  List<BoundVariable> get items => _items.items;

  @override
  CoreElement get element => _items;

  void showVariables(Frame frame) {
    // AsyncCausal frames don't have local vars.
    _items.setItems(frame.vars ?? <BoundVariable>[]);
  }

  void clearVariables() {
    _items.setItems(<BoundVariable>[]);
  }
}

class VariablesChildProvider extends ChildProvider<BoundVariable> {
  VariablesChildProvider(this.debuggerState);

  final DebuggerState debuggerState;

  @override
  bool hasChildren(BoundVariable item) {
    final dynamic value = item.value;
    return value is InstanceRef && value.valueAsString == null;
  }

  @override
  Future<List<BoundVariable>> getChildren(BoundVariable item) async {
    final dynamic value = item.value;
    if (value is! InstanceRef) {
      return [];
    }

    final InstanceRef instanceRef = value;
    final dynamic result = await debuggerState.getInstance(instanceRef);
    if (result is! Instance) {
      return [];
    }

    // TODO: how to test?

    final Instance instance = result;
    if (instance.associations != null) {
      return instance.associations.map((MapAssociation assoc) {
        // For string keys, quote the key value.
        String keyString = assoc.key.valueAsString;
        if (assoc.key is InstanceRef &&
            assoc.key.kind == InstanceKind.kString) {
          keyString = "'$keyString'";
        }
        return new BoundVariable()
          ..name = '[$keyString]'
          ..value = assoc.value;
      }).toList();
    } else if (instance.elements != null) {
      final List<BoundVariable> result = [];
      int index = 0;

      for (dynamic value in instance.elements) {
        result.add(new BoundVariable()
          ..name = '[$index]'
          ..value = value);
        index++;
      }

      return result;
    } else if (instance.fields != null) {
      return instance.fields.map((BoundField field) {
        return new BoundVariable()
          ..name = field.decl.name
          ..value = field.value;
      }).toList();
    } else {
      return [];
    }
  }
}
