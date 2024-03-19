// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/config_specific/launch_url/launch_url.dart';
import '../../shared/ui/colors.dart';
import 'deep_link_list_view.dart';
import 'deep_links_controller.dart';
import 'deep_links_model.dart';
import 'deep_links_services.dart';

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
            horizontal: extraLargeSpacing,
            vertical: defaultSpacing,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This tool helps you diagnose issues with App Links in your application.'
                'Web checks are done for the web association'
                ' file on your website. App checks are done for the intent filters in'
                ' the manifest and info.plist files, routing issues, URL format, etc.',
                style: Theme.of(context).subtleTextStyle,
              ),
              if (viewType == TableViewType.domainView ||
                  viewType == TableViewType.singleUrlView)
                _DomainCheckTable(controller: controller),
              if (viewType == TableViewType.pathView ||
                  viewType == TableViewType.singleUrlView)
                _PathCheckTable(controller: controller),
              const SizedBox(height: extraLargeSpacing),
              if (linkData.domainErrors.isNotEmpty)
                Align(
                  alignment: Alignment.bottomRight,
                  child: FilledButton(
                    onPressed: () async => await controller.validateLinks(),
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
      showLeft: false,
      child: Container(
        height: actionWidgetSize,
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: intermediateSpacing),
        Text('Web check', style: theme.textTheme.titleSmall),
        const SizedBox(height: denseSpacing),
        DataTable(
          headingRowColor: MaterialStateProperty.all(
            theme.colorScheme.deeplinkTableHeaderColor,
          ),
          dataRowColor: MaterialStateProperty.all(
            theme.colorScheme.alternatingBackgroundColor2,
          ),
          columns: const [
            DataColumn(label: Text('OS')),
            DataColumn(label: Text('Issue type')),
            DataColumn(label: Text('Status')),
          ],
          headingRowHeight: defaultHeaderHeight,
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
                            '${linkData.domainErrors.length} '
                            '${pluralize('Check', linkData.domainErrors.length)} failed',
                            style: theme.errorTextStyle,
                          )
                        : Text(
                            'No issues found',
                            style: TextStyle(
                              color: theme.colorScheme.green,
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
                      style: TextStyle(color: theme.colorScheme.green),
                    ),
                  ),
                ],
              ),
          ],
        ),
        _Fingerprint(controller: controller),
        _AssetLinksJsonFileIssues(controller: controller),
        _HostingIssues(controller: controller),
        const SizedBox(height: intermediateSpacing),
        const _ViewDeveloperGuide(),
      ],
    );
  }
}

