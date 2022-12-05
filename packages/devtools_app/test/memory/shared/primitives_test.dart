// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devtools_app/src/screens/memory/shared/primitives.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doc links are not broken', () async {
    final request = await HttpClient().getUrl(Uri.parse(DocLinks.chart.value));
    final response = await request.close();

    final completer = Completer<String>();
    final content = StringBuffer();
    response.transform(utf8.decoder).listen(
      (data) {
        content.write(data);
      },
      onDone: () => completer.complete(content.toString()),
    );
    await completer.future;
    final hash = DocLinks.chart.hash;
    expect(content.toString(), contains('href="#$hash"'));
  });
}
