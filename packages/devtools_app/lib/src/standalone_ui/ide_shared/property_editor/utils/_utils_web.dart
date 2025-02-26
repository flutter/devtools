// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';

import 'package:web/web.dart';

void addBlurListener() {
  window.addEventListener('blur', _onBlur.toJS);
}

void removeBlurListener() {
  window.removeEventListener('blur', _onBlur.toJS);
}

void _onBlur(Event _) {
  final inputElement = document.activeElement as HTMLElement?;
  inputElement?.blur();
}
