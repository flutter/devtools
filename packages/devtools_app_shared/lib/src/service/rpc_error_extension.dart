// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:vm_service/vm_service.dart';

extension RpcErrorExtension on RPCError {
  /// Whether this [RPCError] is some kind of "VM Service connection has gone"
  /// error that may occur if the VM is shut down.
  bool get isServiceDisposedError {
    if (code == RPCErrorKind.kServiceDisappeared.code ||
        code == RPCErrorKind.kConnectionDisposed.code) {
      return true;
    }

    if (code == RPCErrorKind.kServerError.code) {
      // Always ignore "client is closed" and "closed with pending request"
      // errors because these can always occur during shutdown if we were
      // just starting to send (or had just sent) a request.
      return message.contains('The client is closed') ||
          message.contains('The client closed with pending request') ||
          message.contains('Service connection dispose');
    }
    return false;
  }
}
