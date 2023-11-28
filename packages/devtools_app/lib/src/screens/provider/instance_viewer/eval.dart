// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A few utilities related to evaluating dart code
library;

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vm_service/vm_service.dart';

import '../../../service/vm_service_wrapper.dart';
import '../../../shared/globals.dart';

Stream<VmServiceWrapper> get _serviceConnectionStream =>
    _serviceConnectionStreamController.stream;
final _serviceConnectionStreamController =
    StreamController<VmServiceWrapper>.broadcast();
void setServiceConnectionForProviderScreen(VmServiceWrapper service) {
  _serviceConnectionStreamController.add(service);
}

/// Exposes the current VmServiceWrapper.
/// By listening to this provider instead of directly accessing `serviceManager.manager.service`,
/// this ensures that providers reload properly when the devtool is connected
/// to a different application.
final serviceProvider = StreamProvider<VmServiceWrapper>((ref) async* {
  yield serviceConnection.serviceManager.service!;
  yield* _serviceConnectionStream;
});

/// An [EvalOnDartLibrary] that has access to no specific library in particular
///
/// Not suitable to be used when evaluating third-party objects, as it would
/// otherwise not be possible to read private properties.
final evalProvider = libraryEvalProvider('dart:io');

/// An [EvalOnDartLibrary] that has access to `provider`
final providerEvalProvider =
    libraryEvalProvider('package:provider/src/provider.dart');

/// An [EvalOnDartLibrary] for custom objects.
final libraryEvalProvider =
    FutureProviderFamily<EvalOnDartLibrary, String>((ref, libraryPath) async {
  final service = await ref.watch(serviceProvider.future);

  final eval = EvalOnDartLibrary(
    libraryPath,
    service,
    serviceManager: serviceConnection.serviceManager,
  );
  ref.onDispose(eval.dispose);
  return eval;
});

final hotRestartEventProvider =
    ChangeNotifierProvider<ValueNotifier<void>>((ref) {
  final selectedIsolateListenable =
      serviceConnection.serviceManager.isolateManager.selectedIsolate;

  // Since ChangeNotifierProvider calls `dispose` on the returned ChangeNotifier
  // when the provider is destroyed, we can't simply return `selectedIsolateListenable`.
  // So we're making a copy of it instead.
  final notifier = ValueNotifier<IsolateRef?>(selectedIsolateListenable.value);

  void listener() => notifier.value = selectedIsolateListenable.value;
  selectedIsolateListenable.addListener(listener);
  ref.onDispose(() => selectedIsolateListenable.removeListener(listener));

  return notifier;
});
