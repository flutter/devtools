// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Point;

/// Finds the first descendant element of this document with the given id.
Element queryId(String id) => querySelector('#$id');

CoreElement a({String text, String c, String a, String href, String target}) =>
    CoreElement('a', text: text, classes: c, attributes: a)
      ..setAttribute('href', href)
      ..setAttribute('target', target);

CoreElement br() => CoreElement('br');

CoreElement button({String text, String c, String a}) =>
    CoreElement('button', text: text, classes: c, attributes: a);

CoreElement checkbox({String text, String c, String a}) =>
    CoreElement('input', text: text, classes: c, attributes: a)
      ..setAttribute('type', 'checkbox');

CoreElement label({String text, String c, String a}) =>
    CoreElement('label', text: text, classes: c, attributes: a);

CoreElement div({String text, String c, String a}) =>
    CoreElement('div', text: text, classes: c, attributes: a);

CoreElement span({String text, String c, String a}) =>
    CoreElement('span', text: text, classes: c, attributes: a);

CoreElement h2({String text, String c, String a}) =>
    CoreElement('h2', text: text, classes: c, attributes: a);

CoreElement p({String text, String c, String a}) =>
    CoreElement('p', text: text, classes: c, attributes: a);

CoreElement italic({String text, String c, String a}) =>
    CoreElement('i', text: text, classes: c, attributes: a);

CoreElement em({String text, String c, String a}) =>
    CoreElement('em', text: text, classes: c, attributes: a);

CoreElement img({String text, String c, String a, String src}) {
  final CoreElement img =
      CoreElement('img', text: text, classes: c, attributes: a);
  // ignore: avoid_as
  (img.element as ImageElement).src = src;
  return img;
}

CoreElement ol({String text, String c, String a}) =>
    CoreElement('ol', text: text, classes: c, attributes: a);

CoreElement ul({String text, String c, String a}) =>
    CoreElement('ul', text: text, classes: c, attributes: a);

CoreElement li({String text, String html, String c, String a}) =>
    CoreElement('li', text: text, html: html, classes: c, attributes: a);

CoreElement para({String text, String c, String a}) =>
    CoreElement('p', text: text, classes: c, attributes: a);

CoreElement table() => CoreElement('table');

CoreElement tr() => CoreElement('tr');

CoreElement th({String text, String c}) =>
    CoreElement('th', text: text, classes: c);

CoreElement td({String text, String c}) =>
    CoreElement('td', text: text, classes: c);

CoreElement form() => CoreElement('form');

class CoreElement {
  CoreElement(String tag,
      {String text, String html, String classes, String attributes})
      : element = Element.tag(tag) {
    if (text != null) {
      element.text = text;
    }
    if (html != null) {
      element.innerHtml = html;
    }
    if (classes != null) {
      element.classes.addAll(classes.split(' '));
    }
    if (attributes != null) {
      attributes.split(' ').forEach(attribute);
    }
  }

  CoreElement.from(this.element);

  final Element element;

  String get tag => element.tagName;

  String get id => attributes['id'];

  set id(String value) => setAttribute('id', value);

  String get src => attributes['src'];

  set src(String value) => setAttribute('src', value);

  bool hasAttribute(String name) => element.attributes.containsKey(name);

  void attribute(String name, [bool value]) {
    value ??= !element.attributes.containsKey(name);

    if (value) {
      element.setAttribute(name, '');
    } else {
      element.attributes.remove(name);
    }
  }

  void toggleAttribute(String name, [bool value]) => attribute(name, value);

  Map<String, String> get attributes => element.attributes;

  void setAttribute(String name, [String value = '']) =>
      element.setAttribute(name, value);

  String clearAttribute(String name) => element.attributes.remove(name);

  void icon(String iconName) =>
      element.classes.addAll(<String>['icon', 'icon-$iconName']);

  bool hasClass(String name) => element.classes.contains(name);

  void clazz(String _class, {bool removeOthers = false}) {
    if (_class.contains(' ')) {
      throw ArgumentError('spaces not allowed in class names');
    }
    if (removeOthers) {
      element.classes.clear();
    }
    element.classes.add(_class);
  }

  void toggleClass(String name, [bool value]) {
    element.classes.toggle(name, value);
  }

  String get text => element.text;

  set text(String value) {
    element.text = value;
  }

  /// Add the given child to this element's list of children. [child] must be
  /// either a `CoreElement` or an `Element`.
  dynamic add(dynamic child) {
    if (child is Iterable) {
      return child.map<dynamic>((dynamic c) => add(c)).toList();
    } else if (child is CoreElement) {
      element.children.add(child.element);
    } else if (child is CoreElementView) {
      element.children.add(child.element.element);
    } else if (child is Element) {
      element.children.add(child);
    } else {
      throw ArgumentError('argument type ${child.runtimeType} not supported');
    }
    return child;
  }

  /// Replace the given child/children to this element's list of children by the
  /// childIndex. [child] must be either a `CoreElement` or an `Element`.
  void replace(int childIndex, dynamic child) {
    if (child is Iterable) {
      // TODO(terry): Check begin index and end to ensure valid replace range.
      int nextIndex = childIndex;
      child.map<dynamic>((dynamic c) {
        replace(nextIndex++, c);
      });
    } else if (child is CoreElement) {
      element.children[childIndex] = child.element;
    } else if (child is CoreElementView) {
      element.children[childIndex] = child.element.element;
    } else if (child is Element) {
      element.children[childIndex] = child;
    } else {
      throw ArgumentError('argument type ${child.runtimeType} not supported');
    }
  }

