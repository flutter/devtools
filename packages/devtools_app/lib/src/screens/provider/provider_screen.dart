// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider show Provider;

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/banner_messages.dart';
import '../../shared/common_widgets.dart';
import '../../shared/dialogs.dart';
import '../../shared/primitives/simple_items.dart';
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
  ProviderScreen()
      : super.conditional(
          id: id,
          requiresLibrary: 'package:provider/',
          title: ScreenMetaData.provider.title,
          requiresDebugBuild: true,
          icon: Icons.attach_file,
        );

  static final id = ScreenMetaData.provider.id;

  @override
  Widget build(BuildContext context) {
    return const ProviderScreenWrapper();
  }
}

class ProviderScreenWrapper extends StatefulWidget {
  const ProviderScreenWrapper({Key? key}) : super(key: key);

  @override
  _ProviderScreenWrapperState createState() => _ProviderScreenWrapperState();
}

class _ProviderScreenWrapperState extends State<ProviderScreenWrapper> {
  @override
  void initState() {
    super.initState();
    ga.screen(ProviderScreen.id);
  }

  @override
  Widget build(BuildContext context) {
    return const ProviderScreenBody();
  }
}

class ProviderScreenBody extends ConsumerWidget {
  const ProviderScreenBody({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitAxis = Split.axisFor(context, 0.85);

    // A provider will automatically be selected as soon as one is detected
    final selectedProviderId = ref.watch(selectedProviderIdProvider);
    final detailsTitleText = selectedProviderId != null
        ? ref.watch(_selectedProviderNode)?.type ?? ''
        : '[No provider selected]';

    ref.listen<bool>(_hasErrorProvider, (_, hasError) {
      if (hasError) showProviderErrorBanner(context);
    });

    return Split(
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
                )
            ],
          ),
        ),
      ],
    );
  }
}

void showProviderErrorBanner(BuildContext context) {
  provider.Provider.of<BannerMessagesController>(
    context,
    listen: false,
  ).addMessage(
    ProviderUnknownErrorBanner(screenId: ProviderScreen.id).build(context),
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
          )
        ],
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}
