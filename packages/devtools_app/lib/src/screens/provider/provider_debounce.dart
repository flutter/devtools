// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'instance_viewer/eval.dart';

// TODO(rrousselGit) remove once the next Riverpod update is released
AutoDisposeStateNotifierProviderFamily<StateController<Listened>, Listened, Id>
    familyAsyncDebounce<Listened extends AsyncValue, Id>(
  Family<dynamic, Listened, Id, AutoDisposeProviderReference,
          AutoDisposeProviderBase<dynamic, Listened>>
      family, {
  Duration duration = const Duration(seconds: 1),
}) {
  return AutoDisposeStateNotifierProviderFamily<StateController<Listened>,
      Listened, Id>(
    (ref, id) {
      ref.watch(hotRestartEventProvider);
      bool listening = true;

      final controller = StateController<Listened>(
        // It is safe to use `read` here because the provider is immediately listened after
        ref.read(family(id)),
      );

      Timer? timer;
      ref.onDispose(() => timer?.cancel());

      // TODO(rrousselGit): refactor to use `ref.listen` when available
      final sub = ref.container.listen<Listened>(
        family(id),
        mayHaveChanged: (sub) async {
          return Future.microtask(() {
            if (ref.mounted && listening) sub.flush();
          });
        },
        didChange: (sub) {
          timer?.cancel();

          final value = sub.read();

          value.map(
            data: (_) => controller.state = value,
            error: (_) => controller.state = value,
            loading: (_) {
              timer = Timer(const Duration(seconds: 1), () {
                controller.state = value;
              });
            },
          );
        },
      );

      ref.onDispose(() {
        sub.close();
        listening = false;
      });
      return controller;
    },
    // ignore: invalid_use_of_protected_member
    name: family.name == null
        ? 'familyDebounced($duration)'
        // ignore: invalid_use_of_protected_member
        : '${family.name}.debounced($duration)',
  );
}

// TODO(rrousselGit) remove once the next Riverpod update is released
AutoDisposeStateNotifierProvider<StateController<Listened>, Listened>
    asyncDebounce<Listened extends AsyncValue>(
  AutoDisposeProviderBase<dynamic, Listened> provider, {
  Duration duration = const Duration(seconds: 1),
}) {
  return AutoDisposeStateNotifierProvider<StateController<Listened>, Listened>(
    (ref) {
      ref.watch(hotRestartEventProvider);
      bool listening = true;

      final controller = StateController<Listened>(
        // It is safe to use `read` here because the provider is immediately listened after
        ref.read(provider),
      );

      Timer? timer;
      ref.onDispose(() => timer?.cancel());

      // TODO(rrousselGit): refactor to use `ref.listen` when available
      final sub = ref.container.listen<Listened>(
        provider,
        mayHaveChanged: (sub) async {
          return Future.microtask(() {
            if (ref.mounted && listening) sub.flush();
          });
        },
        didChange: (sub) {
          timer?.cancel();

          final value = sub.read();

          value.map(
            data: (_) {
              controller.state = value;
            },
            error: (_) {
              controller.state = value;
            },
            loading: (_) {
              timer = Timer(const Duration(seconds: 1), () {
                controller.state = value;
              });
            },
          );
        },
      );

      ref.onDispose(() {
        sub.close();
        listening = false;
      });

      return controller;
    },
    name: provider.name == null
        ? 'debounced($duration)'
        : '${provider.name}.debounced($duration)',
  );
}
