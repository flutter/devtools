// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'package:html_shim/html.dart' hide Screen;

import 'package:meta/meta.dart';

import '../globals.dart';
import '../html_message_manager.dart';
import '../main.dart';
import '../timeline/html_timeline_screen.dart';
import '../timeline/timeline_controller.dart';
import '../timeline/timeline_model.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/html_custom.dart';
import '../ui/html_elements.dart';
import '../ui/primer.dart';
import '../ui/ui_utils.dart';
import '../url_utils.dart';
import '../utils.dart';
import 'framework_core.dart';

class HtmlFramework {
  HtmlFramework() {
    window.onPopState.listen(handlePopState);

    _initDragDrop();

    globalStatus = HtmlStatusLine(CoreElement.from(queryId('global-status')));
    pageStatus = HtmlStatusLine(CoreElement.from(queryId('page-status')));
    auxiliaryStatus =
        HtmlStatusLine(CoreElement.from(queryId('auxiliary-status')))
          ..defaultStatus = defaultAuxiliaryStatus;

    globalActions =
        HtmlActionsContainer(CoreElement.from(queryId('global-actions')));

    // TODO(kenz): refactor [connectDialog] and [snapshotMessage] to be in their
    // own screen.
    connectDialog = HtmlConnectDialog(this);

    snapshotMessage = HtmlSnapshotMessage(this);

    analyticsDialog = HtmlAnalyticsOptInDialog(this);
  }

  final List<HtmlScreen> screens = <HtmlScreen>[];

  final Map<HtmlScreen, CoreElement> _screenContents = {};

  final Completer<void> screensReady = Completer();

  final HtmlMessageManager messageManager = HtmlMessageManager();

  HtmlScreen current;

  HtmlScreen _previous;

  HtmlStatusLine globalStatus;

  HtmlStatusLine pageStatus;

  HtmlStatusLine auxiliaryStatus;

  HtmlActionsContainer globalActions;

  HtmlConnectDialog connectDialog;

  HtmlSnapshotMessage snapshotMessage;

  HtmlAnalyticsOptInDialog analyticsDialog;

  HtmlSurveyToast devToolsSurvey;

  Stream<String> get onPageChange => _pageChangeController.stream;
  final _pageChangeController = StreamController<String>.broadcast();

