// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
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
    return ListTileTheme(
      // TODO(hangyujin): Set `minTileHeight` when it is available for devtool.
      // related PR: https://github.com/flutter/flutter/pull/145244
      data: const ListTileThemeData(
        dense: true,
        minVerticalPadding: 0,
        contentPadding: EdgeInsets.zero,
      ),
      child: ListView(
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
                const SizedBox(height: largeSpacing),
                const _ViewDeveloperGuide(),
              ],
            ),
          ),
        ],
      ),
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
    return ValueListenableBuilder<String?>(
      valueListenable: controller.localFingerprint,
      builder: (context, localFingerprint, _) {
        final fingerprintExists =
            controller.googlePlayFingerprintsAvailability.value ||
                localFingerprint != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: intermediateSpacing),
            Text('Web check', style: theme.textTheme.titleSmall),
            const SizedBox(height: denseSpacing),
            const _CheckTableHeader(),
            _CheckExpansionTile(
              initiallyExpanded: !fingerprintExists,
              checkName: 'Digital assets link file',
              status:
                  _CheckStatusText(hasError: linkData.domainErrors.isNotEmpty),
              children: <Widget>[
                _Fingerprint(controller: controller),
                // The following checks are only displayed if a fingerprint exists.
                if (fingerprintExists) ...[
                  _AssetLinksJsonFileIssues(controller: controller),
                  _HostingIssues(controller: controller),
                ],
              ],
            ),
            const SizedBox(height: intermediateSpacing),
          ],
        );
      },
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
    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      title: _VerifiedOrErrorText(
        'Digital Asset Links JSON file related issues',
        isError: errors.isNotEmpty,
      ),
      children: [
        if (errors.isNotEmpty)
          _IssuesBorderWrap(
            children: [
              _FailureDetails(
                errors: errors,
                oneFixGuideForAll:
                    'To fix above issues, publish the recommended Digital Asset Links'
                    ' JSON file below to all of the failed website domains at the following'
                    ' location: https://${controller.selectedLink.value!.domain}/.well-known/assetlinks.json.',
              ),
              const SizedBox(height: denseSpacing),
              _GenerateAssetLinksPanel(controller: controller),
            ],
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
          _IssuesBorderWrap(
            children: [
              _FailureDetails(errors: [error]),
            ],
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
    final hasPdcFingerprint =
        controller.googlePlayFingerprintsAvailability.value;
    final haslocalFingerprint = controller.localFingerprint.value != null;
    final isError = !hasPdcFingerprint && !haslocalFingerprint;
    late String title;
    if (hasPdcFingerprint && haslocalFingerprint) {
      title = 'PDC fingerprint and Local fingerprint are detected';
    }
    if (hasPdcFingerprint && !haslocalFingerprint) {
      title = 'PDC fingerprint detected, enter a local fingerprint if needed';
    }
    if (!hasPdcFingerprint && haslocalFingerprint) {
      title = 'Local fingerprint detected';
    }
    if (isError) {
      title = 'Can\'t proceed check due to no fingerprint detected';
    }

    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      initiallyExpanded: isError,
      title: _VerifiedOrErrorText(
        title,
        isError: isError,
      ),
      children: [
        _IssuesBorderWrap(
          children: [
            if (hasPdcFingerprint && !haslocalFingerprint) ...[
              Text(
                'Your PDC fingerprint has been detected. If you have local fingerprint, you can enter it below.',
                style: theme.subtleTextStyle,
              ),
              const SizedBox(height: denseSpacing),
            ],
            if (isError) ...[
              const Text(
                'Issue: no fingerprint detached locally or on PDC',
              ),
              const SizedBox(height: denseSpacing),
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
            // User can add local fingerprint no matter PDC fingerprint is detected or not.
            _LocalFingerprint(controller: controller),
          ],
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Local fingerprint'),
        const SizedBox(height: intermediateSpacing),
        controller.localFingerprint.value == null
            ? TextField(
                decoration: const InputDecoration(
                  labelText: 'Enter your local fingerprint',
                  hintText:
                      'eg: A1:B2:C3:D4:A1:B2:C3:D4:A1:B2:C3:D4:A1:B2:C3:D4:A1:B2:C3:D4:A1:B2:C3:D4:A1:B2:C3:D4:A1:B2:C3:D4',
                  filled: true,
                ),
                onSubmitted: (fingerprint) async {
                  final validFingerprintAdded =
                      controller.addLocalFingerprint(fingerprint);

                  if (!validFingerprintAdded) {
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
                  Flexible(child: SelectionArea(child: Text(content!))),
                  if (hasCopyAction)
                    CopyToClipboardControl(dataProvider: () => content),
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
        return (generatedAssetLinks != null &&
                generatedAssetLinks.errorCode.isNotEmpty)
            ? Text(
                'Not able to generate assetlinks.json, because the app ${controller.applicationId} is not uploaded to Google Play.',
                style: theme.subtleTextStyle,
              )
            : _CodeCard(content: generatedAssetLinks?.generatedString);
      },
    );
  }
}

class _FailureDetails extends StatelessWidget {
  const _FailureDetails({
    required this.errors,
    this.oneFixGuideForAll,
  });

  final List<CommonError> errors;
  final String? oneFixGuideForAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final error in errors) ...[
          const SizedBox(height: densePadding),
          Text('Issue: ${error.title}'),
          const SizedBox(height: densePadding),
          Text(
            error.explanation,
            style: Theme.of(context).subtleTextStyle,
          ),
          if (oneFixGuideForAll == null) ...[
            const SizedBox(height: defaultSpacing),
            const Text('Fix guide:'),
            const SizedBox(height: densePadding),
            Text(
              error.fixDetails,
              style: Theme.of(context).subtleTextStyle,
            ),
          ],
        ],
        if (oneFixGuideForAll != null) ...[
          const SizedBox(height: defaultSpacing),
          const Text('Fix guide:'),
          const SizedBox(height: densePadding),
          Text(
            oneFixGuideForAll!,
            style: Theme.of(context).subtleTextStyle,
          ),
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
                          Text('${linkData.domain}$path'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: intermediateSpacing),
        Text(
          'Path check',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: intermediateSpacing),
        const _CheckTableHeader(),
        const Divider(height: 1.0),
        _ManifestFileCheck(controller: controller),
        const Divider(height: 1.0),
        _PathFormatCheck(controller: controller),
      ],
    );
  }
}

class _ManifestFileCheck extends StatelessWidget {
  const _ManifestFileCheck({required this.controller});

  final DeepLinksController controller;

  @override
  Widget build(BuildContext context) {
    final linkData = controller.selectedLink.value!;
    final errors = manifestFileErrors
        .where((error) => linkData.pathErrors.contains(error))
        .toList();

    return _CheckExpansionTile(
      checkName: 'Manifest file',
      status: _CheckStatusText(hasError: errors.isNotEmpty),
      children: <Widget>[
        if (errors.isNotEmpty)
          _IssuesBorderWrap(
            children: [
              _FailureDetails(
                errors: errors,
                oneFixGuideForAll:
                    'Copy the following code into your Manifest file.',
              ),
              const _CodeCard(
                content: '''<meta-data android:name="flutter_deeplinking_enabled" android:value="true" />'

<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
</intent-filter>''',
              ),
            ],
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
    final hasError = linkData.pathErrors.contains(PathError.pathFormat);

    return _CheckExpansionTile(
      checkName: 'URL format',
      status: _CheckStatusText(hasError: hasError),
      children: <Widget>[
        if (hasError)
          const _IssuesBorderWrap(
            children: [
              _FailureDetails(errors: [PathError.pathFormat]),
            ],
          ),
      ],
    );
  }
}

class _CheckTableHeader extends StatelessWidget {
  const _CheckTableHeader();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Theme.of(context).colorScheme.deeplinkTableHeaderColor,
      title: const Padding(
        padding: EdgeInsets.symmetric(horizontal: defaultSpacing),
        child: Row(
          children: [
            Expanded(child: Text('OS')),
            Expanded(child: Text('Issue type')),
            Expanded(child: Text('Status')),
          ],
        ),
      ),
    );
  }
}

class _CheckExpansionTile extends StatelessWidget {
  const _CheckExpansionTile({
    required this.checkName,
    required this.status,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String checkName;
  final Widget status;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      backgroundColor: theme.colorScheme.alternatingBackgroundColor2,
      collapsedBackgroundColor: theme.colorScheme.alternatingBackgroundColor2,
      initiallyExpanded: initiallyExpanded,
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

class _IssuesBorderWrap extends StatelessWidget {
  const _IssuesBorderWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: largeSpacing,
        vertical: densePadding,
      ),
      child: RoundedOutlinedBorder(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: largeSpacing,
            vertical: densePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _CheckStatusText extends StatelessWidget {
  const _CheckStatusText({required this.hasError});

  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return hasError
        ? Text(
            'Check failed',
            style: theme.errorTextStyle,
          )
        : Text(
            'No issues found',
            style: TextStyle(color: theme.colorScheme.green),
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
