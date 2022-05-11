// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/ui/hover.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _textSpan = TextSpan(
  children: [
    TextSpan(text: 'hello', style: TextStyle(fontWeight: FontWeight.bold)),
    TextSpan(text: ' '),
    TextSpan(text: 'world'),
    TextSpan(text: ' '),
    TextSpan(text: 'foo', style: TextStyle(fontWeight: FontWeight.bold)),
    TextSpan(text: '.'),
    TextSpan(text: 'bar'),
    TextSpan(text: '.'),
    TextSpan(text: 'baz', style: TextStyle(fontWeight: FontWeight.w100)),
    TextSpan(text: ' '),
    TextSpan(text: 'blah'),
  ],
);

void main() {
  test('wordForHover returns the correct word given the provided x offset', () {
    expect(wordForHover(10, _textSpan), 'hello');
    expect(wordForHover(100, _textSpan), 'world');
    expect(wordForHover(5000, _textSpan), '');
  });

  test('wordForHover returns an empty string if there is no underlying word',
      () {
    expect(wordForHover(5000, _textSpan), '');
  });

  test('wordForHover merges words linked with `.`', () {
    expect(wordForHover(200, _textSpan), 'foo');
    expect(wordForHover(250, _textSpan), 'foo.bar');
    expect(wordForHover(300, _textSpan), 'foo.bar.baz');
  });
}