  final HtmlStatusItem defaultAuxiliaryStatus = createLinkStatusItem(
    span()..add(span(text: 'DevTools Docs', c: 'optional-700')),
    href: 'https://flutter.dev/docs/development/tools/devtools/overview',
    title: 'Documentation on using Dart DevTools',
  );

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
            hideDelay: HtmlToastAnimator.extendedHideDelay,
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
              hideDelay: HtmlToastAnimator.extendedHideDelay,
            );
            return;
        }
      } on FormatException catch (e) {
        toast(
          'JSON syntax error in imported file: "$e". Please make sure the '
          'imported file is a Dart DevTools file, and check that it has not '
          'been modified.',
          hideDelay: HtmlToastAnimator.extendedHideDelay,
        );
        return;
      }
      messageManager.removeAll();
    });

    try {
      reader.readAsText(droppedFile);
    } catch (e) {
      toast('Could not import file: $e');
    }
  }

  Future<void> _importTimeline(Map<String, dynamic> import) async {
    OfflineData offlineData;
    final timelineMode =
        import[TimelineData.timelineModeKey] == TimelineMode.full.toString()
            ? TimelineMode.full
            : TimelineMode.frameBased;
    if (timelineMode == TimelineMode.frameBased) {
      offlineData = OfflineFrameBasedTimelineData.parse(import);
    } else {
      offlineData = OfflineFullTimelineData.parse(import);
    }

    if (offlineData.isEmpty) {
      toast('Imported file does not contain timeline data.');
      return;
    }

    _enterOfflineMode();

    HtmlTimelineScreen timelineScreen = screens.firstWhere(
      (screen) => screen.id == timelineScreenId,
      orElse: () => null,
    );
    if (timelineScreen == null) {
      addScreen(timelineScreen = HtmlTimelineScreen(timelineMode));
    }
    navigateTo(timelineScreenId);

    await timelineScreen.prepareViewForOfflineData(timelineMode);
    timelineScreen.timelineController.loadOfflineData(offlineData);
  }

  void _enterOfflineMode() {
    connectDialog.hide();
    snapshotMessage.hide();
    offlineMode = true;
  }

  void exitOfflineMode() {
    offlineMode = false;
    if (serviceManager.connectedApp == null) {
      showConnectionDialog();
      showSnapshotMessage();
      mainElement.clear();
      screens.removeWhere((screen) => screen.id == timelineScreenId);
      auxiliaryStatus.defaultStatus = defaultAuxiliaryStatus;
    } else {
      navigateTo((_previous ?? current).id);
    }
  }

  void addScreen(HtmlScreen screen) {
    screens.add(screen);
  }

  /// Returns false if the screen is disabled.
  bool navigateTo(String id) {
    final HtmlScreen screen = getScreen(id);
    assert(screen != null);
    if (screen.disabled) {
      return false;
    }
    ga.screen(id);

    final String search = window.location.search;
    final String ref = search == null ? screen.ref : '$search${screen.ref}';
    window.history.pushState(null, screen.name, ref);

    load(screen);
    return true;
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

  // Hookup for any keyDown event to handle shortcut keys for a screen.
  void _hookupShortcuts() {
    window.onKeyDown.listen((KeyboardEvent e) {
      if (current != null &&
          e.key.isNotEmpty &&
          current.shortcutCallback != null &&
          current.shortcutCallback(e.ctrlKey, e.shiftKey, e.altKey, e.key)) {
        e.preventDefault();
      }
    });
  }

  void loadScreenFromLocation() async {
    _hookupShortcuts();

    await screensReady.future.whenComplete(() {
      // Screens are identified by the hash as that works better with the webdev
      // server.
      String id = window.location.hash;
      if (id.isNotEmpty) {
        assert(id[0] == '#');
        id = id.substring(1);
      }
      HtmlScreen screen = getScreen(id, onlyEnabled: true);
      screen ??= screens.firstWhere((screen) => !screen.disabled,
          orElse: () => screens.first);
      if (screen != null) {
        ga_platform.setupAndGaScreen(id);
        load(screen);
      } else {
        load(HtmlNotFoundScreen());
      }
    });
  }

  HtmlScreen getScreen(String id, {bool onlyEnabled = false}) {
    return screens.firstWhere(
        (HtmlScreen screen) =>
            screen.id == id && (!onlyEnabled || !screen.disabled),
        orElse: () => null);
  }

  void handlePopState(PopStateEvent event) {
    loadScreenFromLocation();
  }

  CoreElement get mainElement => CoreElement.from(queryId('content'));

  void load(HtmlScreen screen) {
    if (current == null) {
      mainElement.element.children.clear();
    }

    if (current != null) {
      _previous = current;
      current = null;
      _previous.exiting();
      _previous.visible = false;

      pageStatus.removeAll();
      messageManager.removeAll();

      _screenContents[_previous].hidden(true);
    }

    current = screen;

    if (_screenContents.containsKey(current)) {
      _screenContents[current].hidden(false);
      if (screen.needsResizing) {
        // Fire a resize used to ensure a plotly chart (transitioning from one
        // screen to another uses display:none).
        _screenContents[current].element.dispatchEvent(Event('resize'));
        screen.needsResizing = false;
      }
    } else {
      current.framework = this;

      final CoreElement screenContent = current.createContent(this);
      screenContent.attribute('full');
      mainElement.add(screenContent);
      current.onContentAttached();

      _screenContents[current] = screenContent;

      screenContent.element.onResize.listen((e) {
        // Need to stop event listeners, within the screen from getting the
        // resize event. This doesn't stop event listeners higher up in the tree
        // from receiving the resize event. Plotly can chart get's resized even
        // though its in a div with a 'display:none' and will resize improperly.
        e.stopImmediatePropagation(); // Don't bubble up the resize event.

        _screenContents.forEach((HtmlScreen theScreen, CoreElement content) {
          if (current != theScreen) {
            theScreen.needsResizing = true;
          }
        });
      });
    }

    current.visible = true;
    current.entering();
    pageStatus.addAll(current.statusItems);
    messageManager.showMessagesForScreen(current.id);
    auxiliaryStatus.defaultStatus = screen._helpStatus;

    updatePage();
    _updateSurveyUrlForCurrentScreen();
  }

  void _updateSurveyUrlForCurrentScreen() {
    if (devToolsSurvey == null) return;
    assert(current != null);

    final oldUri = Uri.parse(devToolsSurvey.url);
    final newUri = Uri(
      scheme: oldUri.scheme,
      host: oldUri.host,
      path: oldUri.path,
      queryParameters: Map.from(oldUri.queryParameters)
        ..['From'] = current?.id ?? '',
    );
    devToolsSurvey.url = newUri.toString();
  }

  void updatePage() {
    // nav
    for (Element element in querySelectorAll('#main-nav a')) {
      final CoreElement e = CoreElement.from(element);
      final bool isCurrent = current.ref == element.attributes['href'];
      e.toggleClass('active', isCurrent);
    }
    _pageChangeController.add(current.id);
  }

  void showMessage({
    @required HtmlMessage message,
    String screenId = generalId,
  }) {
    messageManager.addMessage(message, screenId);
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
    messageManager.addMessage(
      HtmlMessage(MessageType.error, message: message, title: title),
      generalId,
    );
  }

  void clearMessages() {
    messageManager.removeAll();
  }

  void surveyToast(String url) {
    devToolsSurvey = HtmlSurveyToast(url);
    final CoreElement toastContainer =
        CoreElement.from(queryId('toast-container'))
          ..clazz('survey-toast-container');
    toastContainer.add(devToolsSurvey);
    devToolsSurvey.show();
  }

  void toast(
    String message, {
    String title,
    Duration hideDelay = HtmlToastAnimator.defaultHideDelay,
  }) {
    final HtmlToast toast = HtmlToast(title: title, message: message);
    final CoreElement toastContainer =
        CoreElement.from(queryId('toast-container'));
    toastContainer.add(toast);
    toast.show(hideDelay: hideDelay);
  }

  void addGlobalAction(HtmlActionButton action) {
    globalActions.addAction(action);
  }

  void removeGlobalAction(String id) {
    globalActions.removeAction(id);
  }
}

