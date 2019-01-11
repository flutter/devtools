// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

import 'package:meta/meta.dart';

import '../main.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../utils.dart';

class Framework {
  Framework() {
    window.onPopState.listen(handlePopState);

    globalStatus =
        StatusLine(CoreElement.from(querySelector('#global-status')));
    pageStatus = StatusLine(CoreElement.from(querySelector('#page-status')));
    auxiliaryStatus =
        StatusLine(CoreElement.from(querySelector('#auxiliary-status')));
  }

  final List<Screen> screens = <Screen>[];

  Screen current;

  StatusLine globalStatus;
  StatusLine pageStatus;
  StatusLine auxiliaryStatus;

  void addScreen(Screen screen) {
    screens.add(screen);
  }

  void navigateTo(String id) {
    final Screen screen = getScreen(id);
    assert(screen != null);

    final String search = window.location.search;
    final String ref = search == null ? screen.ref : '$search${screen.ref}';
    window.history.pushState(null, screen.name, ref);

    load(screen);
  }

  void loadScreenFromLocation() {
    // Screens are identified by the hash as that works better with the webdev
    // server.
    String id = window.location.hash;
    if (id.isNotEmpty) {
      assert(id[0] == '#');
      id = id.substring(1);
    }
    Screen screen = getScreen(id);
    screen ??= screens.first;
    if (screen != null) {
      load(screen);
    } else {
      load(NotFoundScreen());
    }
  }

  Screen getScreen(String id) {
    return screens.firstWhere((Screen screen) => screen.id == id,
        orElse: () => null);
  }

  void handlePopState(PopStateEvent event) {
    loadScreenFromLocation();
  }

  CoreElement get mainElement => CoreElement.from(querySelector('#content'));

  final Map<Screen, List<Element>> _contents = <Screen, List<Element>>{};

  void load(Screen screen) {
    if (current != null) {
      final Screen oldScreen = current;
      current = null;
      oldScreen.exiting();
      oldScreen.visible = false;

      pageStatus.removeAll();
      _contents[oldScreen] = mainElement.element.children.toList();
      mainElement.element.children.clear();
    } else {
      mainElement.element.children.clear();
    }

    current = screen;

    if (_contents.containsKey(current)) {
      mainElement.element.children.addAll(_contents[current]);
    } else {
      current.framework = this;
      current.createContent(this, mainElement);
    }

    current.visible = true;
    current.entering();
    pageStatus.addAll(current.statusItems);

    updatePage();
  }

  void updatePage() {
    // nav
    for (Element element in querySelectorAll('#main-nav a')) {
      final CoreElement e = CoreElement.from(element);
      final bool isCurrent = current.ref == element.attributes['href'];
      e.toggleClass('active', isCurrent);
    }
  }

  void showError(String title, [dynamic error]) {
    final PFlash flash = PFlash();
    flash.addClose().click(clearError);
    flash.add(span(text: title));
    if (error != null) {
      flash.add(span(text: '$error'));
    }

    final CoreElement errorContainer =
        CoreElement.from(querySelector('#error-container'));
    errorContainer.add(flash);
  }

  void clearError() {
    querySelector('#error-container').children.clear();
  }
}

class StatusLine {
  StatusLine(this.element);

  final CoreElement element;
  final List<StatusItem> _items = <StatusItem>[];

  void add(StatusItem item) {
    _items.add(item);

    _rebuild();
  }

  void _rebuild() {
    element.clear();

    if (_items.isNotEmpty) {
      element.add(_items.first.element);

      for (StatusItem item in _items.sublist(1)) {
        element.add(SpanElement()
          ..text = '•'
          ..classes.add('separator'));
        element.add(item.element);
      }
    }
  }

  void remove(StatusItem item) {
    _items.remove(item);

    _rebuild();
  }

  void addAll(List<StatusItem> items) {
    _items.addAll(items);

    _rebuild();
  }

  void removeAll() {
    _items.clear();
    _rebuild();
  }
}

void toast(String message) {
  // TODO(devoncarew): Display this message in the UI.
  print(message);
}

abstract class Screen {
  Screen({
    @required this.name,
    @required this.id,
    this.iconClass,
  });

  final String name;
  final String id;
  final String iconClass;

  Framework framework;

  final Property<bool> _visible = Property<bool>(false);

  final List<StatusItem> statusItems = <StatusItem>[];

  String get ref => id.isEmpty ? id : '#$id';

  bool get visible => _visible.value;

  set visible(bool value) {
    _visible.value = value;
  }

  Stream<bool> get onVisibleChange => _visible.onValueChange;

  void createContent(Framework framework, CoreElement mainDiv);

  void entering() {}

  bool get isCurrentScreen => framework != null && framework.current == this;

  void exiting() {}

  void addStatusItem(StatusItem item) {
    statusItems.add(item);
  }

  void removeStatusItems(StatusItem item) {
    statusItems.remove(item);
  }

  @override
  String toString() => 'Screen($id)';
}

class SetStateMixin {
  void setState(Function rebuild) {
    window.requestAnimationFrame((_) => rebuild());
  }
}

class HelpInfo {
  HelpInfo({
    @required this.title,
    @required this.url,
  });

  final String title;
  final String url;
}

class StatusItem {
  StatusItem() : element = span();

  final CoreElement element;
}
