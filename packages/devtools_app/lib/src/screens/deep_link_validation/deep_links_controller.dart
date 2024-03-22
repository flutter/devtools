// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/globals.dart';
import '../../shared/server/server.dart' as server;
import 'deep_links_model.dart';
import 'deep_links_services.dart';

typedef _DomainAndPath = ({String domain, String path});

const domainAssetLinksJsonFileErrors = {
  DomainError.existence,
  DomainError.appIdentifier,
  DomainError.fingerprints,
};
const domainHostingErrors = {
  DomainError.contentType,
  DomainError.httpsAccessibility,
  DomainError.nonRedirect,
  DomainError.hostForm,
};

/// The phase of the deep link page.
enum PagePhase {
  // The empty state.
  emptyState,
  // Loading links from the flutter project.
  linksLoading,
  // Loading completed but no link to validate
  noLinks,
  // Validating links.
  linksValidating,
  // Links are validated.
  linksValidated,
  // Error page.
  errorPage,
}

enum FilterOption {
  http('http://, https://'),
  custom('Custom scheme'),
  android('Android'),
  ios('iOS'),
  noIssue('No issues found'),
  failedDomainCheck('Failed domain checks '),
  failedPathCheck('Failed path checks');

  const FilterOption(this.description);
  final String description;
}

enum SortingOption {
  aToZ('A-Z'),
  zToA('Z-A'),
  errorOnTop('Error on top');

  const SortingOption(this.description);
  final String description;
}

class DisplayOptions {
  DisplayOptions({
    this.domainErrorCount = 0,
    this.pathErrorCount = 0,
    this.showSplitScreen = false,
    this.filters = const {
      FilterOption.http,
      FilterOption.custom,
      FilterOption.android,
      FilterOption.ios,
      FilterOption.noIssue,
      FilterOption.failedDomainCheck,
      FilterOption.failedPathCheck,
    },
    this.searchContent = '',
    // Default to show result with error first.
    this.domainSortingOption = SortingOption.errorOnTop,
    this.pathSortingOption = SortingOption.errorOnTop,
  });

  int domainErrorCount = 0;
  int pathErrorCount = 0;
  bool showSplitScreen = false;
  String searchContent;
  SortingOption? domainSortingOption;
  SortingOption? pathSortingOption;

  final Set<FilterOption> filters;

  DisplayOptions updateFilter(FilterOption option, bool value) {
    final newFilter = Set<FilterOption>.of(filters);

    if (value) {
      newFilter.add(option);
    } else {
      newFilter.remove(option);
    }

    return DisplayOptions(
      domainErrorCount: domainErrorCount,
      pathErrorCount: pathErrorCount,
      showSplitScreen: showSplitScreen,
      filters: newFilter,
      searchContent: searchContent,
      domainSortingOption: domainSortingOption,
      pathSortingOption: pathSortingOption,
    );
  }

  DisplayOptions copyWith({
    int? domainErrorCount,
    int? pathErrorCount,
    bool? showSplitScreen,
    String? searchContent,
    SortingOption? domainSortingOption,
    SortingOption? pathSortingOption,
  }) {
    return DisplayOptions(
      domainErrorCount: domainErrorCount ?? this.domainErrorCount,
      pathErrorCount: pathErrorCount ?? this.pathErrorCount,
      showSplitScreen: showSplitScreen ?? this.showSplitScreen,
      filters: filters,
      searchContent: searchContent ?? '',
      domainSortingOption: domainSortingOption ?? this.domainSortingOption,
      pathSortingOption: pathSortingOption ?? this.pathSortingOption,
    );
  }
}

class DeepLinksController extends DisposableController {
  DeepLinksController() {
    selectedVariantIndex.addListener(_handleSelectedVariantIndexChanged);
  }

  @override
  void dispose() {
    super.dispose();
    selectedVariantIndex.removeListener(_handleSelectedVariantIndexChanged);
  }

  DisplayOptions get displayOptions => displayOptionsNotifier.value;
  String get applicationId =>
      _androidAppLinks[selectedVariantIndex.value]?.applicationId ?? '';

