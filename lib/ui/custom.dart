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
      new StreamController<T>.broadcast();

  Stream<T> get onSelectionChanged => _selectionController.stream;

  void setRenderer(ListRenderer<T> renderer) {
    this.renderer = renderer;
  }

  void setItems(List<T> items) {
    this.items = items;

    _selectedElement = null;

    final ListRenderer<T> renderer = this.renderer ?? _defaultRenderer;

    clear();

    add(items.map((T item) {
      final CoreElement element = renderer(item);
      element.click(() {
        _selectedElement?.toggleClass('selected', false);
        _selectedElement = element;
        element.toggleClass('selected', true);
        _selectionController.add(item);
      });
      return element;
    }).toList());
  }

  void clearItems() {
    setItems(<T>[]);
  }

  CoreElement _defaultRenderer(T item) {
    return li(text: item.toString(), c: 'list-item');
  }
}
