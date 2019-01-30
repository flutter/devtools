// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
part of 'fake_flutter.dart';

/// Signature of callbacks that have no arguments and return no data.
typedef VoidCallback = void Function();

/// The signature of [State.setState] functions.
typedef StateSetter = void Function(VoidCallback fn);
