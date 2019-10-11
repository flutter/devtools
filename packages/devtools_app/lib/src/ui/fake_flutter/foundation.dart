// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
part of '_fake_flutter.dart';

/// Signature of callbacks that have no arguments and return no data.
typedef VoidCallback = void Function();

/// The signature of [State.setState] functions.
typedef StateSetter = void Function(VoidCallback fn);

const kReleaseMode = false;

/// Configure [debugFormatDouble] using [num.toStringAsPrecision].
///
/// Defaults to null, which uses the default logic of [debugFormatDouble].
int debugDoublePrecision;

/// Formats a double to have standard formatting.
///
/// This behavior can be overriden by [debugDoublePrecision].
String debugFormatDouble(double value) {
  if (value == null) {
    return 'null';
  }
  if (debugDoublePrecision != null) {
    return value.toStringAsPrecision(debugDoublePrecision);
  }
  return value.toStringAsFixed(1);
}
