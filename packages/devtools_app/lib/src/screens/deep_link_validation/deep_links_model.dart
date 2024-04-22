// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/ui/colors.dart';
import '../../shared/ui/search.dart';
import 'deep_link_list_view.dart';
import 'deep_links_controller.dart';

const kDeeplinkTableCellDefaultWidth = 200.0;
const kToolTipWidth = 344.0;
const metaDataDeepLinkingFlagTag =
    '<meta-data android:name="flutter_deeplinking_enabled" android:value="true" />';
const missingDomain = 'missing domain';
const missingScheme = 'missing scheme';

enum PlatformOS {
  android('Android'),
  ios('iOS');

  const PlatformOS(this.description);
  final String description;
}

class CommonError {
  const CommonError(this.title, this.explanation, this.fixDetails);
  final String title;
  final String explanation;
  final String fixDetails;
}

class DomainError extends CommonError {
  const DomainError(title, explanation, fixDetails)
      : super(title, explanation, fixDetails);

  /// Existence of an asset link file.
  static const existence = DomainError(
    'Digital Asset Links JSON file does not exist',
    'This test checks whether the assetlinks.json file, '
        'which is used to verify the association between the app and the '
        'domain name, exists under your domain.',
    'Add a Digital Asset Links JSON file to all of the '
        'failed website domains at the following location: '
        'https://[domain.name]/.well-known/assetlinks.json. See the following recommended asset link json file. ',
  );

  /// Asset link file should define a link to this app.
  static const appIdentifier = DomainError(
    'Package name not found',
    'The test checks your Digital Asset Links JSON file '
        'for package name validation, which the mobile device '
        'uses to verify ownership of the app.',
    'Ensure your Digital Asset Links JSON file declares the '
        'correct package name with the "android_app" namespace for '
        'all of the failed website domains. Also, confirm that the '
        'app is available in the Google Play store. See the following recommended asset link json file. ',
  );

  /// Asset link file should contain the correct fingerprint.
  static const fingerprints = DomainError(
    'Fingerprint validation failed',
    'This test checks your Digital Asset Links JSON file for '
        'sha256 fingerprint validation, which the mobile device uses '
        'to verify ownership of the app.',
    'Add sha256_cert_fingerprints to the Digital Asset Links JSON '
        'file for all of the failed website domains. If the fingerprint '
        'has already been added, make sure it\'s correct and that the '
        '"android_app" namespace is declared on it. See the following recommended asset link json file. ',
  );

  /// Asset link file should be served with the correct content type.
  static const contentType = DomainError(
    'JSON content type incorrect',
    'This test checks your Digital Asset Links JSON file for content type '
        'validation, which defines the format of the JSON file. This allows '
        'the mobile device to verify ownership of the app.',
    'Ensure the content-type is "application/json" for all of the failed website domains.',
  );

  /// Asset link file should be accessible via https.
  static const httpsAccessibility = DomainError(
    'HTTPS accessibility check failed',
    'This test tries to access your Digital Asset Links '
        'JSON file over an HTTPS connection, which must be '
        'accessible to verify ownership of the app.',
    'Ensure your Digital Asset Links JSON file is accessible '
        'over an HTTPS connection for all of the failed website domains (even if '
        'the app\'s intent filter declares HTTP as the data scheme).',
  );

  /// Asset link file should be accessible with no redirects.
  static const nonRedirect = DomainError(
    'Domain non-redirect check failed',
    'This test checks that your domain is accessible without '
        'redirects. This domain must be directly accessible '
        'to verify ownership of the app.',
    'Ensure your domain is accessible without any redirects ',
  );

  /// Asset link domain should be valid/not malformed.
  static const hostForm = DomainError(
    'Host attribute is not formed properly',
    'This test checks that your android:host attribute has a valid domain URL pattern.',
    'Make sure the host is a properly formed web address such '
        'as google.com or www.google.com, without "http://" or "https://".',
  );

  /// Issues that are not covered by other checks. An example that may be in this
  /// category is Android validation API failures.
  static const other = DomainError('Check failed', '', '');
}

/// There are currently two types of path errors, errors from intent filters and path format errors.
class PathError extends CommonError {
  const PathError(title, explanation, fixDetails)
      : super(title, explanation, fixDetails);

