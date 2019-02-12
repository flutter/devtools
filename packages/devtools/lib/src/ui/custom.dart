// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

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
    // TODO(dantup): Figure out why this doesn't work.
    element?.scrollIntoView();
    _selectionController.add(item);
  }
}

abstract class ChildProvider<T> {
  bool hasChildren(T item);

  Future<List<T>> getChildren(T item);
}

class SelectableTree<T> extends CoreElement {
  SelectableTree() : super('ul') {
    // Ensure the tree can be tabbed into.
    element.tabIndex = 0;
    element.onKeyDown.listen(handleKeyPress);
  }

  @visibleForTesting
  void handleKeyPress(KeyboardEvent e) {
    void handleDownKey() {
      if (_selectedItem != null) {
        final nextElm = _selectedItem.getNextVisibleElement();
        if (nextElm != null) {
          select(nextElm);
        }
      } else {
        if (treeItems.isNotEmpty) {
          select(treeItems.first);
        }
      }
    }

    void handleUpKey() {
      if (_selectedItem != null) {
        final prevElm = selectedItem.getPreviousVisibleElement();
        if (prevElm != null) {
          select(prevElm);
        }
      } else {
        if (treeItems.isNotEmpty) {
          select(treeItems.last.getLastVisibleDescendant() ?? treeItems.last);
        }
      }
    }

    void handleRightKey() {
      if (!_selectedItem.hasChildren) {
        return;
      }
      if (!_selectedItem.isExpanded) {
        _selectedItem.expand();
      } else {
        select(_selectedItem.visibleChildren.first);
      }
    }

    void handleLeftKey() {
      if (_selectedItem.isExpanded) {
        _selectedItem.collapse();
      } else if (_selectedItem.parent != null) {
        select(_selectedItem.parent);
      }
    }

    if (e.keyCode == KeyCode.DOWN) {
      handleDownKey();
    } else if (e.keyCode == KeyCode.UP) {
      handleUpKey();
    } else if (e.keyCode == KeyCode.RIGHT) {
      handleRightKey();
    } else if (e.keyCode == KeyCode.LEFT) {
      handleLeftKey();
    } else {
      return; // don't preventDefault if we were anything else.
    }

    e.preventDefault();
  }

  List<T> items = <T>[];
  List<TreeItem<T>> treeItems = [];
  ListRenderer<T> renderer;
  ChildProvider<T> childProvider;
  TreeItem<T> _selectedItem;
  TreeItem<T> get selectedItem => _selectedItem;

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

    final bool hadSelection = _selectedItem != null;
    _selectedItem = null;

    clear();

    treeItems = _populateItems(items, this, null);

    if (hadSelection && _selectedItem == null) {
      _selectionController.add(null);
    }
  }

  TreeItem<T> _populateInto(CoreElement container, T item) {
    final ListRenderer<T> renderer = this.renderer ?? _defaultRenderer;
    final TreeItem<T> obj = TreeItem<T>(renderer(item), item);
    obj.click(() {
      select(obj, clear: obj.hasClass('selected'));
    });

    final CoreElement element = div();
    element.add(obj);

    if (childProvider.hasChildren(item)) {
      final TreeToggle toggle = new TreeToggle();
      obj.element.children.insert(0, toggle.element);

      bool hasPopulated = false;
      final CoreElement childContainer = ul(c: 'tree-list');
      element.add(childContainer);
      childContainer.hidden(true);

      // Attach helpers that allow TreeItem to expand/collapse for use in
      // keyboard navigation.
      obj.expand = () => toggle.toggle(onlyExpand: true);
      obj.collapse = () => toggle.toggle(onlyCollapse: true);

      toggle.onOpen.listen((bool open) {
        obj.isExpanded = open;
        childContainer.hidden(!open);

        if (!hasPopulated) {
          hasPopulated = true;

          childProvider.getChildren(item).then((List<T> results) {
            _populateItems(results, childContainer, obj);
          }).catchError((e) {
            // ignore
          });
        }
      });
    } else {
      obj.element.children.insert(0, new TreeToggle(empty: true).element);
    }

    container.add(element);

    return obj;
  }

  /// Populates [results] into [container] while wiring up the TreeItem properties
  /// for tracking siblings/parents/children to allow keyboard navigation.
  List<TreeItem<T>> _populateItems(
    List results,
    CoreElement container,
    TreeItem<T> obj,
  ) {
    final List<TreeItem<T>> children = [];
    TreeItem<T> previousNode;

    for (T result in results) {
      final TreeItem<T> node = _populateInto(container, result);
      children.add(node);

      node.hasChildren = childProvider.hasChildren(result);
      node.parent = obj;

      if (previousNode != null) {
        node.previousSibling = previousNode;
        previousNode.nextSibling ??= node;
      }

      previousNode = node;
    }

    obj?.children?.addAll(children);
    return children;
  }

  void clearItems() {
    setItems(<T>[]);
  }

  @visibleForTesting
  void select(TreeItem<T> element, {bool clear = false}) {
    _selectedItem?.toggleClass('selected', false);

    if (clear) {
      element = null;
    }

    _selectedItem = element;
    element?.toggleClass('selected', true);
    _selectionController.add(element?.item);
  }
}

class TreeToggle extends CoreElement {
  TreeToggle({bool empty = false})
      : super('div', classes: 'tree-toggle octicon') {
    if (!empty) {
      click(toggle);
    }
    if (!empty) {
      clazz('octicon-triangle-right');
    }
  }

  void toggle({bool onlyExpand = false, bool onlyCollapse = false}) {
    if ((onlyExpand && _isOpen) || (onlyCollapse && !_isOpen)) {
      return;
    }
    _isOpen = !_isOpen;
    _openController.add(_isOpen);
    toggleClass('octicon-triangle-right', !_isOpen);
    toggleClass('octicon-triangle-down', _isOpen);
  }

  bool _isOpen = false;

  final StreamController<bool> _openController =
      new StreamController.broadcast();

  Stream<bool> get onOpen => _openController.stream;
}

class TreeItem<T> extends CoreElement {
  TreeItem(CoreElement core, this.item) : super.from(core.element);
  final T item;
  bool isExpanded = false, hasChildren = false;
  Function() expand, collapse;
  TreeItem<T> parent;
  TreeItem<T> previousSibling, nextSibling;
  final List<TreeItem<T>> children = [];
  List<TreeItem<T>> get visibleChildren => isExpanded ? children : [];

  TreeItem<T> getNextVisibleElement({includeChildren = true}) {
    // The next visible element below this one is first of:
    // - Our first child
    // - Our next sibling
    // - The next sibling of our parent
    // - The next sibling of our parents parent (recursive...)
    if (includeChildren && isExpanded && visibleChildren.isNotEmpty) {
      return visibleChildren.first;
    }
    return nextSibling ?? parent?.getNextVisibleElement(includeChildren: false);
  }

  TreeItem<T> getPreviousVisibleElement() {
    // The previous visible element above this one is first of:
    // - Our previous sibling's last visible ancestor
    // - Our previous sibling
    // - Our parent

    return previousSibling?.getLastVisibleDescendant() ??
        previousSibling ??
        parent;
  }

  TreeItem<T> getLastVisibleDescendant() {
    var node = this;
    while (node.isExpanded && node.visibleChildren.isNotEmpty) {
      node = node.visibleChildren.last;
    }
    return node;
  }
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
