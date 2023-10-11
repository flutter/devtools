// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import 'vm_service_wrapper.dart';

// Defined in SDK: https://github.com/dart-lang/sdk/blob/master/runtime/vm/flag_list.h.
const asyncDebugger = 'async_debugger';
const causalAsyncStacks = 'causal_async_stacks';
const profiler = 'profiler';

// Defined in SDK: https://github.com/dart-lang/sdk/blob/master/runtime/vm/profiler.cc#L36
const profilePeriod = 'profile_period';

class VmFlagManager with DisposerMixin {
  VmServiceWrapper get service => _service;
  late VmServiceWrapper _service;

  ValueListenable<FlagList?> get flags => _flags;
  final _flags = ValueNotifier<FlagList?>(null);

  final _flagNotifiers = <String, ValueNotifier<Flag>>{};

  ValueNotifier<Flag>? flag(String name) {
    return _flagNotifiers.containsKey(name) ? _flagNotifiers[name] : null;
  }

  Future<void> _initFlags() async {
    final flagList = await service.getFlagList();
    _flags.value = flagList;

    for (var flag in flagList.flags ?? <Flag>[]) {
      _flagNotifiers[flag.name ?? ''] = ValueNotifier<Flag>(flag);
    }
  }

  @visibleForTesting
  void handleVmEvent(Event event) async {
    if (event.kind == EventKind.kVMFlagUpdate) {
      if (_flagNotifiers.containsKey(event.flag)) {
        final currentFlag = _flagNotifiers[event.flag]!.value;
        _flagNotifiers[event.flag]!.value = Flag.parse({
          'name': currentFlag.name,
          'comment': currentFlag.comment,
          'modified': true,
          'valueAsString': event.newValue,
        })!;
        _flags.value = await service.getFlagList();
      }
    }
  }

  Future<void> vmServiceOpened(VmServiceWrapper service) async {
    cancelStreamSubscriptions();
    _service = service;
    // Upon setting the vm service, get initial values for vm flags.
    await _initFlags();

    autoDisposeStreamSubscription(service.onVMEvent.listen(handleVmEvent));
  }

  void vmServiceClosed() {
    _flags.value = null;
  }
}
