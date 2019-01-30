// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

import 'package:meta/meta.dart';

import '../main.dart';
import '../ui/custom.dart';
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

    globalActions =
        ActionsContainer(CoreElement.from(querySelector('#global-actions')));
  }

  final List<Screen> screens = <Screen>[];

  Screen current;

  StatusLine globalStatus;
  StatusLine pageStatus;
  StatusLine auxiliaryStatus;
  ActionsContainer globalActions;

  final Map<Screen, CoreElement> _screenContents = {};

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

  void load(Screen screen) {
    if (current == null) {
      mainElement.element.children.clear();
    }

    if (current != null) {
      final Screen oldScreen = current;
      current = null;
      oldScreen.exiting();
      oldScreen.visible = false;

      pageStatus.removeAll();

      _screenContents[oldScreen].hidden(true);
    }

    current = screen;

    if (_screenContents.containsKey(current)) {
      _screenContents[current].hidden(false);
    } else {
      current.framework = this;

      final CoreElement screenContent = current.createContent(this);
      screenContent.attribute('full');
      mainElement.add(screenContent);

      _screenContents[current] = screenContent;
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

  void showInfo(String message, {String title}) {
    _showMessage(message, title: title);
  }

  void showWarning(String message, {String title}) {
    _showMessage(message, title: title, warning: true);
  }

  void showError(String title, [dynamic error]) {
    String message;
    if (error != null) {
      message = '$error';
      // Only display the error object if it has a custom Dart toString.
      if (message.startsWith('[object ') ||
          message.startsWith('Instance of ')) {
        message = null;
      }
    }

    _showMessage(message, title: title, error: true);
  }

  void _showMessage(
    String message, {
    String title,
    bool warning = false,
    bool error = false,
  }) {
    final PFlash flash = PFlash();
    if (warning) {
      flash.warning();
    }
    if (error) {
      flash.error();
    }
    flash.addClose().click(clearMessages);
    if (title != null) {
      flash.add(label(text: title));
    }
    if (message != null) {
      for (String text in message.split('\n\n')) {
        flash.add(div(text: text));
      }
    }

    final CoreElement errorContainer =
        CoreElement.from(querySelector('#messages-container'));
    errorContainer.add(flash);
  }

  void clearMessages() {
    querySelector('#messages-container').children.clear();
  }

  void toast(String message, {String title}) {
    final Toast toast = Toast(title: title, message: message);
    final CoreElement toastContainer =
        CoreElement.from(querySelector('#toast-container'));
    toastContainer.add(toast);
    toast.show();
  }

  void addGlobalAction(ActionButton action) {
    globalActions.addAction(action);
  }

  void clearGlobalActions() {
    globalActions.clearActions();
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

class ActionsContainer {
  ActionsContainer(this.element);

  final CoreElement element;
  final List<ActionButton> _actions = [];

  void addAction(ActionButton action) {
    if (_actions.isEmpty) {
      // add a visual separator
      element.add(span(text: '•', a: 'horiz-padding', c: 'masthead-item'));
    }

    _actions.add(action);
    element.add(action.element);
  }

  void clearActions() {
    _actions.clear();
    element.clear();
  }
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

  CoreElement createContent(Framework framework);

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

class Toast extends CoreElement {
  Toast({this.title, this.message}) : super('div', classes: 'toast') {
    if (title != null) {
      add(label(text: title));
    }
    add(div(text: message));
  }

  static const Duration animationDelay = Duration(milliseconds: 500);
  static const Duration hideDelay = Duration(seconds: 4);

  final String title;
  @required
  final String message;

  void show() async {
    await window.animationFrame;

    element.style.left = '0px';

    Timer(animationDelay, () {
      Timer(hideDelay, _hide);
    });
  }

  void _hide() {
    element.style.left = '400px';

    Timer(animationDelay, dispose);
  }

  @override
  String toString() => '$title $message';
}
