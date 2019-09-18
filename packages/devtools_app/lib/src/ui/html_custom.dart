// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../ui/icons.dart';
import 'html_elements.dart';
import 'html_icon_renderer.dart';
import 'trees.dart';
import 'trees_html.dart';

class HtmlProgressElement extends CoreElement {
  HtmlProgressElement() : super('div') {
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

class HtmlSpinner extends CoreElement {
  HtmlSpinner({List<String> classes = const []}) : super('div') {
    clazz('spinner');
    classes.forEach(clazz);
  }

  static HtmlSpinner centered({List<String> classes = const []}) =>
      HtmlSpinner(classes: ['centered']..addAll(classes));

  void remove() => element.remove();
}

typedef ListRenderer<T> = CoreElement Function(T item);

class HtmlSelectableList<T> extends CoreElement {
  HtmlSelectableList() : super('div');

  List<T> items = <T>[];
  ListRenderer<T> renderer;
  CoreElement _selectedElement;

  bool _hadClicked = false;
  bool get hadClicked => _hadClicked;

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

  T selectedItem() {
    if (_selectedElement != null) {
      final childrenElements = element.children;
      for (var i = 0; i < childrenElements.length; i++) {
        final elem = childrenElements[i];
        if (elem.classes.contains('selected')) return items[i];
      }
    }

    return null;
  }

  void setItems(List<T> items,
      {T selection, bool scrollSelectionIntoView = false}) {
    this.items = items;

    final bool hadSelection = _selectedElement != null;

    _selectedElement = null;

    if (selection == null) {
      // Reset the clicked state.
      _hadClicked = false;
    }

    final ListRenderer<T> renderer = this.renderer ?? _defaultRenderer;

    clear();

    add(items.map((T item) {
      final CoreElement element = _hookup(renderer, item, selection);
      if (scrollSelectionIntoView && selection == item) {
        _selectedElement = element;
      }
      return element;
    }).toList());

    if (hadSelection) {
      if (_selectedElement == null) {
        _selectionController.add(null);
      } else if (_selectedElement != null) {
        _select(_selectedElement, selection);
      }
    }

    _itemsChangedController.add(null);
  }

  CoreElement setReplace(int index, T item) {
    _selectedElement?.toggleClass('selected', false);
    _selectedElement = null;

    final ListRenderer<T> renderer = this.renderer ?? _defaultRenderer;

    final CoreElement element = _hookup(renderer, item, item);

    replace(index, element);

    _select(element, item);

    return element;
  }

  CoreElement _hookup(ListRenderer<T> renderer, T item, T selection) {
    final CoreElement element = renderer(item);
    element.click(() {
      _select(element, item,
          clear: canDeselect && element.hasClass('selected'), clicked: true);
    });
    element.dblclick(() {
      _doubleClickController.add(item);
    });
    if (selection == item) {
      _select(element, item);
    }
    return element;
  }

  void clearItems() {
    setItems(<T>[]);
  }

  void _select(
    CoreElement element,
    T item, {
    bool clear = false,
    bool clicked = false,
  }) {
    _selectedElement?.toggleClass('selected', false);

    if (clear) {
      element = null;
      item = null;
    }

    _selectedElement = element;
    element?.toggleClass('selected', true);
    element?.scrollIntoView();
    _selectionController.add(item);
    _hadClicked = clicked;
  }
}

abstract class ChildProvider<T> {
  bool hasChildren(T item);

  Future<List<T>> getChildren(T item);
}

class HtmlSelectableTreeNodeItem<T> {
  HtmlSelectableTreeNodeItem(this.element, this.item);
  final CoreElement element;
  final T item;
}

class HtmlSelectableTree<T> extends CoreElement
    with
        Tree<HtmlSelectableTreeNodeItem<T>>,
        TreeNavigator<HtmlSelectableTreeNodeItem<T>>,
        HtmlTreeNavigator<HtmlSelectableTreeNodeItem<T>> {
  HtmlSelectableTree() : super('ul') {
    // Ensure the tree can be tabbed into.
    element.tabIndex = 0;
    element.onKeyDown.listen(handleKeyPress);
  }

  List<T> items = <T>[];
  @override
  List<TreeNode<HtmlSelectableTreeNodeItem<T>>> treeNodes = [];
  ListRenderer<T> renderer;
  ChildProvider<T> childProvider;
  TreeNode<HtmlSelectableTreeNodeItem<T>> _selectedItem;
  @override
  TreeNode<HtmlSelectableTreeNodeItem<T>> get selectedItem => _selectedItem;

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

    treeNodes = _buildTree(items, this, null);

    if (hadSelection && _selectedItem == null) {
      _selectionController.add(null);
    }
  }

  TreeNode<HtmlSelectableTreeNodeItem<T>> _addItemToTree(
      CoreElement container, T item) {
    final ListRenderer<T> renderer = this.renderer ?? _defaultRenderer;
    final obj = TreeNode(HtmlSelectableTreeNodeItem(renderer(item), item));
    obj.data.element.click(() {
      select(obj, clear: obj.data.element.hasClass('selected'));
    });

    final CoreElement element = div();
    element.add(obj.data.element);

    if (childProvider.hasChildren(item)) {
      final HtmlTreeToggle toggle = HtmlTreeToggle();
      obj.data.element.element.children.insert(0, toggle.element);

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
            _buildTree(results, childContainer, obj);
          }).catchError((e) {
            // ignore
          });
        }
      });
    } else {
      obj.data.element.element.children
          .insert(0, HtmlTreeToggle(empty: true).element);
    }

    container.add(element);

    return obj;
  }

  /// Builds a tree for [results] into [container].
  List<TreeNode<HtmlSelectableTreeNodeItem<T>>> _buildTree(
    List<T> results,
    CoreElement container,
    TreeNode<HtmlSelectableTreeNodeItem<T>> parent,
  ) {
    final List<TreeNode<HtmlSelectableTreeNodeItem<T>>> children =
        results.map((result) => _addItemToTree(container, result)).toList();

    connectNodes(
      parent,
      children,
      (node) => childProvider.hasChildren(node.item),
    );

    return children;
  }

  void clearItems() {
    setItems(<T>[]);
  }

  @override
  void select(
    TreeNode<HtmlSelectableTreeNodeItem<T>> node, {
    bool clear = false,
  }) {
    _selectedItem?.data?.element?.toggleClass('selected', false);

    if (clear) {
      node = null;
    }

    _selectedItem = node;
    _selectedItem?.data?.element?.toggleClass('selected', true);
    _selectedItem?.data?.element?.scrollIntoView();
    _selectionController.add(node?.data?.item);
  }
}

// TODO(kenz): wrap this element in a larger div to increase tap target.
class HtmlTreeToggle extends CoreElement {
  HtmlTreeToggle({bool empty = false, bool forceOpen = false})
      : super('div', classes: 'tree-toggle octicon') {
    if (!empty) {
      click(toggle);
      if (forceOpen) {
        _isOpen = true;
        clazz('octicon-triangle-down');
      } else {
        clazz('octicon-triangle-right');
      }
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

  final StreamController<bool> _openController = StreamController.broadcast();

  Stream<bool> get onOpen => _openController.stream;
}

CoreElement _defaultRenderer<T>(T item) {
  return li(text: item.toString(), c: 'list-item');
}

class HtmlActionButton implements CoreElementView {
  HtmlActionButton(this.id, this.icon, this.tooltip) {
    _element = div(c: 'masthead-item action-button')
      ..tooltip = tooltip
      ..add(createIconElement(icon));
  }

  final String id;
  final DevToolsIcon icon;
  final String tooltip;

  CoreElement _element;

  StreamSubscription click(void handle()) => _element.click(handle);

  set disabled(bool value) => _element.disabled = value;

  @override
  CoreElement get element => _element;
}