  bool get isHidden => hasAttribute('hidden');

  void hidden([bool value]) => attribute('hidden', value);

  String get label => attributes['label'];

  set label(String value) => setAttribute('label', value);

  bool get disabled => hasAttribute('disabled');

  set disabled(bool value) => attribute('disabled', value);

  bool get enabled => !disabled;

  set enabled(bool value) => attribute('disabled', !value);

  // Layout types.
  void layout() => attribute('layout');

  void horizontal() => attribute('horizontal');

  void vertical() => attribute('vertical');

  void layoutHorizontal() {
    setAttribute('layout');
    setAttribute('horizontal');
  }

  void layoutVertical() {
    setAttribute('layout');
    setAttribute('vertical');
  }

  // Layout params.
  void fit() => attribute('fit');

  void flex([int flexAmount]) {
    attribute('flex', true);

    if (flexAmount != null) {
      if (flexAmount == 1) {
        attribute('one', true);
      } else if (flexAmount == 2) {
        attribute('two', true);
      } else if (flexAmount == 3) {
        attribute('three', true);
      } else if (flexAmount == 4) {
        attribute('four', true);
      } else if (flexAmount == 5) {
        attribute('five', true);
      }
    }
  }

  String get tooltip => element.title;

  set tooltip(String value) {
    element.title = value;
  }

  String get display => element.style.display;

  set display(String value) {
    element.style.display = value;
  }

  int get scrollHeight => element.scrollHeight;

  int get scrollTop => element.scrollTop;

  set scrollTop(int value) => element.scrollTop = value;

  int get offsetHeight => element.offsetHeight;

  String get height => element.style.height;

  set height(String value) {
    element.style.height = value;
  }

  Stream<MouseEvent> get onClick => element.onClick.where((_) => !disabled);

  Stream<Event> get onFocus => element.onFocus.where((_) => !disabled);

  Stream<Event> get onBlur => element.onBlur.where((_) => !disabled);

  Stream<Event> get onScroll => element.onScroll;

  Stream<KeyboardEvent> get onKeyDown => element.onKeyDown;

  Stream<KeyboardEvent> get onKeyUp => element.onKeyUp;

  Stream<ClipboardEvent> get onCut => element.onCut;

  Stream<ClipboardEvent> get onPaste => element.onPaste;

  /// Subscribe to the [onClick] event stream with a no-arg handler.
  StreamSubscription<Event> click(void handle(), [void shiftHandle()]) {
    return onClick.listen((MouseEvent e) {
      e.stopImmediatePropagation();
      if (shiftHandle != null && e.shiftKey) {
        shiftHandle();
      } else {
        handle();
      }
    });
  }

  /// Subscribe to the [onDoubleClick] event stream with a no-arg handler.
  StreamSubscription<Event> dblclick(void handle()) {
    return element.onDoubleClick.listen((Event event) {
      event.stopImmediatePropagation();
      handle();
    });
  }

  /// Subscribe to the [focus] event stream with a no-arg handler.
  StreamSubscription<Event> focus(void handle()) {
    return onFocus.listen((Event e) {
      e.stopImmediatePropagation();
      handle();
    });
  }

  /// Subscribe to the [blur] event stream with a no-arg handler.
  StreamSubscription<Event> blur(void handle()) {
    return onBlur.listen((Event e) {
      e.stopImmediatePropagation();
      handle();
    });
  }

  void clear() => element.children.clear();

  void scrollIntoView({bool bottom = false, bool top = false}) {
    if (bottom) {
      element.scrollIntoView(ScrollAlignment.BOTTOM);
    } else if (top) {
      element.scrollIntoView(ScrollAlignment.TOP);
    } else {
      element.scrollIntoView();
    }
  }

  void setInnerHtml(String str) {
    element.setInnerHtml(str, treeSanitizer: const TrustedHtmlTreeSanitizer());
  }

  // /// Listen for a user copy event (ctrl-c / cmd-c) and copy the selected DOM
  // /// bits into the user's paste buffer.
  // void listenForUserCopy() {
  //   element.onKeyDown.listen(_handleCopyKeyPress);
  // }

  // void _handleCopyKeyPress(KeyboardEvent event) {
  //   // ctrl-c or cmd-c
  //   if (event.keyCode != 67) return;

  //   if ((isMac && event.metaKey) || (!isMac && event.ctrlKey)) {
  //     event.preventDefault();
  //     document.execCommand('copy', false, null);
  //   }
  // }

  void dispose() {
    if (element.parent == null) {
      return;
    }

    if (element.parent.children.contains(element)) {
      try {
        element.parent.children.remove(element);
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  String toString() => element.toString();
}

class CloseButton extends CoreElement {
  CloseButton() : super('div', classes: 'close-button');
}

class TrustedHtmlTreeSanitizer implements NodeTreeSanitizer {
  const TrustedHtmlTreeSanitizer();

  @override
  void sanitizeTree(Node node) {}
}

/// Base class for lightweight views that render to a CoreElement but are not
/// a CoreElement themselves.
abstract class CoreElementView {
  CoreElement get element;
}
