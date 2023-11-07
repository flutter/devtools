// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      children: [
        OutlineDecoration(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  viewType == TableViewType.domainView
                      ? 'Selected domain validation details'
                      : 'Selected Deep link validation details',
                  style: textTheme.titleSmall,
                ),
                IconButton(
                  onPressed: () =>
                      controller.updateDisplayOptions(showSplitScreen: false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
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
              if (viewType == TableViewType.domainView || viewType == TableViewType.singleUrlView) ...[
                const SizedBox(height: intermediateSpacing),
                Text('Domain check', style: textTheme.titleSmall),
                const SizedBox(height: denseSpacing),
                _DomainCheckTable(
                  controller: controller,
                ),
              ],
              if (viewType == TableViewType.pathView || viewType == TableViewType.singleUrlView) ...[
                const SizedBox(height: intermediateSpacing),
                Text('Path check (coming soon)', style: textTheme.titleSmall),
                _PathCheckTable(),
              ],
              const SizedBox(height: largeSpacing),
              Align(
                alignment: Alignment.bottomRight,
                child: FilledButton(
                  onPressed: () {
                    controller.validateLinks();
                  },
                  child: const Text('Recheck all'),
                ),
              ),
              if (viewType == TableViewType.domainView) ...[
                Text('Associated deep link URL', style: textTheme.titleSmall),
                Card(
                  color: colorScheme.surface,
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
                                      color: colorScheme.error,
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
            ],
          ),
        ),
      ],
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
          dataRowMinHeight: 32,
          dataRowMaxHeight: 32,
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
        if (linkData.domainErrors.isNotEmpty) ...[
          Text('How to fix'),
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
    return Opacity(
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
    );
  }
}
