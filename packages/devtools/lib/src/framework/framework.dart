// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' hide Screen;

import 'package:meta/meta.dart';

import '../globals.dart';
import '../main.dart';
import '../timeline/timeline.dart';
import '../timeline/timeline_controller.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/primer.dart';
import '../ui/ui_utils.dart';
import '../utils.dart';
import 'framework_core.dart';

class Framework {
  Framework() {
    window.onPopState.listen(handlePopState);

    _initDragDrop();

    globalStatus = StatusLine(CoreElement.from(queryId('global-status')));
    pageStatus = StatusLine(CoreElement.from(queryId('page-status')));
    auxiliaryStatus = StatusLine(CoreElement.from(queryId('auxiliary-status')));

    globalActions =
        ActionsContainer(CoreElement.from(queryId('global-actions')));

    // TODO(kenzie): refactor [connectDialog] and [snapshotMessage] to be in their
    // own screen.
    connectDialog = new ConnectDialog(this);

    snapshotMessage = new SnapshotMessage(this);

    analyticsDialog = AnalyticsOptInDialog(this);
  }

  final List<Screen> screens = <Screen>[];

  final Map<Screen, CoreElement> _screenContents = {};

  final Completer<void> screensReady = Completer();

  Screen current;

  Screen _previous;

  StatusLine globalStatus;
  StatusLine pageStatus;
  StatusLine auxiliaryStatus;
  ActionsContainer globalActions;
  ConnectDialog connectDialog;
  SnapshotMessage snapshotMessage;
  AnalyticsOptInDialog analyticsDialog;

  void _initDragDrop() {
    window.addEventListener('dragover', (e) => _onDragOver(e), false);
    window.addEventListener('drop', (e) => _onDrop(e), false);
  }

  void _onDragOver(MouseEvent event) {
    // This is necessary to allow us to drop.
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }

  void _onDrop(MouseEvent event) async {
    // Stop the browser from redirecting.
    event.preventDefault();

    final List<File> files = event.dataTransfer.files;
    if (files.length > 1) {
      toast('You cannot import more than one file.');
      return;
    }

    final droppedFile = files.first;
    if (droppedFile.type != 'application/json') {
      toast('${droppedFile.type} is not a supported file type. Please import '
          'a .json file that was exported from Dart DevTools.');
      return;
    }

    final FileReader reader = FileReader();
    reader.onLoad.listen((_) {
      try {
        final Map<String, dynamic> import = jsonDecode(reader.result);
        final devToolsScreen = import['dartDevToolsScreen'];

        if (devToolsScreen == null) {
          toast(
            'The imported file is not a Dart DevTools file. At this time, '
            'DevTools only supports importing files that were originally '
            'exported from DevTools.',
            hideDelay: Toast.extendedHideDelay,
          );
          return;
        }

        // TODO(jacobr): add the inspector handling case here once the inspector
        // can be exported.
        switch (devToolsScreen) {
          case timelineScreenId:
            _importTimeline(import);
            break;
          default:
            toast(
              'Could not import file. The imported file is from '
              '"$devToolsScreen", which is not supported by this version of '
              'Dart DevTools. You may need to upgrade your version of Dart '
              'DevTools to view this file.',
              hideDelay: Toast.extendedHideDelay,
            );
        }
      } on FormatException catch (e) {
        toast(
          'JSON syntax error in imported file: "$e". Please make sure the '
          'imported file is a Dart DevTools file, and check that it has not '
          'been modified.',
          hideDelay: Toast.extendedHideDelay,
        );
        return;
      }
    });

    try {
      reader.readAsText(droppedFile);
    } catch (e) {
      toast('Could not import file: $e');
    }
  }

  void _importTimeline(Map<String, dynamic> import) {
    final snapshot = TimelineSnapshot.parse(import);
    if (snapshot.isEmpty) {
      toast('Imported file does not contain timeline data.');
      exitSnapshotMode();
      return;
    }

    TimelineScreen timelineScreen = screens.firstWhere(
      (screen) => screen.id == timelineScreenId,
      orElse: () => null,
    );
    if (timelineScreen == null) {
      addScreen(timelineScreen = TimelineScreen(disabled: false));
    }
    _enterSnapshotMode();
    navigateTo(timelineScreenId);
    loadTimelineSnapshotController.add(snapshot);
  }

  void _enterSnapshotMode() {
    connectDialog.hide();
    snapshotMessage.hide();
    snapshotMode = true;
  }

  void exitSnapshotMode() {
    snapshotMode = false;
    if (serviceManager.connectedApp == null) {
      showConnectionDialog();
      showSnapshotMessage();
      mainElement.clear();
      screens.removeWhere((screen) => screen.id == timelineScreenId);
    } else {
      navigateTo(_previous.id);
    }
  }

  void addScreen(Screen screen) {
    screens.add(screen);
  }