  @visibleForTesting
  List<LinkData> linkDatasByPath(List<LinkData> linkdatas) {
    final linkDatasByPath = <String, LinkData>{};
    for (var linkData in linkdatas) {
      final previousRecord = linkDatasByPath[linkData.path];
      linkDatasByPath[linkData.path] = LinkData(
        domain: linkData.domain,
        path: linkData.path,
        os: [
          if (previousRecord?.os.contains(PlatformOS.android) ??
              false || linkData.os.contains(PlatformOS.android))
            PlatformOS.android,
          if (previousRecord?.os.contains(PlatformOS.ios) ??
              false || linkData.os.contains(PlatformOS.ios))
            PlatformOS.ios,
        ],
        associatedDomains: [
          ...previousRecord?.associatedDomains ?? [],
          linkData.domain,
        ],
        pathErrors: linkData.pathErrors,
      );
    }

    return getFilterredLinks(linkDatasByPath.values.toList());
  }

  @visibleForTesting
  List<LinkData> linkDatasByDomain(List<LinkData> linkdatas) {
    final linkDatasByDomain = <String, LinkData>{};

    for (var linkData in linkdatas) {
      final previousRecord = linkDatasByDomain[linkData.domain];
      linkDatasByDomain[linkData.domain] = LinkData(
        domain: linkData.domain,
        path: linkData.path,
        os: linkData.os,
        associatedPath: [
          ...previousRecord?.associatedPath ?? [],
          linkData.path,
        ],
        domainErrors: linkData.domainErrors,
      );
    }
    return getFilterredLinks(linkDatasByDomain.values.toList());
  }

  final Map<int, AppLinkSettings> _androidAppLinks = <int, AppLinkSettings>{};

  late final selectedVariantIndex = ValueNotifier<int>(0);
  void _handleSelectedVariantIndexChanged() {
    unawaited(_loadAndroidAppLinks());
  }

  Future<void> _loadAndroidAppLinks() async {
    pagePhase.value = PagePhase.linksLoading;
    if (!_androidAppLinks.containsKey(selectedVariantIndex.value)) {
      final variant =
          selectedProject.value!.androidVariants[selectedVariantIndex.value];
      await ga.timeAsync(
        gac.deeplink,
        gac.AnalyzeFlutterProject.loadAppLinks.name,
        asyncOperation: () async {
          final AppLinkSettings result;
          try {
            result = await server.requestAndroidAppLinkSettings(
              selectedProject.value!.path,
              buildVariant: variant,
            );
            _androidAppLinks[selectedVariantIndex.value] = result;
          } catch (_) {
            pagePhase.value = PagePhase.errorPage;
          }
        },
      );
    }
    if (pagePhase.value == PagePhase.errorPage) {
      return;
    }
    await validateLinks();
  }

  Future<String?> packageDirectoryForMainIsolate() async {
    if (!serviceConnection.serviceManager.hasConnection) {
      return null;
    }
    final packageUriString =
        await serviceConnection.rootPackageDirectoryForMainIsolate();
    if (packageUriString == null) return null;
    return Uri.parse(packageUriString).toFilePath();
  }

  Set<PathError> _getPathErrorsFromIntentFilterChecks(
    IntentFilterChecks intentFilterChecks,
  ) {
    return {
      if (!intentFilterChecks.hasActionView) PathError.intentFilterActionView,
      if (!intentFilterChecks.hasBrowsableCategory)
        PathError.intentFilterBrowsable,
      if (!intentFilterChecks.hasDefaultCategory) PathError.intentFilterDefault,
      if (!intentFilterChecks.hasAutoVerify) PathError.intentFilterAutoVerify,
    };
  }

