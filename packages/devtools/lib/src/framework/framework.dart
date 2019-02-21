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
import 'framework_core.dart';

class Framework {
  Framework() {
    window.onPopState.listen(handlePopState);

    globalStatus = StatusLine(CoreElement.from(queryId('global-status')));
    pageStatus = StatusLine(CoreElement.from(queryId('page-status')));
    auxiliaryStatus = StatusLine(CoreElement.from(queryId('auxiliary-status')));

    globalActions =
        ActionsContainer(CoreElement.from(queryId('global-actions')));

    connectDialog = new ConnectDialog(this);
  }

  final List<Screen> screens = <Screen>[];

  Screen current;

  StatusLine globalStatus;
  StatusLine pageStatus;
  StatusLine auxiliaryStatus;
  ActionsContainer globalActions;
  ConnectDialog connectDialog;

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

  void showConnectionDialog() {
    connectDialog.show();
  }

  void loadScreenFromLocation() {
    // Screens are identified by the hash as that works better with the webdev
    // server.
    String id = window.location.hash;
    if (id.isNotEmpty) {
      assert(id[0] == '#');
      id = id.substring(1);
    }
    Screen screen = getScreen(id, onlyEnabled: true);
    screen ??= screens.first;
    if (screen != null) {
      load(screen);
    } else {
      load(NotFoundScreen());
    }
  }

  Screen getScreen(String id, {bool onlyEnabled = false}) {
    return screens.firstWhere(
        (Screen screen) =>
            screen.id == id && (!onlyEnabled || !screen.disabled),
        orElse: () => null);
  }

  void handlePopState(PopStateEvent event) {
    loadScreenFromLocation();
  }

  CoreElement get mainElement => CoreElement.from(queryId('content'));

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
        CoreElement.from(queryId('messages-container'));
    errorContainer.add(flash);
  }

  void clearMessages() {
    queryId('messages-container').children.clear();
  }

  void toast(String message, {String title}) {
    final Toast toast = Toast(title: title, message: message);
    final CoreElement toastContainer =
        CoreElement.from(queryId('toast-container'));
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
    this.disabled = false,
  });

  final String name;
  final String id;
  final String iconClass;
  final bool disabled;

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

class ConnectDialog {
  ConnectDialog(this.framework) {
    parent = CoreElement.from(queryId('connect-dialog'));
    parent.layoutVertical();

    parent.add([
      h2(text: 'Connect'),
      CoreElement('dl', classes: 'form-group')
        ..add([
          CoreElement('dt')
            ..add([
              label(text: 'Connect to a running app')
                ..setAttribute('for', 'port-field'),
            ]),
          CoreElement('dd')
            ..add([
              p(
                  text: 'Enter a port or URL to a running Dart or Flutter '
                      'application.',
                  c: 'note'),
            ]),
          CoreElement('dd')
            ..add([
              textfield = CoreElement('input', classes: 'form-control input-sm')
                ..setAttribute('type', 'text')
                ..setAttribute('placeholder', 'Port')
                ..id = 'port-field',
              connectButton = PButton('Connect')
                ..small()
                ..clazz('margin-left'),
            ]),
        ]),
    ]);

    connectButton.click(() {
      _tryConnect();
    });

    textfield.element.onKeyDown.listen((KeyboardEvent event) {
      // Check for an enter key press ('\n').
      if (event.keyCode == 13) {
        event.preventDefault();

        _tryConnect();
      }
    });
  }

  final Framework framework;

  CoreElement parent;
  CoreElement textfield;
  CoreElement connectButton;

  void show() {
    parent.display = 'initial';
  }

  void hide() {
    parent.display = 'none';
  }

  bool isVisible() => parent.display != 'none';

  @visibleForTesting
  void connectTo(int port) async {
    await _connect(port);
  }

  void _tryConnect() {
    final InputElement inputElement = textfield.element;
    final String value = inputElement.value.trim();
    final int port = int.tryParse(value);

    void handleConnectError() {
      // TODO(devoncarew): We should provide the user some instructions about
      // how to resolve an issue connecting.
      framework.toast("Unable to connect to '$value'.");
    }

    if (port != null) {
      _connect(port).catchError((dynamic error) {
        handleConnectError();
      });
    } else {
      try {
        final Uri uri = Uri.parse(value);
        if (uri.hasPort) {
          _connect(uri.port).catchError((dynamic error) {
            handleConnectError();
          });
        } else {
          handleConnectError();
        }
      } catch (_) {
        // ignore
        handleConnectError();
      }
    }
  }

  Future _connect(int port) async {
    final bool connected = await FrameworkCore.initVmService(
      explicitPort: port,
      errorReporter: (String title, dynamic error) {
        // ignore - we report this in _tryConnect
      },
    );

    if (connected) {
      // Re-write the url to include the new port
      final Location location = window.location;
      Uri uri = Uri.parse(location.href);
      uri = uri.replace(queryParameters: {'port': port.toString()});
      window.history.pushState(null, null, uri.toString());

      // Hide the dialog
      hide();
    } else {
      throw 'not connected';
    }
  }
}
