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
import '../theme.dart';
import '../ui/label.dart';
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
                  actions: [
                    _DevtoolTheme(
                      child: ToggleButtons(
                        isSelected: [watch(_showInternals).state],
                        onPressed: (_) {
                          final showInternals = context.read(_showInternals);
                          showInternals.state = !showInternals.state;
                        },
                        children: const <Widget>[
                          _ToggleImageIconLabel(
                            icon: Icon(Icons.fingerprint),
                            text: 'Show internals',
                            tooltipMessage:
                                'Show private properties inherited from SDKs/packages',
                          )
                        ],
                      ),
                    )
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

class _DevtoolTheme extends StatelessWidget {
  const _DevtoolTheme({Key key, @required this.child}) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      data: ThemeData(
        tooltipTheme: const TooltipThemeData(
          showDuration: tooltipWait,
          preferBelow: false,
        ),
        toggleButtonsTheme: ToggleButtonsThemeData(
          // TODO(kenz): ensure border radius is set correctly for single child
          // groups once https://github.com/flutter/flutter/issues/73725 is fixed.
          borderRadius: const BorderRadius.all(Radius.circular(4.0)),
          color: theme.colorScheme.contrastForeground,
          textStyle: theme.textTheme.bodyText1,
          constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
        ),
      ),
      child: child,
    );
  }
}

class _ToggleImageIconLabel extends StatelessWidget {
  const _ToggleImageIconLabel({
    Key key,
    @required this.icon,
    @required this.text,
    @required this.tooltipMessage,
  }) : super(key: key);
  final Widget icon;
  final String text;
  final String tooltipMessage;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltipMessage,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
        child: ImageIconLabel(
          icon,
          text,
        ),
      ),
    );
  }
}