class HtmlStatusLine {
  HtmlStatusLine(this.element);

  final CoreElement element;
  final List<HtmlStatusItem> _items = <HtmlStatusItem>[];

  /// Status to show if no actual status is provided..
  final List<HtmlStatusItem> _defaultStatusItems = <HtmlStatusItem>[];

  void add(HtmlStatusItem item) {
    _items.add(item);

    _rebuild();
  }

  set defaultStatus(HtmlStatusItem defaultStatus) {
    _defaultStatusItems.clear();
    if (defaultStatus != null) {
      _defaultStatusItems.add(defaultStatus);
    }
    _rebuild();
  }

  void _rebuild() {
    element.clear();
    final List<HtmlStatusItem> items =
        _items.isEmpty ? _defaultStatusItems : _items;

    bool first = true;
    for (HtmlStatusItem item in items) {
      if (!first) {
        element.add(SpanElement()
          ..text = '•'
          ..classes.add('separator'));
      }
      element.add(item.element);
      first = false;
    }
  }

  void remove(HtmlStatusItem item) {
    _items.remove(item);

    _rebuild();
  }

  void addAll(List<HtmlStatusItem> items) {
    _items.addAll(items);

    _rebuild();
  }

  void removeAll() {
    _items.clear();
    _rebuild();
  }
}

