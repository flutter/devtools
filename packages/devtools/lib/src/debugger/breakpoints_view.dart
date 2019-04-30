// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:vm_service_lib/vm_service_lib.dart';

import '../debugger/debugger.dart';
import '../debugger/debugger_state.dart';
import '../ui/analytics.dart' as ga;
import '../ui/custom.dart';
import '../ui/elements.dart';

typedef URIDescriber = String Function(String uri);

int _breakpointComparator(Breakpoint a, Breakpoint b) {
  ScriptRef getRef(dynamic location) {
    if (location is SourceLocation) {
      return location.script;
    } else if (location is UnresolvedSourceLocation) {
      return location.script;
    } else {
      return null;
    }
  }

  int getPos(dynamic location) {
    if (location is SourceLocation) {
      return location.tokenPos ?? 0;
    } else if (location is UnresolvedSourceLocation) {
      return location.line ?? 0;
    } else {
      return 0;
    }
  }

  // sort by script
  final ScriptRef aRef = getRef(a.location);
  final ScriptRef bRef = getRef(b.location);
  final int compare = aRef.uri.compareTo(bRef.uri);
  if (compare != 0) {
    return compare;
  }

  // then sort by location
  return getPos(a.location) - getPos(b.location);
}

class BreakpointsView implements CoreElementView {
  BreakpointsView(this._breakpointsCountDiv, DebuggerState debuggerState,
      URIDescriber uriDescriber) {
    _items = SelectableList<Breakpoint>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..clazz('debugger-items-list');

    _items.setRenderer((Breakpoint breakpoint) {
      final dynamic location = breakpoint.location;

      final CoreElement element = li(c: 'list-item');

      if (location is UnresolvedSourceLocation) {
        element.text = uriDescriber(location.script.uri);
        element.add(span(text: ' line ${location.line}', c: 'subtle'));
      } else if (location is SourceLocation) {
        element.text = uriDescriber(location.script.uri);

        // Modify the rendering slightly asynchronously.
        debuggerState.getScript(location.script).then((Script script) {
          final SourcePosition pos =
              debuggerState.calculatePosition(script, location.tokenPos);
          element.add(span(text: ' line ${pos.line}', c: 'subtle'));
        });
      }

      if (!breakpoint.resolved) {
        element.add(span(text: ' (unresolved)', c: 'subtle'));
      }

      return element;
    });
  }

  final CoreElement _breakpointsCountDiv;

  SelectableList<Breakpoint> _items;

  Stream<Breakpoint> get onDoubleClick => _items.onDoubleClick;

  @override
  CoreElement get element => _items;

  Stream<Breakpoint> get onSelectionChanged => _items.onSelectionChanged;

  void showBreakpoints(List<Breakpoint> breakpoints) {
    breakpoints = breakpoints.toList();
    breakpoints.sort(_breakpointComparator);

    _items.setItems(breakpoints);
    _breakpointsCountDiv.text = breakpoints.length.toString();
  }
}

class BreakOnExceptionControl extends CoreElement {
  BreakOnExceptionControl()
      : super('div', classes: 'break-on-exceptions flex-no-wrap') {
    final CoreElement unhandledExceptionsElement = CoreElement('input')
      ..setAttribute('type', 'checkbox');
    _unhandledElement = unhandledExceptionsElement.element;

    final CoreElement allExceptionsElement = CoreElement('input')
      ..setAttribute('type', 'checkbox');
    _allElement = allExceptionsElement.element;

    add([
      span(text: 'Break on', c: 'strong'),
      span(text: ' exceptions', c: 'strong optional-1000'),
      span(text: ': ', c: 'strong'),
      CoreElement('label')
        ..add(<CoreElement>[
          unhandledExceptionsElement,
          span(text: ' unhandled')
        ]),
      CoreElement('label')
        ..add(<CoreElement>[
          allExceptionsElement,
          span(text: ' all'),
        ]),
    ]);

    unhandledExceptionsElement.element.onChange.listen((_) {
      ga.select(ga.debugger, ga.unhandledExceptions);
      _pauseModeController.add(exceptionPauseMode);
    });

    allExceptionsElement.element.onChange.listen((_) {
      ga.select(ga.debugger, ga.allExceptions);
      if (_allElement.checked) {
        unhandledExceptionsElement.enabled = false;
        _unhandledElement.checked = true;
      } else {
        unhandledExceptionsElement.enabled = true;
      }
      _pauseModeController.add(exceptionPauseMode);
    });
  }

  html.InputElement _unhandledElement;
  html.InputElement _allElement;

  final StreamController<String> _pauseModeController =
      StreamController.broadcast();

  /// See the string values for [ExceptionPauseMode].
  Stream<String> get onPauseModeChanged => _pauseModeController.stream;

  String get exceptionPauseMode {
    if (_allElement.checked) {
      return ExceptionPauseMode.kAll;
    } else if (_unhandledElement.checked) {
      return ExceptionPauseMode.kUnhandled;
    } else {
      return ExceptionPauseMode.kNone;
    }
  }

  set exceptionPauseMode(final String value) {
    if (value == ExceptionPauseMode.kAll) {
      _allElement.checked = true;
      _unhandledElement.checked = true;
      _unhandledElement.setAttribute('disabled', '');
    } else if (value == ExceptionPauseMode.kUnhandled) {
      _allElement.checked = false;
      _unhandledElement.checked = true;
      _unhandledElement.attributes.remove('disabled');
    } else {
      _allElement.checked = false;
      _unhandledElement.checked = false;
      _unhandledElement.attributes.remove('disabled');
    }
  }
}