  /// Activity should have deep link enabled flag.
  static const missingDeepLinkingFlag = PathError(
    'Activity is missing the deep linking enabled flag',
    'The activity must have the following metadata tag: '
        '$metaDataDeepLinkingFlagTag',
    '',
  );

  /// Intent filter should have action tag.
  static const intentFilterActionView = PathError(
    'Intent filter is missing action tag',
    'The intent filter must have a <action android:name="android.intent.action.VIEW" />',
    '',
  );

  /// Intent filter should have browsable tag.
  static const intentFilterBrowsable = PathError(
    'Intent filter is missing browsable tag',
    'The intent filter must have a <category android:name="android.intent.category.BROWSABLE" />',
    '',
  );

  /// Intent filter should have default tag.
  static const intentFilterDefault = PathError(
    'Intent filter is missing default tag',
    'The intent filter must have a <category android:name="android.intent.category.DEFAULT" />',
    '',
  );

  /// Intent filter should have autoVerify tag.
  static const intentFilterAutoVerify = PathError(
    'Intent filter is missing autoVerify tag',
    'The intent filter must have android:autoVerify="true"',
    '',
  );

  /// Path has format.
  static const pathFormat = PathError(
    'Path format',
    '',
    'Path must starts with “/” or “.*”',
  );
}

Set<PathError> manifestFileErrors = <PathError>{
  PathError.missingDeepLinkingFlag,
  PathError.intentFilterActionView,
  PathError.intentFilterBrowsable,
  PathError.intentFilterDefault,
  PathError.intentFilterAutoVerify,
};

class ValidatedLinkDatas {
  ValidatedLinkDatas({
    required this.all,
    required this.byDomain,
    required this.byPath,
  });
  ValidatedLinkDatas.empty()
      : all = [],
        byDomain = [],
        byPath = [];
  final List<LinkData> all;
  final List<LinkData> byDomain;
  final List<LinkData> byPath;
}

/// Contains all data relevant to a deep link.
class LinkData with SearchableDataMixin {
  LinkData({
    required this.domain,
    required this.path,
    required this.os,
    this.scheme = const <String>{},
    this.domainErrors = const <DomainError>[],
    this.pathErrors = const <PathError>{},
    this.associatedPath = const <String>[],
    this.associatedDomains = const <String>[],
  });

  final String path;
  final String? domain;
  final List<PlatformOS> os;
  final Set<String> scheme;
  final List<DomainError> domainErrors;
  Set<PathError> pathErrors;

  final List<String> associatedPath;
  final List<String> associatedDomains;

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return (domain?.caseInsensitiveContains(regExpSearch) ?? false) ||
        path.caseInsensitiveContains(regExpSearch);
  }

  @override
  String toString() => 'LinkData($domain $path)';
}

class _ErrorAwareText extends StatelessWidget {
  const _ErrorAwareText({
    required this.text,
    required this.isError,
    required this.controller,
    required this.link,
  });
  final String text;
  final bool isError;
  final DeepLinksController controller;
  final LinkData link;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isError)
          DevToolsTooltip(
            padding: const EdgeInsets.only(
              top: defaultSpacing,
              left: defaultSpacing,
              right: defaultSpacing,
            ),
            preferBelow: true,
            enableTapToDismiss: false,
            richMessage: WidgetSpan(
              child: SizedBox(
                width: kToolTipWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'This ${link.domain} domain has ${link.domainErrors.length} ${pluralize('issue', link.domainErrors.length)} to fix. '
                      'Fixing this domain will fix ${link.associatedPath.length} associated deep ${pluralize('link', link.associatedPath.length)}.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.tooltipTextColor,
                        fontSize: defaultFontSize,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        controller.updateDisplayOptions(showSplitScreen: true);
                        controller.selectLink(link);
                      },
                      child: Text(
                        'Fix this domain',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary,
                          fontSize: defaultFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: denseSpacing),
              child: Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
                size: defaultIconSize,
              ),
            ),
          ),
        const SizedBox(width: denseSpacing),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class DomainColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  DomainColumn(this.controller)
      : sortingOption = controller.displayOptions.domainSortingOption,
        super.wide('Domain');

  DeepLinksController controller;
  SortingOption? sortingOption;

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Domain'),
        PopupMenuButton<SortingOption>(
          itemBuilder: (BuildContext context) =>
              _buildPopupMenuSortingEntries(controller, isPath: false),
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  String getValue(LinkData dataObject) => dataObject.domain ?? 'missing domain';

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return dataObject.domain == null
        ? Text('missing domain', style: Theme.of(context).errorTextStyle)
        : _ErrorAwareText(
            isError: dataObject.domainErrors.isNotEmpty,
            controller: controller,
            text: dataObject.domain!,
            link: dataObject,
          );
  }

  @override
  int compare(LinkData a, LinkData b) => _compareLinkData(
        a,
        b,
        sortingOption: sortingOption,
        compareDomain: true,
      );

  @override
  String get config => '$title $sortingOption';
}

class PathColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  PathColumn(this.controller)
      : sortingOption = controller.displayOptions.pathSortingOption,
        super.wide('Path');

  DeepLinksController controller;
  SortingOption? sortingOption;

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Path'),
        PopupMenuButton<SortingOption>(
          itemBuilder: (BuildContext context) =>
              _buildPopupMenuSortingEntries(controller, isPath: true),
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  String getValue(LinkData dataObject) => dataObject.path;

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return _ErrorAwareText(
      isError: dataObject.pathErrors.isNotEmpty,
      controller: controller,
      text: dataObject.path,
      link: dataObject,
    );
  }

  @override
  int compare(LinkData a, LinkData b) => _compareLinkData(
        a,
        b,
        sortingOption: sortingOption,
        compareDomain: false,
      );

  @override
  String get config => '$title $sortingOption';
}

class NumberOfAssociatedPathColumn extends ColumnData<LinkData> {
  NumberOfAssociatedPathColumn() : super.wide('Number of associated path');

  @override
  String getValue(LinkData dataObject) =>
      dataObject.associatedPath.length.toString();
}

class NumberOfAssociatedDomainColumn extends ColumnData<LinkData> {
  NumberOfAssociatedDomainColumn() : super.wide('Number of associated domain');

  @override
  String getValue(LinkData dataObject) =>
      dataObject.associatedDomains.length.toString();
}

class SchemeColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  SchemeColumn(this.controller) : super.wide('Scheme');

  DeepLinksController controller;

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Scheme'),
        PopupMenuButton<FilterOption>(
          itemBuilder: (BuildContext context) {
            return [
              _buildPopupMenuFilterEntry(controller, FilterOption.http),
              _buildPopupMenuFilterEntry(controller, FilterOption.custom),
            ];
          },
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return dataObject.scheme.isEmpty
        ? Text(missingScheme, style: Theme.of(context).errorTextStyle)
        : Text(getValue(dataObject));
  }

  @override
  String getValue(LinkData dataObject) => dataObject.scheme.join(', ');
}

class OSColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  OSColumn(this.controller) : super.wide('OS');

  DeepLinksController controller;

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('OS'),
        PopupMenuButton<FilterOption>(
          itemBuilder: (BuildContext context) {
            return [
              _buildPopupMenuFilterEntry(controller, FilterOption.android),
              _buildPopupMenuFilterEntry(controller, FilterOption.ios),
            ];
          },
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return Text(getValue(dataObject));
  }

  @override
  String getValue(LinkData dataObject) =>
      dataObject.os.map((e) => e.description).toList().join(', ');
}

class StatusColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData>, ColumnHeaderRenderer<LinkData> {
  StatusColumn(this.controller, this.viewType) : super.wide('Status');

  DeepLinksController controller;

  TableViewType viewType;

  @override
  String getValue(LinkData dataObject) {
    if (dataObject.domainErrors.isNotEmpty) {
      return 'Failed domain checks';
    } else if (dataObject.pathErrors.isNotEmpty) {
      return 'Failed path checks';
    } else {
      return 'No issues found';
    }
  }

