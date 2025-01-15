// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This code was pulled from dart:io.

part of 'http.dart';

class HttpException {
  const HttpException(this.message, {this.uri});

  @override
  String toString() {
    final b =
        StringBuffer()
          ..write('HttpException: ')
          ..write(message);
    if (uri != null) {
      b.write(', uri = $uri');
    }
    return b.toString();
  }

  final String message;
  final Uri? uri;
}
