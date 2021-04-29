// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider show Provider;

import '../banner_messages.dart';
import '../common_widgets.dart';
import '../screen.dart';
import '../split.dart';
import './instance_viewer/instance_details.dart';
import './instance_viewer/instance_providers.dart';
import './instance_viewer/instance_viewer.dart';
import 'provider_list.dart';
import 'provider_nodes.dart';

final _hasErrorProvider = Provider.autoDispose<bool>((ref) {
  if (ref.watch(sortedProviderNodesProvider) is AsyncError) return true;

  final selectedProviderId = ref.watch(selectedProviderIdProvider);

  if (selectedProviderId == null) return false;

  final instance = ref.watch(
    rawInstanceProvider(InstancePath.fromProviderId(selectedProviderId)),
  );

  return instance is AsyncError;
});

final _selectedProviderNode = AutoDisposeProvider<ProviderNode>((ref) {
  final selectedId = ref.watch(selectedProviderIdProvider);

  return ref.watch(sortedProviderNodesProvider).data?.value?.firstWhere(
        (node) => node.id == selectedId,
        orElse: () => null,
      );
});

class ProviderScreen extends Screen {
  const ProviderScreen()
      : super.conditional(
          id: id,
          requiresLibrary: 'package:provider/',
          title: 'Provider',
          requiresDebugBuild: true,
          icon: Icons.attach_file,
        );

  static const id = 'provider';

  @override
  Widget build(BuildContext context) {
    return const ProviderScreenBody();
  }
}

class ProviderScreenBody extends ConsumerWidget {
  const ProviderScreenBody({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context, ScopedReader watch) {
    final splitAxis = Split.axisFor(context, 0.85);

    // A provider will automatically be selected as soon as one is detected
    final selectedProviderId = watch(selectedProviderIdProvider);

    return ProviderListener<bool>(
      provider: _hasErrorProvider,
      onChange: (context, hasError) {
        if (hasError) showProviderErrorBanner(context);
      },
      child: Split(
        axis: splitAxis,
        initialFractions: const [0.33, 0.67],
        children: [
          OutlineDecoration(
            child: Column(
              children: [
                areaPaneHeader(context, title: 'Providers'),
                const Expanded(
                  child: ProviderList(),
                ),
              ],
            ),
          ),
          OutlineDecoration(
            child: Column(
              children: [
                if (selectedProviderId != null) ...[
                  areaPaneHeader(
                    context,
                    title: watch(_selectedProviderNode)?.type ?? '',
                  ),
                  Expanded(
                    child: InstanceViewer(
                      rootPath: InstancePath.fromProviderId(selectedProviderId),
                    ),
                  )
                ] else
                  areaPaneHeader(context, title: '[No provider selected]'),
              ],
            ),
          )
        ],
      ),
    );
  }
}

void showProviderErrorBanner(BuildContext context) {
  provider.Provider.of<BannerMessagesController>(
    context,
    listen: false,
  ).addMessage(
    const ProviderUnknownErrorBanner(screenId: ProviderScreen.id)
        .build(context),
  );
}
