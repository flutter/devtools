// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide VmService;

import '../../../service/vm_service_wrapper.dart';
import '../../../shared/globals.dart';

class VMStatisticsViewController extends DisposableController {
  VMStatisticsViewController() {
    unawaited(refresh());
  }

  Future<void> refresh() async {
    _refreshing.value = true;
    final vm = await _service.getVM();
    _vm = vm;
    _isolates = await Future.wait<Isolate>(
      vm.isolates!.map(
        (i) => _service.getIsolate(i.id!),
      ),
    );
    _systemIsolates = await Future.wait<Isolate>(
      vm.systemIsolates!.map(
        (i) => _service.getIsolate(i.id!),
      ),
    );
    _refreshing.value = false;
  }

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(true);

  VmServiceWrapper get _service => serviceConnection.serviceManager.service!;

  VM? get vm => _vm;
  VM? _vm;

  /// The list of [Isolate]s running user code.
  List<Isolate> get isolates => UnmodifiableListView(_isolates);
  List<Isolate> _isolates = [];

  /// The list of [Isolate]s listed as system isolates. Typically includes:
  ///   - Service isolate
  ///   - Kernel isolate (standalone VM)
  ///   - CLI isolate (standalone VM)
  List<Isolate> get systemIsolates => UnmodifiableListView(_systemIsolates);
  List<Isolate> _systemIsolates = [];
}
