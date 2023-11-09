// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/table/table.dart';
import '../../shared/ui/colors.dart';
import 'deep_link_list_view.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';

class ValidationDetailView extends StatelessWidget {
  const ValidationDetailView({
    super.key,
    required this.linkData,
    required this.viewType,
    required this.controller,
  });

  final LinkData linkData;
  final TableViewType viewType;
  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ValidationDetailHeader(viewType: viewType, controller: controller),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: largeSpacing,
            vertical: defaultSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This tool assistants helps you diagnose Universal Links, App Links,'
                ' and Custom Schemes in your app. Web check are done for the web association'
                ' file on your website. App checks are done for the intent filters in'
                ' the manifest and info.plist file, routing issues, URL format, etc.',
                style: Theme.of(context).subtleTextStyle,
              ),
              if (viewType == TableViewType.domainView ||
                  viewType == TableViewType.singleUrlView)
                _DomainCheckTable(
                  controller: controller,
                ),
              if (viewType == TableViewType.pathView ||
                  viewType == TableViewType.singleUrlView)
                _PathCheckTable(),
              const SizedBox(height: largeSpacing),
              Align(
                alignment: Alignment.bottomRight,
                child: FilledButton(
                  onPressed: () async => controller.validateLinks(),
                  child: const Text('Recheck all'),
                ),
              ),
              if (viewType == TableViewType.domainView)
                _DomainAssociatedLinksPanel(controller: controller),
            ],
          ),
        ),
      ],
    );
  }
}

class ValidationDetailHeader extends StatelessWidget {
  const ValidationDetailHeader({
    super.key,
    required this.viewType,
    required this.controller,
  });

  final TableViewType viewType;
  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              viewType == TableViewType.domainView
                  ? 'Selected domain validation details'
                  : 'Selected Deep link validation details',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            IconButton(
              onPressed: () =>
                  controller.updateDisplayOptions(showSplitScreen: false),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainCheckTable extends StatelessWidget {
  const _DomainCheckTable({
    required this.controller,
  });

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final linkData = controller.selectedLink.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: intermediateSpacing),
        Text('Domain check', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: denseSpacing),
        DataTable(
          headingRowColor: MaterialStateProperty.all(
            Theme.of(context).colorScheme.deeplinkTableHeaderColor,
          ),
          dataRowColor: MaterialStateProperty.all(
            Theme.of(context).colorScheme.alternatingBackgroundColor2,
          ),
          columns: const [
            DataColumn(label: Text('OS')),
            DataColumn(label: Text('Issue type')),
            DataColumn(label: Text('Status')),
          ],
          dataRowMinHeight: defaultRowHeight,
          dataRowMaxHeight: defaultRowHeight,
          rows: [
            if (linkData.os.contains(PlatformOS.android))
              DataRow(
                cells: [
                  const DataCell(Text('Android')),
                  const DataCell(Text('Digital assets link file')),
                  DataCell(
                    linkData.domainErrors.isNotEmpty
                        ? Text(
                            'Check failed',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          )
                        : Text(
                            'No issues found',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.green,
                            ),
                          ),
                  ),
                ],
              ),
            if (linkData.os.contains(PlatformOS.ios))
              DataRow(
                cells: [
                  const DataCell(Text('iOS')),
                  const DataCell(Text('Apple-App-Site-Association file')),
                  DataCell(
                    Text(
                      'No issues found',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.green),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (linkData.domainErrors.isNotEmpty)
          _DomainFixPanel(controller: controller),
      ],
    );
  }
}

class _DomainFixPanel extends StatelessWidget {
  const _DomainFixPanel({
    required this.controller,
  });

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final linkData = controller.selectedLink.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('How to fix'),
        Text(
          'Add the new recommended Digital Asset Links JSON file to the failed website domain at the correct location.',
          style: Theme.of(context).subtleTextStyle,
        ),
        Text(
          'Update and publish recommend Digital Asset Links JSON file below to this location: ',
          style: Theme.of(context).subtleTextStyle,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Card(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4.0)),
            ),
            color: Theme.of(context).colorScheme.outline,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
              child: SelectionArea(
                child: Text(
                  'https://${linkData.domain}/.well-known/assetlinks.json',
                  style: Theme.of(context).regularTextStyle.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ),
          ),
        ),
        Card(
          child: ValueListenableBuilder(
            valueListenable: controller.generatedAssetLinksForSelectedLink,
            builder: (_, String? generatedAssetLinks, __) =>
                generatedAssetLinks != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: SelectionArea(
                          child: Text(generatedAssetLinks),
                        ),
                      )
                    : const CenteredCircularProgressIndicator(),
          ),
        ),
      ],
    );
  }
}

class _DomainAssociatedLinksPanel extends StatelessWidget {
  const _DomainAssociatedLinksPanel({
    required this.controller,
  });

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final linkData = controller.selectedLink.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Associated deep link URL',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Card(
          color: Theme.of(context).colorScheme.surface,
          shape: const RoundedRectangleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(denseSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: linkData.associatedPath
                  .map(
                    (path) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: denseRowSpacing,
                      ),
                      child: Row(
                        children: <Widget>[
                          if (linkData.domainErrors.isNotEmpty)
                            Icon(
                              Icons.error,
                              color: Theme.of(context).colorScheme.error,
                              size: defaultIconSize,
                            ),
                          const SizedBox(width: denseSpacing),
                          Text(path),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _PathCheckTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notAvailableCell = DataCell(
      Text(
        'Not available',
        style: TextStyle(
          color: Theme.of(context).colorScheme.deeplinkUnavailableColor,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: intermediateSpacing),
        Text(
          'Path check (coming soon)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Opacity(
          opacity: 0.5,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.deeplinkTableHeaderColor,
            ),
            dataRowColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.alternatingBackgroundColor2,
            ),
            columns: const [
              DataColumn(label: Text('OS')),
              DataColumn(label: Text('Issue type')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              DataRow(
                cells: [
                  const DataCell(Text('Android')),
                  const DataCell(Text('Intent filter')),
                  notAvailableCell,
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('iOS')),
                  const DataCell(Text('Associated domain')),
                  notAvailableCell,
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Android, iOS')),
                  const DataCell(Text('URL format')),
                  notAvailableCell,
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Android, iOS')),
                  const DataCell(Text('Routing')),
                  notAvailableCell,
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
