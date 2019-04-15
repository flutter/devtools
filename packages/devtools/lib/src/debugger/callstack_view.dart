// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import '../ui/custom.dart';
import '../ui/elements.dart';

class CallStackView implements CoreElementView {
  CallStackView() {
    _items = SelectableList<Frame>()
      ..flex()
      ..clazz('menu-item-bottom-border')
      ..clazz('debugger-items-list');

    _items.setRenderer((Frame frame) {
      String name = frame.code?.name ?? '<none>';
      if (name.startsWith('[Unoptimized] ')) {
        name = name.substring('[Unoptimized] '.length);
      }
      name = name.replaceAll('<anonymous closure>', '<closure>');

      String locationDescription;
      if (frame.kind == FrameKind.kAsyncSuspensionMarker) {
        name = '<async break>';
      } else if (frame.kind != emptyStackMarker) {
        locationDescription = frame.location.script.uri;

        if (locationDescription.contains('/')) {
          locationDescription = locationDescription
              .substring(locationDescription.lastIndexOf('/') + 1);
        }
      }

      final CoreElement element = li(text: name, c: 'list-item');
      if (frame.kind == FrameKind.kAsyncSuspensionMarker ||
          frame.kind == emptyStackMarker) {
        element.toggleClass('subtle');
      }
      if (locationDescription != null) {
        element.add(span(text: ' $locationDescription', c: 'subtle'));
      }
      return element;
    });
  }

  static const String emptyStackMarker = 'EmptyStackMarker';

  SelectableList<Frame> _items;

  List<Frame> get items => _items.items;

  @override
  CoreElement get element => _items;

  Stream<Frame> get onSelectionChanged => _items.onSelectionChanged;

  void showFrames(List<Frame> frames, {bool selectTop = false}) {
    if (frames.isEmpty) {
      // Create a marker frame for 'no call frames'.
      final Frame frame = Frame()
        ..kind = emptyStackMarker
        ..code = (CodeRef()..name = '<no call frames>');
      _items.setItems([frame]);
    } else {
      _items.setItems(frames, selection: frames.isEmpty ? null : frames.first);
    }
  }

  void clearFrames() {
    _items.setItems(<Frame>[]);
  }
}
