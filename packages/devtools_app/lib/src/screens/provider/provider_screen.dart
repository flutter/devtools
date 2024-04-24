// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/screen.dart';
import 'instance_viewer/eval.dart';
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
    instanceProvider(InstancePath.fromProviderId(selectedProviderId)),
  );

  return instance is AsyncError;
});

final _selectedProviderNode = AutoDisposeProvider<ProviderNode?>((ref) {
  final selectedId = ref.watch(selectedProviderIdProvider);

  return ref.watch(sortedProviderNodesProvider).asData?.value.firstWhereOrNull(
        (node) => node.id == selectedId,
      );
});

final _showInternals = StateProvider<bool>((ref) => false);

class ProviderScreen extends Screen {
  ProviderScreen() : super.fromMetaData(ScreenMetaData.provider);

  static final id = ScreenMetaData.provider.id;

  @override
  Widget buildScreenBody(BuildContext context) {
    return const ProviderScreenWrapper();
  }
}

class ProviderScreenWrapper extends StatefulWidget {
  const ProviderScreenWrapper({super.key});

  @override
  State<ProviderScreenWrapper> createState() => _ProviderScreenWrapperState();
}

class _ProviderScreenWrapperState extends State<ProviderScreenWrapper>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    ga.screen(ProviderScreen.id);

    cancelListeners();
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      if (serviceConnection.serviceManager.connectedState.value.connected) {
        setServiceConnectionForProviderScreen(
          serviceConnection.serviceManager.service!,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ProviderScreenBody();
  }
}

class ProviderScreenBody extends ConsumerWidget {
  const ProviderScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitAxis = SplitPane.axisFor(context, 0.85);

    // A provider will automatically be selected as soon as one is detected
    final selectedProviderId = ref.watch(selectedProviderIdProvider);
    final detailsTitleText = selectedProviderId != null
        ? ref.watch(_selectedProviderNode)?.type ?? ''
        : '[No provider selected]';

    ref.listen<bool>(_hasErrorProvider, (_, hasError) {
      if (hasError) showProviderErrorBanner();
    });

    return SplitPane(
      axis: splitAxis,
      initialFractions: const [0.33, 0.67],
      children: [
        const RoundedOutlinedBorder(
          clip: true,
          child: Column(
            children: [
              AreaPaneHeader(
                roundedTopBorder: false,
                includeTopBorder: false,
                title: Text('Providers'),
              ),
              Expanded(
                child: ProviderList(),
              ),
            ],
          ),
        ),
        RoundedOutlinedBorder(
          clip: true,
          child: Column(
            children: [
              AreaPaneHeader(
                roundedTopBorder: false,
                includeTopBorder: false,
                title: Text(detailsTitleText),
                actions: [
                  ToolbarAction(
                    icon: Icons.settings,
                    onPressed: () {
                      unawaited(
                        showDialog(
                          context: context,
                          builder: (_) => _StateInspectorSettingsDialog(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (selectedProviderId != null)
                Expanded(
                  child: InstanceViewer(
                    rootPath: InstancePath.fromProviderId(selectedProviderId),
                    showInternalProperties: ref.watch(_showInternals),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

void showProviderErrorBanner() {
  bannerMessages.addMessage(
    ProviderUnknownErrorBanner(screenId: ProviderScreen.id).build(),
  );
}

class _StateInspectorSettingsDialog extends ConsumerWidget {
  static const title = 'State inspector configurations';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DevToolsDialog(
      title: const DialogTitleText(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                ref.read(_showInternals.notifier).update((state) => !state),
            child: Row(
              children: [
                Checkbox(
                  value: ref.watch(_showInternals),
                  onChanged: (_) => ref
                      .read(_showInternals.notifier)
                      .update((state) => !state),
                ),
                const Text(
                  'Show private properties inherited from SDKs/packages',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}