  void navigateTo(String id) {
    ga.screen(id);
    final Screen screen = getScreen(id);
    assert(screen != null);

    final String search = window.location.search;
    final String ref = search == null ? screen.ref : '$search${screen.ref}';
    window.history.pushState(null, screen.name, ref);

    load(screen);
  }

  void showAnalyticsDialog() {
    analyticsDialog.show();
  }

  void showConnectionDialog() {
    connectDialog.show();
  }

  void showSnapshotMessage() {
    snapshotMessage.show();
  }

  void loadScreenFromLocation() async {
    await screensReady.future.whenComplete(() {
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
        ga_platform.setupAndGaScreen(id);
        load(screen);
      } else {
        load(NotFoundScreen());
      }
    });
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
      _previous = current;
      current = null;
      _previous.exiting();
      _previous.visible = false;

      pageStatus.removeAll();

      _screenContents[_previous].hidden(true);
    }

    current = screen;

    if (_screenContents.containsKey(current)) {
      _screenContents[current].hidden(false);
      if (screen.needsResizing) {
        // Fire a resize used to ensure a plotly chart (transitioning from one
        // screen to another uses display:none).
        _screenContents[current].element.dispatchEvent(new Event('resize'));
        screen.needsResizing = false;
      }
    } else {
      current.framework = this;

      final CoreElement screenContent = current.createContent(this);
      screenContent.attribute('full');
      mainElement.add(screenContent);

      _screenContents[current] = screenContent;

      screenContent.element.onResize.listen((e) {
        // Need to stop event listeners, within the screen from getting the
        // resize event. This doesn't stop event listeners higher up in the tree
        // from receiving the resize event.  Plotly can chart get's resized even
        // though its in a div with a 'display:none' and will resize improperly.
        e.stopImmediatePropagation(); // Don't bubble up the resize event.

        _screenContents.forEach((Screen theScreen, CoreElement content) {
          if (current != theScreen) {
            theScreen.needsResizing = true;
          }
        });
      });
    }

    current.visible = true;
    current.entering();
    pageStatus.addAll(current.statusItems);
    auxiliaryStatus.defaultStatus = screen.helpStatus;

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

  void showInfo({String message, String title, List<CoreElement> children}) {
    _showMessage(message: message, title: title, children: children);
  }

  void showWarning({String message, String title, List<CoreElement> children}) {
    _showMessage(
        message: message, title: title, children: children, warning: true);
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

    _showMessage(message: message, title: title, error: true);
  }

  void _showMessage({
    String message,
    String title,
    bool warning = false,
    bool error = false,
    List<CoreElement> children,
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
    if (children != null) {
      children.forEach(flash.add);
    }

    final CoreElement errorContainer =
        CoreElement.from(queryId('messages-container'));
    errorContainer.add(flash);
  }

  void clearMessages() {
    queryId('messages-container').children.clear();
  }

  void toast(
    String message, {
    String title,
    Duration hideDelay = Toast.defaultHideDelay,
  }) {
    final Toast toast = Toast(title: title, message: message);
    final CoreElement toastContainer =
        CoreElement.from(queryId('toast-container'));
    toastContainer.add(toast);
    toast.show(hideDelay: hideDelay);
  }

  void addGlobalAction(ActionButton action) {
    globalActions.addAction(action);
  }

  void removeGlobalAction(String id) {
    globalActions.removeAction(id);
  }
}

class StatusLine {
  StatusLine(this.element);

  final CoreElement element;
  final List<StatusItem> _items = <StatusItem>[];

  /// Status to show if no actual status is provided..
  final List<StatusItem> _defaultStatusItems = <StatusItem>[];

  void add(StatusItem item) {
    _items.add(item);

    _rebuild();
  }

  set defaultStatus(StatusItem defaultStatus) {
    _defaultStatusItems.clear();
    if (defaultStatus != null) {
      _defaultStatusItems.add(defaultStatus);
    }
    _rebuild();
  }

  void _rebuild() {
    element.clear();
    final List<StatusItem> items =
        _items.isEmpty ? _defaultStatusItems : _items;

    bool first = true;
    for (StatusItem item in items) {
      if (!first) {
        element.add(SpanElement()
          ..text = '•'
          ..classes.add('separator'));
      }
      element.add(item.element);
      first = false;
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
    for (ActionButton _action in _actions) {
      if (_action.id == action.id) {
        // This action is a duplicate. Do not add it.
        return;
      }
    }

    if (_actions.isEmpty) {
      // add a visual separator
      element.add(span(
          text: '•', a: 'horiz-padding', c: 'masthead-item action-separator'));
    }

    _actions.add(action);
    element.add(action.element);
  }

  void removeAction(String id) {
    _actions.removeWhere((ActionButton button) => button.id == id);
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
    this.disabledTooltip = 'This screen is not available',
    bool disabled = false,
  })  : helpStatus = createLinkStatusItem(
          span()
            ..add(span(text: '$name', c: 'optional-700'))
            ..add(span(text: ' Docs')),
          href: 'https://flutter.github.io/devtools/$id',
          title: 'Documentation on using the $name page',
        ),
        disabled = allTabsEnabledByQuery ? false : disabled;

