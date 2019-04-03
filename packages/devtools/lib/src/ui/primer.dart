// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

import 'elements.dart';
import 'html_icon_renderer.dart';
import 'icons.dart';

class PSelect extends CoreElement {
  PSelect() : super('select', classes: 'form-select');

  void small() => clazz('select-sm');

  void option(String name, {String value}) {
    final CoreElement e = CoreElement('option', text: name);
    if (value != null) {
      final OptionElement optionElement = e.element;
      optionElement.value = value;
    }
    add(e);
  }

  String get value {
    final SelectElement selectElement = element;
    return selectElement.value;
  }

  set selectedIndex(int index) {
    final SelectElement selectedElement = element;
    selectedElement.selectedIndex = index;
  }

  Stream<Event> get onChange => element.onChange.where((_) => !disabled);

  /// Subscribe to the [onChange] event stream with a no-arg handler.
  StreamSubscription<Event> change(void handle()) {
    return onChange.listen((Event e) {
      e.stopImmediatePropagation();
      handle();
    });
  }
}

class PTooltip {
  static void add(CoreElement element, String text) {
    element.toggleClass('tooltipped', true);
    element.toggleClass('tooltipped-nw', true);
    element.setAttribute('aria-label', text);
  }

  static void remove(CoreElement element) {
    element.toggleClass('tooltipped', false);
    element.toggleClass('tooltipped-nw', false);
    element.toggleAttribute('aria-label', false);
  }
}

class PButton extends CoreElement {
  PButton([String text]) : super('button', text: text, classes: 'btn') {
    setAttribute('type', 'button');
  }

  PButton.octicon(String text, {@required String icon})
      : super('button', classes: 'btn optional-text') {
    tooltip = text;
    add(<CoreElement>[
      span(c: 'octicon octicon-$icon'),
      span(c: 'optional-text', text: text),
    ]);
    small();
  }

  PButton.icon(String text, Icon icon, {String title, List<String> classes})
      : super('button', classes: 'btn optional-text') {
    setAttribute('type', 'button');
    setAttribute('title', title ?? text);
    classes?.forEach(clazz);
    if (icon != null) {
      _icon = icon;
      add(createIconElement(icon));
      if (text != null) {
        add(span(text: text));
      }
    } else {
      element.text = text;
    }
  }

  Icon _icon;

  void changeIcon(String url) {
    if (_icon != null) {
      element.children.first.style.backgroundImage = 'url("$url")';
    }
  }

  void primary() => clazz('btn-primary');

  void small() => clazz('btn-sm');
}

class PFlash extends CoreElement {
  PFlash({String text}) : super('div', classes: 'flash', text: text);

  void warning() {
    clazz('flash-warn');
  }

  void error() {
    clazz('flash-error');
  }

  CoreElement addClose() {
    return add(span(c: 'octicon octicon-x flash-close js-flash-close'));
  }
}

/// A tabbed container (ala Chrome tabs).
class PTabNav extends CoreElement {
  PTabNav(List<PTabNavTab> tabs) : super('div', classes: 'tabnav') {
    final CoreElement nav = add(CoreElement('nav', classes: 'tabnav-tabs'));
    nav.add(tabs);

    if (tabs.isNotEmpty) {
      selectTab(tabs.first);
    }

    for (PTabNavTab tab in tabs) {
      tab.click(() {
        selectTab(tab);
      });
    }
  }

  final StreamController<PTabNavTab> _selectedTabController =
      StreamController<PTabNavTab>.broadcast();

  Stream<PTabNavTab> get onTabSelected => _selectedTabController.stream;

  PTabNavTab selectedTab;

  void selectTab(PTabNavTab tab) {
    selectedTab?.toggleClass('selected', false);
    selectedTab = tab;
    selectedTab?.toggleClass('selected', true);
    _selectedTabController.add(selectedTab);
  }
}

class PTabNavTab extends CoreElement {
  PTabNavTab(String name) : super('div', classes: 'tabnav-tab', text: name);
}

/// A menu navigation element - a vertically oriented list of items.
class PNavMenu extends CoreElement {
  PNavMenu(
    List<CoreElement> items, {
    bool supportsSelection = true,
  }) : super('nav', classes: 'menu') {
    add(items);

    if (supportsSelection) {
      if (items.isNotEmpty && items.first is PNavMenuItem) {
        selectItem(items.first);
      }

      for (CoreElement item in items) {
        if (item is PNavMenuItem) {
          item.click(() => selectItem(item));
        }
      }
    }
  }

  PNavMenuItem selectedItem;

  void selectItem(PNavMenuItem item) {
    selectedItem?.toggleClass('selected', false);
    selectedItem = item;
    selectedItem?.toggleClass('selected', true);
  }
}

class PNavMenuItem extends CoreElement {
  PNavMenuItem(String name) : super('a', classes: 'menu-item', text: name);
}
