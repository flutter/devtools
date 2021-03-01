// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedantic/pedantic.dart';

import '../eval_on_dart_library.dart';
import '../globals.dart';
import '../instance_viewer/eval.dart';
import '../instance_viewer/instance_providers.dart';
import '../instance_viewer/instance_viewer.dart';
import '../riverpod_error_logger_observer.dart';
import '../screen.dart';
import '../split.dart';
import 'provider_list.dart';

final _selectedProviderEvalProvider =
    AutoDisposeFutureProvider<EvalOnDartLibrary>((ref) async {
  final isAlive = IsAlive();
  FocusManager.instance.primaryFocus.unfocus();
  ref.onDispose(isAlive.dispose);

  final selectedProviderId = ref.watch(selectedProviderIdProvider).state;

  final instanceDetails = await ref.watch(
    instanceProvider(InstancePath.fromRiverpodId(selectedProviderId)).future,
  );

  return instanceDetails.maybeMap(
    object: (instance) => instance.evalForInstance,
    orElse: () => ref.watch(evalProvider),
  );
});

class RiverpodScreen extends Screen {
  const RiverpodScreen()
      : super.conditional(
          id: id,
          requiresLibrary: 'package:riverpod/',
          title: 'Riverpod',
          requiresDebugBuild: true,
          icon: Icons.palette,
        );

  static const id = 'riverpod';

  @override
  Widget build(BuildContext context) {
    return const _RiverpodScreenBody();
  }
}

class _RiverpodScreenBody extends ConsumerWidget {
  const _RiverpodScreenBody({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, ScopedReader watch) {
    final splitAxis = Split.axisFor(context, 0.85);

    // TODO(rrousselGit) test selected provider being unmounted should select the next provider (or nothing)
    // A provider will automatically be selected as soon as one is detected
    final selectedProviderId = watch(selectedProviderIdProvider).state;

    return Split(
      axis: splitAxis,
      initialFractions: const [0.33, 0.67],
      children: [
        const _SplitBorder(child: ProviderList()),
        if (selectedProviderId != null)
          Column(
            children: [
              Expanded(
                child: _SplitBorder(
                  child: InstanceViewer(
                    rootPath: InstancePath.fromRiverpodId(selectedProviderId),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const _SplitBorder(child: _ProviderEvaluation()),
            ],
          )
        else
          const Expanded(
            child: _SplitBorder(child: SizedBox.expand()),
          )
      ],
    );
  }
}

class _ProviderEvaluation extends StatefulWidget {
  const _ProviderEvaluation({Key key}) : super(key: key);

  @override
  _ProviderEvaluationState createState() => _ProviderEvaluationState();
}

class _ProviderEvaluationState extends State<_ProviderEvaluation> {
  final isAlive = IsAlive();

  @override
  void dispose() {
    isAlive.dispose();
    super.dispose();
  }

  Future<void> _evalExpression(
    FutureOr<EvalOnDartLibrary> evalFuture,
    String expression,
  ) async {
    try {
      final eval = await evalFuture;

      final selectedProviderId = context.read(selectedProviderIdProvider).state;
      final providerInstance = await context.read(
        instanceProvider(InstancePath.fromRiverpodId(selectedProviderId))
            .future,
      );

      await eval.safeEval(
        expression,
        isAlive: isAlive,
        scope: {
          r'$value': providerInstance.instanceRefId,
        },
      );

      unawaited(
        context.refresh(
          instanceProvider(InstancePath.fromRiverpodId(selectedProviderId)),
        ),
      );

      await serviceManager.performHotReload();
    } catch (err) {
      showErrorSnackBar(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Execute code against the value exposed by this provider'),
          Consumer(
            builder: (context, watch, _) {
              final eval = watch(_selectedProviderEvalProvider.future);

              return TextField(
                onSubmitted: (value) => _evalExpression(eval, value),
                decoration: const InputDecoration(
                  hintText: r'$value.increment()',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SplitBorder extends StatelessWidget {
  const _SplitBorder({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).focusColor),
      ),
      child: child,
    );
  }
}