  @override
  Widget? buildHeader(
    BuildContext context,
    Widget Function() defaultHeaderRenderer,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Status'),
        PopupMenuButton<FilterOption>(
          itemBuilder: (BuildContext context) {
            return [
              if (viewType != TableViewType.domainView)
                _buildPopupMenuFilterEntry(
                  controller,
                  FilterOption.failedPathCheck,
                ),
              if (viewType != TableViewType.pathView)
                _buildPopupMenuFilterEntry(
                  controller,
                  FilterOption.failedDomainCheck,
                ),
              _buildPopupMenuFilterEntry(controller, FilterOption.noIssue),
            ];
          },
          child: Icon(
            Icons.arrow_drop_down,
            size: actionsIconSize,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    if (dataObject.domainErrors.isNotEmpty ||
        dataObject.pathErrors.isNotEmpty) {
      return Text(
        getValue(dataObject),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    } else {
      return Text(
        'No issues found',
        style: TextStyle(color: Theme.of(context).colorScheme.green),
        overflow: TextOverflow.ellipsis,
      );
    }
  }
}

class NavigationColumn extends ColumnData<LinkData>
    implements ColumnRenderer<LinkData> {
  NavigationColumn()
      : super(
          '',
          fixedWidthPx: scaleByFontFactor(40),
        );

  @override
  String getValue(LinkData dataObject) => '';

  @override
  Widget build(
    BuildContext context,
    LinkData dataObject, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return isRowHovered
        ? const Icon(Icons.arrow_forward)
        : const SizedBox.shrink();
  }
}

PopupMenuEntry<FilterOption> _buildPopupMenuFilterEntry(
  DeepLinksController controller,
  FilterOption filterOption,
) {
  return PopupMenuItem<FilterOption>(
    value: filterOption,
    child: Row(
      children: [
        ValueListenableBuilder<DisplayOptions>(
          valueListenable: controller.displayOptionsNotifier,
          builder: (context, option, _) => Checkbox(
            value: option.filters.contains(filterOption),
            onChanged: (bool? checked) => controller.updateDisplayOptions(
              removedFilter: checked! ? null : filterOption,
              addedFilter: checked ? filterOption : null,
            ),
          ),
        ),
        Text(filterOption.description),
      ],
    ),
  );
}

List<PopupMenuEntry<SortingOption>> _buildPopupMenuSortingEntries(
  DeepLinksController controller, {
  required bool isPath,
}) {
  return [
    _buildPopupMenuSortingEntry(
      controller,
      SortingOption.errorOnTop,
      isPath: isPath,
    ),
    _buildPopupMenuSortingEntry(
      controller,
      SortingOption.aToZ,
      isPath: isPath,
    ),
    _buildPopupMenuSortingEntry(
      controller,
      SortingOption.zToA,
      isPath: isPath,
    ),
  ];
}

PopupMenuEntry<SortingOption> _buildPopupMenuSortingEntry(
  DeepLinksController controller,
  SortingOption sortingOption, {
  required bool isPath,
}) {
  return PopupMenuItem<SortingOption>(
    onTap: () {
      controller.updateDisplayOptions(
        pathSortingOption: isPath ? sortingOption : null,
        domainSortingOption: isPath ? null : sortingOption,
      );
    },
    value: sortingOption,
    child: Text(sortingOption.description),
  );
}

class FlutterProject {
  FlutterProject({
    required this.path,
    required this.androidVariants,
  });
  final String path;
  final List<String> androidVariants;
}

int _compareLinkData(
  LinkData a,
  LinkData b, {
  SortingOption? sortingOption,
  required bool compareDomain,
}) {
  if (sortingOption == null) return 0;

  switch (sortingOption) {
    case SortingOption.errorOnTop:
      if (compareDomain) {
        if (a.domainErrors.isNotEmpty) return -1;
        if (b.domainErrors.isNotEmpty) return 1;
      } else {
        if (a.pathErrors.isNotEmpty) return -1;
        if (b.pathErrors.isNotEmpty) return 1;
      }
      return 0;
    case SortingOption.aToZ:
      if (compareDomain) return (a.domain ?? '').compareTo(b.domain ?? '');

      return a.path.compareTo(b.path);
    case SortingOption.zToA:
      if (compareDomain) return (b.domain ?? '').compareTo(a.domain ?? '');

      return b.path.compareTo(a.path);
  }
}
