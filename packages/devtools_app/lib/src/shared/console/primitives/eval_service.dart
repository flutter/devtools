// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service/vm_service.dart';

import '../../../shared/globals.dart';
import '../../primitives/simple_items.dart';

class EvalService {
  EvalService(this.isolateRef);

  final Reference<IsolateRef?> isolateRef;

  String get _isolateRefId {
    final id = isolateRef.value?.id;
    if (id == null) return '';
    return id;
  }

  /// Get the populated [Obj] object, given an [ObjRef].
  ///
  /// The return value can be one of [Obj] or [Sentinel].
  Future<Obj> getObject(ObjRef objRef) {
    return serviceManager.service!.getObject(_isolateRefId, objRef.id!);
  }

  /// Cache of autocomplete matches to show for a library when that library is
  /// imported.
  ///
  /// This cache includes autocompletes from libraries exported by the library
  /// but does not include autocompletes for libraries imported by this library.
  final libraryMemberAutocompleteCache = <LibraryRef, Future<Set<String?>>>{};
}
