// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'vm_service_wrapper.dart';

/// Connects to a VM Service using a `MessagePort` transferred via postMessage.
Future<VmServiceWrapper> connectWithPostMessage({
  required Uri uri,
  required Completer<void> finishedCompleter,
}) => throw UnsupportedError('unsupported platform');