  /// Get all unverified link data.
  List<LinkData> get _allRawLinkDatas {
    final appLinks = _androidAppLinks[selectedVariantIndex.value]?.deeplinks;
    if (appLinks == null) {
      return const <LinkData>[];
    }
    final domainPathToLinkData = <_DomainAndPath, LinkData>{};
    for (final appLink in appLinks) {
      final domainAndPath = (domain: appLink.host, path: appLink.path);

      if (domainPathToLinkData[domainAndPath] == null) {
        domainPathToLinkData[domainAndPath] = LinkData(
          domain: appLink.host,
          path: appLink.path,
          pathErrors:
              _getPathErrorsFromIntentFilterChecks(appLink.intentFilterChecks),
          os: [PlatformOS.android],
          scheme: [appLink.scheme],
        );
      } else {
        final linkData = domainPathToLinkData[domainAndPath]!;
        if (!linkData.scheme.contains(appLink.scheme)) {
          linkData.scheme.add(appLink.scheme);
        }
        final pathErrors = {
          ...linkData.pathErrors,
          ..._getPathErrorsFromIntentFilterChecks(appLink.intentFilterChecks),
        };

        linkData.pathErrors = pathErrors;
      }
    }

    return domainPathToLinkData.values.toList();
  }

  final selectedProject = ValueNotifier<FlutterProject?>(null);
  final googlePlayFingerprintsAvailability = ValueNotifier<bool>(false);
  final localFingerprint = ValueNotifier<String?>(null);
  final selectedLink = ValueNotifier<LinkData?>(null);
  final pagePhase = ValueNotifier<PagePhase>(PagePhase.emptyState);

  /// These are all link datas before applying displayOptions.
  var validatedLinkDatas =
      ValidatedLinkDatas(all: [], byDomain: [], byPath: []);

  /// These are link datas actually displayed in the data table after filtering by displayOptions.
  final displayLinkDatasNotifier = ValueNotifier<ValidatedLinkDatas>(
    ValidatedLinkDatas(all: [], byDomain: [], byPath: []),
  );

  final generatedAssetLinksForSelectedLink =
      ValueNotifier<GenerateAssetLinksResult?>(null);

  final displayOptionsNotifier =
      ValueNotifier<DisplayOptions>(DisplayOptions());

  /// The [TextEditingController] for the search text field.
  final textEditingController = TextEditingController();
  final deepLinksServices = DeepLinksServices();

  bool addLocalFingerprint(String fingerprint) {
    // A valid fingerprint consists of 32 pairs of hexadecimal digits separated by colons.
    bool isValidFingerprint(String input) {
      final RegExp pattern =
          RegExp(r'^([0-9a-f]{2}:){31}[0-9a-f]{2}$', caseSensitive: false);
      return pattern.hasMatch(input);
    }

    if (!isValidFingerprint(fingerprint)) {
      return false;
    }
    if (localFingerprint.value != fingerprint) {
      localFingerprint.value = fingerprint;
      // If the local fingerprint is updated, re-generate asset link file.
      unawaited(_generateAssetLinks());
    }
    return true;
  }

  Future<void> _generateAssetLinks() async {
    generatedAssetLinksForSelectedLink.value = null;
    generatedAssetLinksForSelectedLink.value =
        await deepLinksServices.generateAssetLinks(
      domain: selectedLink.value!.domain,
      applicationId: applicationId,
      localFingerprint: localFingerprint.value,
    );
  }

  Future<List<LinkData>> _validateAndroidDomain(
    List<LinkData> linkdatas,
  ) async {
    final domains = linkdatas
        .where((linkdata) => linkdata.os.contains(PlatformOS.android))
        .map((linkdata) => linkdata.domain)
        .toSet()
        .toList();

    late final Map<String, List<DomainError>> domainErrors;

    try {
      final result = await deepLinksServices.validateAndroidDomain(
        domains: domains,
        applicationId: applicationId,
        localFingerprint: localFingerprint.value,
      );
      domainErrors = result.domainErrors;
      googlePlayFingerprintsAvailability.value =
          result.googlePlayFingerprintsAvailability;
    } catch (_) {
      //TODO(hangyujin): Add more error handling for cases like RPC error and invalid json.
      pagePhase.value = PagePhase.errorPage;
      return linkdatas;
    }

    return linkdatas.map((linkdata) {
      final errors = domainErrors[linkdata.domain];
      if (errors != null && errors.isNotEmpty) {
        return LinkData(
          domain: linkdata.domain,
          domainErrors: errors,
          path: linkdata.path,
          pathErrors: linkdata.pathErrors,
          os: linkdata.os,
          scheme: linkdata.scheme,
          associatedDomains: linkdata.associatedDomains,
          associatedPath: linkdata.associatedPath,
        );
      }
      return linkdata;
    }).toList();
  }