/// There is a general fix for the asset links json file issues:
/// Update it with the generated asset link file.
class _AssetLinksJsonFileIssues extends StatelessWidget {
  const _AssetLinksJsonFileIssues({
    required this.controller,
  });

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final errors = controller.selectedLink.value!.domainErrors
        .where(
          (error) => domainAssetLinksJsonFileErrors.contains(error),
        )
        .toList();
    final theme = Theme.of(context);
    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      title: _VerifiedOrErrorText(
        'Digital Asset Links JSON file related issues',
        isError: errors.isNotEmpty,
      ),
      children: [
        if (errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(largeSpacing),
            child: RoundedOutlinedBorder(
              child: Padding(
                padding: const EdgeInsets.all(largeSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FailureDetails(errors: errors, showFixGuide: false),
                    const Text('Fix guide:'),
                    const SizedBox(height: denseSpacing),
                    Text(
                      'To fix above issues, publish the recommended Digital Asset Links'
                      ' JSON file below to all of the failed website domains at the following'
                      ' location: https://[domain.name]/.well-known/assetlinks.json.',
                      style: theme.subtleTextStyle,
                    ),
                    const SizedBox(height: denseSpacing),
                    _GenerateAssetLinksPanel(controller: controller),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Hosting issue cannot be fixed by generated asset link file.
/// There is a fix guide for each hosting issue.
class _HostingIssues extends StatelessWidget {
  const _HostingIssues({required this.controller});

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final errors = controller.selectedLink.value!.domainErrors
        .where((error) => domainHostingErrors.contains(error))
        .toList();
    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      title: _VerifiedOrErrorText(
        'Hosting related issues',
        isError: errors.isNotEmpty,
      ),
      children: [
        for (final error in errors)
          Padding(
            padding: const EdgeInsets.all(largeSpacing),
            child: RoundedOutlinedBorder(
              child: Padding(
                padding: const EdgeInsets.all(largeSpacing),
                child: _FailureDetails(errors: [error]),
              ),
            ),
          ),
      ],
    );
  }
}

class _Fingerprint extends StatelessWidget {
  const _Fingerprint({
    required this.controller,
  });

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<String?>(
      valueListenable: controller.localFingerprint,
      builder: (context, localFingerprint, _) {
        final hasPdcFingerpint =
            controller.googlePlayFingerprintsAvailability.value;
        final haslocalFingerpint = localFingerprint != null;
        return ExpansionTile(
          controlAffinity: ListTileControlAffinity.leading,
          title: hasPdcFingerpint
              ? const _VerifiedOrErrorText(
                  'PDC fingerprint detected, enter a local fingerprint if needed',
                  isError: false,
                )
              : haslocalFingerpint
                  ? const _VerifiedOrErrorText(
                      'Local fingerprint detected',
                      isError: false,
                    )
                  : const _VerifiedOrErrorText(
                      'Can\'t proceed check due to no fingerprint detected',
                      isError: true,
                    ),
          children: [
            Padding(
              padding: const EdgeInsets.all(largeSpacing),
              child: RoundedOutlinedBorder(
                child: Padding(
                  padding: const EdgeInsets.all(largeSpacing),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasPdcFingerpint && !haslocalFingerpint) ...[
                        const Text('Fix guide:'),
                        const SizedBox(height: denseSpacing),
                        Text(
                          'To fix this issue, release your app on Play Developer Console to get a fingerprint. '
                          'If you are not ready to release your app, enter a local fingerprint below can also allow you'
                          'to proceed Android domain check.',
                          style: theme.subtleTextStyle,
                        ),
                        const SizedBox(height: denseSpacing),
                      ],
                      // User can add local fingerprint no matter PDC fingerpint is detected or not.
                      _LocalFingerprint(controller: controller),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LocalFingerprint extends StatelessWidget {
  const _LocalFingerprint({
    required this.controller,
  });

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Local fingerprint'),
        const SizedBox(height: intermediateSpacing),
        controller.localFingerprint.value == null
            ? TextField(
                decoration: const InputDecoration(
                  labelText: 'Enter your local fingerprint',
                  hintText: 'eg: F0:FD:6C:5B:41:0F:25:CB:25:C3:B5:33:46'
                      ':C8:97:2F:AE:30:F8:EE:74:11:DF:91:04:80:AD:6B:2D:60:DB:83',
                  filled: true,
                ),
                onSubmitted: (fingerprint) async {
                  final validFingerpintAdded =
                      controller.addLocalFingerprint(fingerprint);

                  if (!validFingerpintAdded) {
                    await showDialog(
                      context: context,
                      builder: (_) {
                        return const AlertDialog(
                          title: Text('This is not a valid fingerprint'),
                          content: Text(
                            'A valid fingerprint consists of 32 pairs of hexadecimal digits separated by colons.'
                            'It should be the same encoding and format as in the assetlinks.json',
                          ),
                          actions: [
                            DialogCloseButton(),
                          ],
                        );
                      },
                    );
                  }
                },
              )
            : _CodeCard(
                content: controller.localFingerprint.value,
                hasCopyAction: false,
              ),
        const SizedBox(height: intermediateSpacing),
        ValueListenableBuilder<String?>(
          valueListenable: controller.localFingerprint,
          builder: (context, fingerprint, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your locally added fingerprint: ',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: intermediateSpacing),
                if (fingerprint != null)
                  Text(fingerprint, style: theme.textTheme.bodySmall),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ViewDeveloperGuide extends StatelessWidget {
  const _ViewDeveloperGuide();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DevToolsButton(
        onPressed: () {
          unawaited(
            launchUrl(
              'https://developer.android.com/training/app-links/verify-android-applinks',
            ),
          );
        },
        label: 'View developer guide',
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    this.content,
    this.hasCopyAction = true,
  });

  final String? content;
  final bool hasCopyAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.alternatingBackgroundColor1,
      elevation: 0.0,
      child: Padding(
        padding: const EdgeInsets.all(denseSpacing),
        child: content != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: SelectionArea(
                      child: Text(content!),
                    ),
                  ),
                  if (hasCopyAction)
                    CopyToClipboardControl(
                      dataProvider: () => content,
                    ),
                ],
              )
            : const CenteredCircularProgressIndicator(),
      ),
    );
  }
}

class _GenerateAssetLinksPanel extends StatelessWidget {
  const _GenerateAssetLinksPanel({
    required this.controller,
  });

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder(
      valueListenable: controller.generatedAssetLinksForSelectedLink,
      builder: (
        _,
        GenerateAssetLinksResult? generatedAssetLinks,
        __,
      ) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const Text('Recommended Asset Links Json file :'),
            const SizedBox(height: denseSpacing),
            (generatedAssetLinks != null &&
                    generatedAssetLinks.errorCode.isNotEmpty)
                ? Text(
                    'Not able to generate assetlinks.json, because the app ${controller.applicationId} is not uploaded to Google Play.',
                    style: theme.subtleTextStyle,
                  )
                : Column(
                    children: [
                      _CodeCard(content: generatedAssetLinks?.generatedString),
                      const SizedBox(height: denseSpacing),
                      Text(
                        'Update and publish this new recommended Digital Asset Links JSON file below at this location:',
                        style: theme.subtleTextStyle,
                      ),
                      const SizedBox(height: denseSpacing),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Card(
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(4.0)),
                          ),
                          color: theme.colorScheme.outline,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: denseSpacing,
                            ),
                            child: SelectionArea(
                              child: Text(
                                'https://${controller.selectedLink.value!.domain}/.well-known/assetlinks.json',
                                style: theme.regularTextStyle.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: denseSpacing),
                    ],
                  ),
          ],
        );
      },
    );
  }
}

class _FailureDetails extends StatelessWidget {
  const _FailureDetails({
    required this.errors,
    this.showFixGuide = true,
  });

  final List<DomainError> errors;
  final bool showFixGuide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final error in errors) ...[
          const SizedBox(height: densePadding),
          Text('Issue : ${error.title}'),
          const SizedBox(height: densePadding),
          Text(
            error.explanation,
            style: Theme.of(context).subtleTextStyle,
          ),
          if (showFixGuide) ...[
            const SizedBox(height: defaultSpacing),
            const Text('Fix guide:'),
            const SizedBox(height: densePadding),
            Text(
              error.fixDetails,
              style: Theme.of(context).subtleTextStyle,
            ),
          ],
        ],
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
    final theme = Theme.of(context);
    final linkData = controller.selectedLink.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Associated deep link URL',
          style: theme.textTheme.titleSmall,
        ),
        Card(
          color: theme.colorScheme.surface,
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
                              color: theme.colorScheme.error,
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
  const _PathCheckTable({required this.controller});

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTileTheme(
      dense: true,
      minVerticalPadding: 0,
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: intermediateSpacing),
          Text(
            'Path check',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: intermediateSpacing),
          ListTile(
            tileColor: theme.colorScheme.deeplinkTableHeaderColor,
            title: const Row(
              children: [
                SizedBox(width: defaultSpacing),
                Expanded(
                  child: Text('OS'),
                ),
                Expanded(
                  child: Text('Issue type'),
                ),
                Expanded(
                  child: Text(
                    'Status',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1.0),
          _IntentFilterCheck(controller: controller),
          const Divider(height: 1.0),
          _PathFormatCheck(controller: controller),
        ],
      ),
    );
  }
}

class _IntentFilterCheck extends StatelessWidget {
  const _IntentFilterCheck({required this.controller});

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final linkData = controller.selectedLink.value!;
    final theme = Theme.of(context);
    final intentFilterErrorCount = intentFilterErrors
        .where((error) => linkData.pathErrors.contains(error))
        .toList()
        .length;

    return _PathCheckExpansionTile(
      checkName: 'IntentFiler',
      status: intentFilterErrorCount > 0
          ? Text(
              '$intentFilterErrorCount Check failed',
              style: theme.errorTextStyle,
            )
          : const _NoIssueText(),
      children: <Widget>[
        for (final error in intentFilterErrors)
          if (linkData.pathErrors.contains(error)) Text(error.description),
        const _CodeCard(
          content: '''<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
</intent-filter>''',
        ),
      ],
    );
  }
}

class _PathFormatCheck extends StatelessWidget {
  const _PathFormatCheck({required this.controller});

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final linkData = controller.selectedLink.value!;
    final theme = Theme.of(context);

