// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

import 'package:vm_service_lib/vm_service_lib.dart';
import 'package:meta/meta.dart';

import '../globals.dart';
import '../main.dart';
import '../service.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../utils.dart';

class Framework {
  final List<Screen> screens = [];
  Screen current;
  StatusLine globalStatus;
  StatusLine pageStatus;

  Framework() {
    window.onPopState.listen(handlePopState);
    globalStatus =
        new StatusLine(new CoreElement.from(querySelector('#global-status')));
    pageStatus =
        new StatusLine(new CoreElement.from(querySelector('#page-status')));
  }

  void addScreen(Screen screen) {
    screens.add(screen);
  }

  void navigateTo(String id) {
    Screen screen = getScreen(id);
    assert(screen != null);

    String search = window.location.search;
    String ref = search == null ? screen.ref : '${screen.ref}$search';
    window.history.pushState(null, screen.name, ref);

    load(screen);
  }

  void performInitialLoad() {
    loadScreenFromLocation();
    _initService();
  }

  void loadScreenFromLocation() {
    // Look for an explicit path, otherwise re-direct to '/'
    String path = window.location.pathname;

    // Special case the development path.
    if (path == '/devtools/web/index.html' || path == '/index.html') {
      path = '/';
    }

    String first =
        (path.startsWith('/') ? path.substring(1) : path).split('/').first;
    Screen screen = getScreen(first.isEmpty ? path : first);
    if (screen == null && path == '/') {
      screen = screens.first;
    }
    if (screen != null) {
      load(screen);
    } else {
      load(new NotFoundScreen());
    }
  }

  void _initService() {
    int port;

    if (window.location.search.isNotEmpty) {
      Uri uri = Uri.parse(window.location.toString());
      String portStr = uri.queryParameters['port'];
      if (portStr != null) {
        port = int.tryParse(portStr);
      }
    }

    port ??= 8100;

    Completer<void> finishedCompleter = new Completer<void>();

    connect('localhost', port, finishedCompleter).then((VmService service) {
      serviceInfo.vmServiceOpened(service, finishedCompleter.future);
    }).catchError((e) {
      showError('Unable to connect to service on port $port');
    });
  }

  Screen getScreen(String id) {
    return screens.firstWhere((s) => s.id == id, orElse: () => null);
  }

  void handlePopState(PopStateEvent event) {
    loadScreenFromLocation();
  }

  CoreElement get mainElement =>
      new CoreElement.from(querySelector('#content'));

  final Map<Screen, List<Element>> _contents = {};

  void load(Screen screen) {
    if (current != null) {
      current.exiting();
      pageStatus.removeAll();
      _contents[current] = mainElement.element.children.toList();
      mainElement.element.children.clear();
    } else {
      mainElement.element.children.clear();
    }

    current = screen;

    if (_contents.containsKey(current)) {
      mainElement.element.children.addAll(_contents[current]);
    } else {
      current.createContent(this, mainElement);
    }

    current.entering();
    pageStatus.addAll(current.statusItems);

    updatePage();
  }

  void updatePage() {
    // nav
    for (Element element in querySelectorAll('#main-nav a')) {
      CoreElement e = new CoreElement.from(element);
      bool isCurrent = current.ref == element.attributes['href'];
      e.toggleClass('active', isCurrent);
    }

    // status
    CoreElement helpLink = new CoreElement.from(querySelector('#docsLink'));
    HelpInfo helpInfo = current.helpInfo;
    if (helpInfo == null) {
      helpLink.hidden(true);
    } else {
      helpLink
        ..clear()
        ..add([
          span(text: '${helpInfo.title} '),
          span(c: 'octicon octicon-link-external small-octicon'),
        ])
        ..setAttribute('href', helpInfo.url)
        ..hidden(false);
    }
  }

  void showError(String title, [dynamic error]) {
    PFlash flash = new PFlash();
    flash.addClose().click(clearError);
    flash.add(span(text: title));
    if (error != null) {
      flash.add(new CoreElement('br'));
      flash.add(span(text: '$error'));
    }

    CoreElement errorContainer =
        new CoreElement.from(querySelector('#error-container'));
    errorContainer.add(flash);
  }

  void clearError() {
    querySelector('#error-container').children.clear();
  }
}

class StatusLine {
  final CoreElement element;
  final List<StatusItem> _items = [];

  StatusLine(this.element);

  void add(StatusItem item) {
    _items.add(item);

    _rebuild();
  }

  void _rebuild() {
    element.clear();

    if (_items.isNotEmpty) {
      element.add(_items.first.element);

      for (StatusItem item in _items.sublist(1)) {
        element.add(new SpanElement()
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
  // TODO:
  print(message);
}

abstract class Screen {
  final String name;
  final String id;
  final String iconClass;

  final Property<bool> _visible = new Property(true);

  final List<StatusItem> statusItems = [];

  // TODO(devoncarew): Switch to using named args (and @required).
  Screen(this.name, this.id, [this.iconClass]);

  String get ref => id == '/' ? id : '/$id';

  bool get visible => _visible.value;

  set visible(bool value) {
    _visible.value = value;
  }

  Stream<bool> get onVisibleChange => _visible.onValueChange;

  void createContent(Framework framework, CoreElement mainDiv) {}

  void entering() {}

  void exiting() {}

  // TODO(devoncarew): generalize this - global and page status items
  void addStatusItem(StatusItem item) {
    // TODO(devoncarew): If we're live, add to the screen
    statusItems.add(item);
  }

  void removeStatusItems(StatusItem item) {
    // TODO(devoncarew): If we're live, remove from the screen
    statusItems.remove(item);
  }

  HelpInfo get helpInfo => null;

  String toString() => 'Screen($id)';
}

class SetStateMixin {
  Timer timer;

  void setState(Function rebuild) {
    timer?.cancel();
    // TODO(devoncarew): listen for rAFs instead
    timer = new Timer(Duration.zero, rebuild);
  }
}

class HelpInfo {
  final String title;
  final String url;

  HelpInfo({
    @required this.title,
    @required this.url,
  });
}

class StatusItem {
  final CoreElement element;

  StatusItem() : element = span();
}
