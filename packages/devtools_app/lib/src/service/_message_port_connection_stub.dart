// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// The stub must have the same parameters as the web implementation.
// ignore_for_file: avoid-unused-parameters

/// @docImport 'message_port_connection.dart';
library;

import 'dart:async';

import 'vm_service_wrapper.dart';

/// Connects to a VM service over a `MessagePort`, as described in
/// [messagePortUriScheme].
///
/// This is only supported on the web, so this always throws an
/// [UnsupportedError].
Future<VmServiceWrapper> connectWithMessagePort({
  required Uri uri,
  required Completer<void> finishedCompleter,
}) => throw UnsupportedError(
  'Connecting to a VM service over a MessagePort is only supported on the web.',
);
