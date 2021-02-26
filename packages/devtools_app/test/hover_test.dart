// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/debugger/hover.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

const _defaultStyle = TextStyle();
const _textSpan = TextSpan(children: [
  TextSpan(text: 'hello'),
  TextSpan(text: 'world'),
  TextSpan(text: 'foo'),
  TextSpan(text: '.'),
  TextSpan(text: 'bar'),
  TextSpan(text: '.'),
  TextSpan(text: 'baz'),
  TextSpan(text: 'blah'),
]);

void main() {
  test('wordForHover returns the correct word given the provided x offset', () {
    expect(wordForHover(10, _textSpan, _defaultStyle), 'hello');
    expect(wordForHover(100, _textSpan, _defaultStyle), 'world');
    expect(wordForHover(5000, _textSpan, _defaultStyle), '');
  });

  test('wordForHover returns an empty string if there is no underlying word',
      () {
    expect(wordForHover(5000, _textSpan, _defaultStyle), '');
  });

  test('wordForHover merges words linked with `.`', () {
    expect(wordForHover(150, _textSpan, _defaultStyle), 'foo.bar.baz');
    expect(wordForHover(200, _textSpan, _defaultStyle), 'foo.bar.baz');
  });
}