  Future<List<LinkData>> _validatePath(List<LinkData> linkdatas) async {
    for (final linkData in linkdatas) {
      if (!(linkData.path.startsWith('/') || linkData.path == '.*')) {
        linkData.pathErrors.add(PathError.pathFormat);
      }
    }
    return linkdatas;
  }

  Future<void> validateLinks() async {
    List<LinkData> linkdata = _allRawLinkDatas;
    if (linkdata.isEmpty) {
      pagePhase.value = PagePhase.noLinks;
      return;
    }
    pagePhase.value = PagePhase.linksValidating;

    linkdata = await _validateAndroidDomain(linkdata);
    if (pagePhase.value == PagePhase.errorPage) {
      return;
    }
    linkdata = await _validatePath(linkdata);

    if (pagePhase.value == PagePhase.errorPage) {
      return;
    }

    validatedLinkDatas = ValidatedLinkDatas(
      all: linkdata,
      byDomain: linkDatasByDomain(linkdata),
      byPath: linkDatasByPath(linkdata),
    );
    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount: validatedLinkDatas.byDomain
          .where((element) => element.domainErrors.isNotEmpty)
          .length,
      pathErrorCount: validatedLinkDatas.byPath
          .where((element) => element.pathErrors.isNotEmpty)
          .length,
    );
    applyFilters();

    pagePhase.value = PagePhase.linksValidated;
  }

  void selectLink(LinkData linkdata) async {
    selectedLink.value = linkdata;
    if (linkdata.domainErrors.isNotEmpty) {
      await _generateAssetLinks();
    }
  }

  set searchContent(String content) {
    displayOptionsNotifier.value =
        displayOptionsNotifier.value.copyWith(searchContent: content);
    applyFilters();
  }

  void updateDisplayOptions({
    int? domainErrorCount,
    int? pathErrorCount,
    bool? showSplitScreen,
    SortingOption? domainSortingOption,
    SortingOption? pathSortingOption,
    FilterOption? addedFilter,
    FilterOption? removedFilter,
  }) {
    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount: domainErrorCount,
      pathErrorCount: pathErrorCount,
      showSplitScreen: showSplitScreen,
      domainSortingOption: domainSortingOption,
      pathSortingOption: pathSortingOption,
    );
    if (addedFilter != null) {
      displayOptionsNotifier.value =
          displayOptionsNotifier.value.updateFilter(addedFilter, true);
    }
    if (removedFilter != null) {
      displayOptionsNotifier.value =
          displayOptionsNotifier.value.updateFilter(removedFilter, false);
    }

    if (addedFilter != null || removedFilter != null) {
      applyFilters();
    }
  }

  void applyFilters() {
    displayLinkDatasNotifier.value = ValidatedLinkDatas(
      all: getFilterredLinks(validatedLinkDatas.all),
      byDomain: getFilterredLinks(validatedLinkDatas.byDomain),
      byPath: getFilterredLinks(validatedLinkDatas.byPath),
    );
  }

  @visibleForTesting
  List<LinkData> getFilterredLinks(List<LinkData> linkDatas) {
    final String searchContent = displayOptions.searchContent;
    linkDatas = linkDatas.where((linkData) {
      if (searchContent.isNotEmpty &&
          !linkData.matchesSearchToken(
            RegExp(searchContent, caseSensitive: false),
          )) {
        return false;
      }

      if (!((linkData.os.contains(PlatformOS.android) &&
              displayOptions.filters.contains(FilterOption.android)) ||
          (linkData.os.contains(PlatformOS.ios) &&
              displayOptions.filters.contains(FilterOption.ios)))) {
        return false;
      }

      if (!((linkData.domainErrors.isNotEmpty &&
              displayOptions.filters
                  .contains(FilterOption.failedDomainCheck)) ||
          (linkData.pathErrors.isNotEmpty &&
              displayOptions.filters.contains(FilterOption.failedPathCheck)) ||
          (linkData.domainErrors.isEmpty &&
              linkData.pathErrors.isEmpty &&
              displayOptions.filters.contains(FilterOption.noIssue)))) {
        return false;
      }

      return true;
    }).toList();

    return linkDatas;
  }
}