class HtmlActionsContainer {
  HtmlActionsContainer(this.element);

  final CoreElement element;
  final List<HtmlActionButton> _actions = [];

  void addAction(HtmlActionButton action) {
    for (HtmlActionButton _action in _actions) {
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
    _actions.removeWhere((HtmlActionButton button) => button.id == id);
  }

  void clearActions() {
    _actions.clear();
    element.clear();
  }
}

// Each screen will get a chance to handle a shortcut key.
typedef ShortCut = bool Function(
    bool ctrlKey, bool shiftKey, bool altKey, String key);

abstract class HtmlScreen {
  HtmlScreen({
    @required this.name,
    @required this.id,
    this.iconClass,
    this.disabledTooltip = 'This screen is not available',
    bool enabled = true,
    this.shortcutCallback,
    this.showTab = true,
  }) : disabled = allTabsEnabledByQuery ? false : !(enabled ?? true) {
    if (name.isNotEmpty) {
      _helpStatus = createLinkStatusItem(
        span()
          ..add(span(text: '$name', c: 'optional-700'))
          ..add(span(text: ' Docs')),
        href: 'https://flutter.dev/docs/development/tools/devtools/$id',
        title: 'Documentation on using the $name page',
      );
    }
  }

  final String name;
  final String id;
  final String iconClass;
  final String disabledTooltip;
  final bool disabled;
  final bool showTab;

  HtmlStatusItem _helpStatus;

  // Set to handle short-cut keys for a particular screen.
  ShortCut shortcutCallback;

  bool needsResizing = false;

  HtmlFramework framework;

  final Property<bool> _visible = Property<bool>(false);

  final List<HtmlStatusItem> statusItems = <HtmlStatusItem>[];

  String get ref => id.isEmpty ? id : '#$id';

  bool get visible => _visible.value;

  set visible(bool value) {
    _visible.value = value;
  }

  Stream<bool> get onVisibleChange => _visible.onValueChange;

  CoreElement createContent(HtmlFramework framework);

  void entering() {}

  bool get isCurrentScreen => framework != null && framework.current == this;

  void exiting() {}

  void addStatusItem(HtmlStatusItem item) {
    statusItems.add(item);
  }

  void removeStatusItem(HtmlStatusItem item) {
    statusItems.remove(item);
  }

  @override
  String toString() => 'Screen($id)';

  /// Callback invoked after the content for the screen has been added to the
  /// DOM.
  ///
  /// Certain libraries such as package:split behave badly if invoked on
  /// elements that are not yet attached to the DOM.
  void onContentAttached() {}
}

class HtmlSetStateMixin {
  void setState(Function rebuild) {
    window.requestAnimationFrame((_) => rebuild());
  }
}

class HtmlStatusItem {
  HtmlStatusItem() : element = span();

  final CoreElement element;
}

class HtmlToast extends CoreElement {
  HtmlToast({this.title, @required this.message})
      : super('div', classes: 'toast') {
    if (title != null) {
      add(label(text: title));
    }
    add(div(text: message));

    toastAnimator = HtmlToastAnimator(this);
  }

  final String title;

  final String message;

  HtmlToastAnimator toastAnimator;

  void show({Duration hideDelay = HtmlToastAnimator.defaultHideDelay}) async {
    toastAnimator.show(hideDelay: hideDelay);
  }

  @override
  String toString() => '$title $message';
}

class HtmlSurveyToast extends CoreElement {
  HtmlSurveyToast(this._url) : super('div', classes: 'toast') {
    toastAnimator = HtmlToastAnimator(this);

    layoutVertical();
    add([
      div()
        ..layoutHorizontal()
        ..add([
          label(text: 'Help improve DevTools! ', c: 'toast-title'),
          surveyLink =
              a(text: 'Take our quarterly survey', href: _url, target: '_blank')
                ..click(_hideAndSetActionTaken),
          label(text: '.'),
          div()..flex(),
          span(c: 'octicon octicon-x flash-close js-flash-close')
            ..click(_hideAndSetActionTaken),
        ]),
      div(
          text:
              'By clicking on this link, you agree to share feature usage along'
              ' with the survey responses.'),
    ]);
  }