    return _PathCheckExpansionTile(
      checkName: 'URL format',
      status: linkData.pathErrors.contains(PathError.pathFormat)
          ? Text(
              'Check failed',
              style: theme.errorTextStyle,
            )
          : const _NoIssueText(),
      children: <Widget>[
        Text(PathError.pathFormat.description),
      ],
    );
  }
}

class _PathCheckExpansionTile extends StatelessWidget {
  const _PathCheckExpansionTile({
    required this.checkName,
    required this.status,
    required this.children,
  });

  final String checkName;
  final Widget status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      backgroundColor: theme.colorScheme.alternatingBackgroundColor2,
      collapsedBackgroundColor: theme.colorScheme.alternatingBackgroundColor2,
      title: Row(
        children: [
          const SizedBox(width: defaultSpacing),
          const Expanded(child: Text('Android')),
          Expanded(child: Text(checkName)),
          Expanded(child: status),
        ],
      ),
      children: children,
    );
  }
}

class _NoIssueText extends StatelessWidget {
  const _NoIssueText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'No issues found',
      style: TextStyle(
        color: Theme.of(context).colorScheme.green,
      ),
    );
  }
}

class _VerifiedOrErrorText extends StatelessWidget {
  const _VerifiedOrErrorText(this.text, {required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        isError
            ? Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
                size: defaultIconSize,
              )
            : Icon(
                Icons.verified,
                color: Theme.of(context).colorScheme.green,
                size: defaultIconSize,
              ),
        const SizedBox(width: denseSpacing),
        Text(text),
      ],
    );
  }
}
