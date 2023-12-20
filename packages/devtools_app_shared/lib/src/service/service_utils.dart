// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:vm_service/vm_service.dart';

extension VmServiceExtension on VmService {
  /// Retrieves the full string value of a [stringRef].
  ///
  /// The string value stored with the [stringRef] is returned unless the value
  /// is truncated, in which an extra getObject call is issued to return the
  /// value. If the [stringRef] has expired so the full string is unavailable,
  /// [onUnavailable] is called to return how the truncated value should be
  /// displayed. If [onUnavailable] is not specified, an exception is thrown
  /// if the full value cannot be retrieved.
  Future<String?> retrieveFullStringValue(
    String isolateId,
    InstanceRef stringRef, {
    String Function(String? truncatedValue)? onUnavailable,
  }) async {
    if (stringRef.valueAsStringIsTruncated != true) {
      return stringRef.valueAsString;
    }

    final result = await getObject(
      isolateId,
      stringRef.id!,
      offset: 0,
      count: stringRef.length,
    );
    if (result is Instance) {
      return result.valueAsString;
    } else if (onUnavailable != null) {
      return onUnavailable(stringRef.valueAsString);
    } else {
      throw Exception(
        'The full string for "{stringRef.valueAsString}..." is unavailable',
      );
    }
  }

  /// Executes `callback` for each isolate, and waiting for all callbacks to
  /// finish before completing.
  Future<void> forEachIsolate(
    Future<void> Function(IsolateRef) callback,
  ) async {
    await forEachIsolateHelper(this, callback);
  }
}

Future<void> forEachIsolateHelper(
  VmService vmService,
  Future<void> Function(IsolateRef) callback,
) async {
  final vm = await vmService.getVM();
  final futures = <Future<void>>[];
  for (final isolate in vm.isolates ?? []) {
    futures.add(callback(isolate));
  }
  await Future.wait(futures);
}