  String get url => _url;
  String _url;
  set url(String url) {
    _url = url;
    surveyLink.setAttribute('href', url);
  }

  CoreElement surveyLink;

  HtmlToastAnimator toastAnimator;

  void show() async {
    toastAnimator.show(hideDelay: HtmlToastAnimator.infiniteHideDelay);
  }

  void _hideAndSetActionTaken() {
    toastAnimator.hide();
    ga.setSurveyActionTaken();
  }
}

class HtmlToastAnimator {
  HtmlToastAnimator(this.element);

  static const Duration _animationDelay = Duration(milliseconds: 500);

  static const Duration defaultHideDelay = Duration(seconds: 4);

  static const Duration extendedHideDelay = Duration(seconds: 10);

  static const Duration infiniteHideDelay = null;

  final CoreElement element;

  void show({Duration hideDelay = defaultHideDelay}) async {
    await window.animationFrame;

    element.element.style.left = '0px';

    // Skip creating the timer if the selected delay is [infiniteHideDelay].
    if (hideDelay == infiniteHideDelay) return;

    Timer(_animationDelay, () {
      Timer(hideDelay, hide);
    });
  }

  void hide() {
    element.element.style.left = '400px';
    Timer(_animationDelay, element.dispose);
  }
}

class HtmlConnectDialog {
  HtmlConnectDialog(this.framework) {
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

  final HtmlFramework framework;

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
    final value = inputElement.value.trim();
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
        final uri = normalizeVmServiceUri(value);
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
      window.location.toString(),
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

class HtmlSnapshotMessage {
  HtmlSnapshotMessage(this.framework) {
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
                  // TODO(kenz): support other generic chrome:trace files and
                  // note their support here.
                  text: 'Supported file formats include any files exported from'
                      ' DevTools, such as the timeline export.',
                  c: 'note'),
            ]),
        ])
    ]);

    hide();
  }

  final HtmlFramework framework;

  CoreElement parent;

  void show() {
    parent.display = 'initial';
  }

  void hide() {
    parent.display = 'none';
  }

  bool isVisible() => parent.display != 'none';
}

class HtmlAnalyticsOptInDialog {
  HtmlAnalyticsOptInDialog(this.framework) {
    parent = CoreElement.from(queryId('ga-dialog'));
    parent.layoutVertical();

    parent.add([
      h2(text: 'Welcome to Dart DevTools'),
      CoreElement('dl', classes: 'form-group')
        ..add([
          CoreElement('dd')
            ..add([
              span(
                text: 'DevTools reports feature usage statistics and basic '
                    'crash reports to Google in order to help Google improve '
                    "the tool over time. See Google's ",
              ),
              a(
                  text: 'privacy policy',
                  href: 'https://www.google.com/intl/en/policies/privacy',
                  target: '_blank'),
              span(text: '.'),
              p(),
            ]),
          CoreElement('dd')
            ..add([
              p(text: 'Send usage statistics for DevTools?'),
              acceptButton = PButton('Sounds good!')
                ..small()
                ..setAttribute('tabindex', '1'),
              dontAcceptButton = PButton('No thanks')
                ..small()
                ..clazz('margin-left')
                ..setAttribute('tabindex', '2'),
            ]),
        ]),
    ]);

    acceptButton.click(() {
      ga_platform.setAllowAnalytics();

      // Analytic collection is enabled - setup for analytics.
      ga_platform.initializeGA();
      ga_platform.jsHookupListenerForGA();

      hide();
    });

    dontAcceptButton.click(() {
      ga_platform.setDontAllowAnalytics();
      hide();
    });

    hide();
  }

  final HtmlFramework framework;

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
