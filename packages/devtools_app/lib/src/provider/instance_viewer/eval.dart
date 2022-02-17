// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A few utilities related to evaluating dart code

// @dart=2.9

library eval;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vm_service/vm_service.dart';

import '../../service/vm_service_wrapper.dart';
import '../../shared/eval_on_dart_library.dart';
import '../../shared/globals.dart';

/// Exposes the current VmServiceWrapper.
/// By listening to this provider instead of directly accessing `serviceManager.service`,
/// this ensures that providers reload properly when the devtool is connected
/// to a different application.
final serviceProvider = StreamProvider<VmServiceWrapper>((ref) async* {
  yield serviceManager.service;
  yield* serviceManager.onConnectionAvailable;
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
  final service = await ref.watch(serviceProvider.last);

  final eval = EvalOnDartLibrary(libraryPath, service);
  ref.onDispose(eval.dispose);
  return eval;
});

final hotRestartEventProvider =
    ChangeNotifierProvider<ValueNotifier<IsolateRef>>((ref) {
  return serviceManager.isolateManager.selectedIsolate;
});
