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

  final StreamController<T> _selectionController =
      StreamController<T>.broadcast();
  final StreamController<T> _doubleClickController =
      StreamController<T>.broadcast();
  final StreamController<void> _itemsChangedController =
      StreamController<void>.broadcast();

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

  CoreElement _defaultRenderer(T item) {
    return li(text: item.toString(), c: 'list-item');
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
