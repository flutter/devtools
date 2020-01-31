// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

String convertProcessOutputToString(List<List<int>> output, String indent) {
  String result = output.map((codes) => utf8.decode(codes)).join();
  result = result.trim();
  result = result
      .split('\n')
      .where((line) => line.isNotEmpty)
      .map((line) => '$indent$line')
      .join('\n');
  return result;
}
