// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'elements.dart';

class ProgressElement extends CoreElement {
  ProgressElement() : super('div') {
    clazz('progress-element');
    add(completeElement = div(c: 'complete'));
  }

  int _value = 0;
  int _max = 100;
  CoreElement completeElement;

  int get value => _value;

  set value(int val) {
    _value = val;

    _update();
  }

  int get max => _max;

  set max(int val) {
    _max = val;

    _update();
  }

  void _update() {
    // TODO(devoncarew): don't hard-code the width
    completeElement.element.style.width = '${(200 * _value / _max).round()}px';
  }
}

class Spinner extends CoreElement {
  Spinner() : super('div') {
    clazz('spinner');
  }
}

typedef ListRenderer<T> = CoreElement Function(T item);

class SelectableList<T> extends CoreElement {
  SelectableList() : super('div');

  List<T> items = <T>[];
  ListRenderer<T> renderer;
  CoreElement _selectedElement;

  final StreamController<T> _selectionController = StreamController.broadcast();
  final StreamController<T> _doubleClickController =
      StreamController.broadcast();
  final StreamController<void> _itemsChangedController =
      StreamController.broadcast();

  bool canDeselect = false;

  Stream<T> get onSelectionChanged => _selectionController.stream;

  Stream<T> get onDoubleClick => _doubleClickController.stream;

  Stream<void> get onItemsChanged => _itemsChangedController.stream;

  void setRenderer(ListRenderer<T> renderer) {
    this.renderer = renderer;
  }

  void setItems(List<T> items, {T selection}) {
    this.items = items;

    final bool hadSelection = _selectedElement != null;

    _selectedElement = null;

    final ListRenderer<T> renderer = this.renderer ?? _defaultRenderer;

    clear();

    add(items.map((T item) {
      final CoreElement element = renderer(item);
      element.click(() {
        _select(element, item,
            clear: canDeselect && element.hasClass('selected'));
      });
      element.dblclick(() {
        _doubleClickController.add(item);
      });
      if (selection == item) {
        _select(element, item);
      }
      return element;
    }).toList());

    if (hadSelection && _selectedElement == null) {
      _selectionController.add(null);
    }

    _itemsChangedController.add(null);
  }

  void clearItems() {
    setItems(<T>[]);
  }

  void _select(CoreElement element, T item, {bool clear = false}) {
    _selectedElement?.toggleClass('selected', false);

    if (clear) {
      element = null;
      item = null;
    }

    _selectedElement = element;
    element?.toggleClass('selected', true);
    _selectionController.add(item);
  }
}

abstract class ChildProvider<T> {
  bool hasChildren(T item);

  Future<List<T>> getChildren(T item);
}

class SelectableTree<T> extends CoreElement {
  SelectableTree() : super('ul');

  List<T> items = <T>[];
  ListRenderer<T> renderer;
  ChildProvider<T> childProvider;
  CoreElement _selectedElement;

  final StreamController<T> _selectionController = StreamController.broadcast();

  Stream<T> get onSelectionChanged => _selectionController.stream;

  void setRenderer(ListRenderer<T> renderer) {
    this.renderer = renderer;
  }

  void setChildProvider(ChildProvider<T> childProvider) {
    this.childProvider = childProvider;
  }

  void setItems(List<T> items) {
    this.items = items;

    final bool hadSelection = _selectedElement != null;
    _selectedElement = null;

    clear();

    for (T item in items) {
      _populateInto(this, item);
    }

    if (hadSelection && _selectedElement == null) {
      _selectionController.add(null);
    }
  }

  void _populateInto(CoreElement parent, T item) {
    final ListRenderer<T> renderer = this.renderer ?? _defaultRenderer;
    final CoreElement obj = renderer(item);
    obj.click(() {
      _select(obj, item, clear: obj.hasClass('selected'));
    });

    final CoreElement element = div();
    element.add(obj);

    if (childProvider.hasChildren(item)) {
      final TreeToggle toggle = new TreeToggle();
      obj.element.children.insert(0, toggle.element);

      bool hasPopulated = false;
      final CoreElement children = ul(c: 'tree-list');
      element.add(children);
      children.hidden(true);

      toggle.onOpen.listen((bool open) {
        children.hidden(!open);

        if (!hasPopulated) {
          hasPopulated = true;

          childProvider.getChildren(item).then((List<T> results) {
            for (T result in results) {
              _populateInto(children, result);
            }
          }).catchError((e) {
            // ignore
          });
        }
      });
    } else {
      obj.element.children.insert(0, new TreeToggle(empty: true).element);
    }

    parent.add(element);
  }

  void clearItems() {
    setItems(<T>[]);
  }

  void _select(CoreElement element, T item, {bool clear = false}) {
    _selectedElement?.toggleClass('selected', false);

    if (clear) {
      element = null;
      item = null;
    }

    _selectedElement = element;
    element?.toggleClass('selected', true);
    _selectionController.add(item);
  }
}

class TreeToggle extends CoreElement {
  TreeToggle({bool empty = false})
      : super('div', classes: 'tree-toggle octicon') {
    if (!empty) {
      click(() {
        _isOpen = !_isOpen;
        _openController.add(_isOpen);
        toggleClass('octicon-triangle-right', !_isOpen);
        toggleClass('octicon-triangle-down', _isOpen);
      });
    }
    if (!empty) {
      clazz('octicon-triangle-right');
    }
  }

  bool _isOpen = false;

  final StreamController<bool> _openController =
      new StreamController.broadcast();

  Stream<bool> get onOpen => _openController.stream;
}

CoreElement _defaultRenderer<T>(T item) {
  return li(text: item.toString(), c: 'list-item');
}

class ActionButton implements CoreElementView {
  ActionButton(this.iconPath, this.tooltip) {
    _element = div(c: 'masthead-item action-button')
      ..add(img(src: iconPath)..tooltip = tooltip);
  }

  final String iconPath;
  final String tooltip;

  CoreElement _element;

  StreamSubscription click(void handle()) => _element.click(handle);

  set disabled(bool value) => _element.disabled = value;

  @override
  CoreElement get element => _element;
}