  final String name;
  final String id;
  final String iconClass;
  final StatusItem helpStatus;
  final String disabledTooltip;
  final bool disabled;

  bool needsResizing = false;

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

  void removeStatusItem(StatusItem item) {
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
  static const Duration defaultHideDelay = Duration(seconds: 4);
  static const Duration extendedHideDelay = Duration(seconds: 10);

  final String title;
  @required
  final String message;

  void show({Duration hideDelay = defaultHideDelay}) async {
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
                ..setAttribute('for', 'uri-field'),
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
                ..setAttribute('placeholder', 'Port or URL')
                ..id = 'uri-field',
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

  void connectTo(Uri uri) async {
    await _connect(uri);
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

    // Clear existing messages as the existing messages are about the previous
    // VMService or the previous failure to connect to the VM Service.
    framework.clearMessages();
    if (port != null) {
      _connect(Uri.parse('ws://localhost:$port/ws'))
          .catchError((dynamic error) {
        handleConnectError();
      });
    } else {
      try {
        final uri = getTrimmedUri(value);
        if (uri != null && uri.isAbsolute) {
          _connect(uri).catchError((dynamic error) {
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

  Future _connect(Uri serviceUri) async {
    final bool connected = await FrameworkCore.initVmService(
      explicitUri: serviceUri,
      errorReporter: (String title, dynamic error) {
        // ignore - we report this in _tryConnect
      },
    );

    if (connected) {
      // Re-write the url to include the new service uri. Keep existing query params.
      final Location location = window.location;
      final uri = Uri.parse(location.href);
      final newParams = Map.of(uri.queryParameters);
      newParams['uri'] = serviceUri.toString();
      window.history.pushState(
          null, null, uri.replace(queryParameters: newParams).toString());

      // Hide the dialog
      hide();

      // Hide the snapshot message.
      framework.snapshotMessage.hide();
    } else {
      throw 'not connected';
    }
  }
}

class SnapshotMessage {
  SnapshotMessage(this.framework) {
    parent = CoreElement.from(queryId('snapshot-message'));
    parent.layoutVertical();

    parent.add([
      h2(text: 'Load DevTools Snapshot'),
      CoreElement('dl', classes: 'form-group')
        ..add([
          CoreElement('dt')
            ..add([label(text: 'Load a DevTools snapshot from a local file.')]),
          CoreElement('dd')
            ..add([
              p(text: 'Drag and drop a file anywhere on the page.', c: 'note'),
            ]),
          CoreElement('dd')
            ..add([
              p(
                  // TODO(kenzie): support other generic chrome:trace files and
                  // note their support here.
                  text: 'Supported file formats include any files exported from'
                      ' DevTools, such as the timeline export.',
                  c: 'note'),
            ]),
        ])
    ]);

    hide();
  }

  final Framework framework;

  CoreElement parent;

  void show() {
    parent.display = 'initial';
  }

  void hide() {
    parent.display = 'none';
  }

  bool isVisible() => parent.display != 'none';
}

class AnalyticsOptInDialog {
  AnalyticsOptInDialog(this.framework) {
    parent = CoreElement.from(queryId('ga-dialog'));
    parent.layoutVertical();

    parent.add([
      h2(text: 'Analytics Data Collection'),
      CoreElement('dl', classes: 'form-group')
        ..add([
          CoreElement('dt')
            ..add([
              label(text: 'Welcome to Dart DevTools')
                ..setAttribute('for', 'uri-field'),
            ]),
          CoreElement('dd')
            ..add([
              p(
                text: 'Dart DevTools reports features usage '
                    'statistics and basic crash reports to Google in order '
                    'to help Google contribute improvements to Dart DevTools '
                    'over time.',
              )..add([
                  br(),
                  a(
                      text: 'See Google\'s privacy policy',
                      c: 'note',
                      href: 'https://www.google.com/intl/en/policies/privacy',
                      target: '_blank'),
                ]),
            ]),
          CoreElement('dd')
            ..add([
              p(text: 'Do you accept analytics collection for Dart DevTools?'),
              acceptButton = PButton('I Accept')
                ..small()
                ..clazz('margin-left')
                ..setAttribute('tabindex', '1'),
              dontAcceptButton = PButton('I Do Not Accept')
                ..small()
                ..clazz('margin-left')
                ..setAttribute('tabindex', '2'),
            ]),
        ]),
    ]);

    acceptButton.click(() {
      ga_platform.setAllowAnalytics();
      hide();
      ga.initializeGA();
    });

    dontAcceptButton.click(() {
      ga_platform.setDontAllowAnalytics();
      hide();
    });

    hide();
  }

  final Framework framework;

  CoreElement parent;
  CoreElement acceptButton;
  CoreElement dontAcceptButton;

  void show() {
    parent.display = 'initial';
    acceptButton.element.focus();
  }

  void hide() {
    parent.display = 'none';
  }

  bool isVisible() => parent.display != 'none';
}
