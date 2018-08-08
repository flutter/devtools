// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'elements.dart';

class ProgressElement extends CoreElement {
  int _value = 0;
  int _max = 100;
  CoreElement completeElement;

  ProgressElement() : super('div') {
    clazz('progress-element');
    add(completeElement = div(c: 'complete'));
  }

  int get value => _value;

  set value(int val) {
    _value = val;

    _update();
  }

  int get max => _max;

  set max(int val) {
    _max = val;

    _update();
  }

  void _update() {
    // TODO: don't hard-code the width
    completeElement.element.style.width = '${(200 * _value / _max).round()}px';
  }
}
