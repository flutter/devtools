// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider show Provider;

import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import 'instance_viewer/instance_details.dart';
import 'instance_viewer/instance_providers.dart';
import 'instance_viewer/instance_viewer.dart';
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

final _showInternals = StateProvider<bool>((ref) => false);

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
    final detailsTitleText = selectedProviderId != null
        ? watch(_selectedProviderNode)?.type ?? ''
        : '[No provider selected]';
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
              children: const [
                AreaPaneHeader(
                  needsTopBorder: false,
                  title: Text('Providers'),
                ),
                Expanded(
                  child: ProviderList(),
                ),
              ],
            ),
          ),
          OutlineDecoration(
            child: Column(
              children: [
                AreaPaneHeader(
                  needsTopBorder: false,
                  title: Text(detailsTitleText),
                  rightActions: [
                    SettingsOutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => _StateInspectorSettingsDialog(),
                        );
                      },
                      label: _StateInspectorSettingsDialog.title,
                    ),
                  ],
                ),
                if (selectedProviderId != null)
                  Expanded(
                    child: InstanceViewer(
                      rootPath: InstancePath.fromProviderId(selectedProviderId),
                      showInternalProperties: watch(_showInternals).state,
                    ),
                  )
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

class _StateInspectorSettingsDialog extends ConsumerWidget {
  static const title = 'State inspector configurations';

  @override
  Widget build(BuildContext context, ScopedReader watch) {
    final theme = Theme.of(context);

    return DevToolsDialog(
      title: dialogTitleText(theme, title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleShowInternals(context),
            child: Row(
              children: [
                Checkbox(
                  value: watch(_showInternals).state,
                  onChanged: (_) => _toggleShowInternals(context),
                ),
                const Text(
                  'Show private properties inherited from SDKs/packages',
                ),
              ],
            ),
          )
        ],
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }

  void _toggleShowInternals(BuildContext context) {
    final showInternals = context.read(_showInternals);
    showInternals.state = !showInternals.state;
  }
}
