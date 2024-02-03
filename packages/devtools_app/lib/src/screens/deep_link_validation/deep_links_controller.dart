// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter/widgets.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/server/server.dart' as server;
import 'deep_links_model.dart';
import 'deep_links_services.dart';

typedef _DomainAndPath = ({String domain, String path});

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
  String get applicationId => _androidAppLinks[selectedVariantIndex.value]?.applicationId ?? '';

  List<LinkData> get getLinkDatasByPath {
    final linkDatasByPath = <String, LinkData>{};
    for (var linkData in allValidatedLinkDatas!) {
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
        pathError: linkData.pathError,
      );
    }

    return getFilterredLinks(linkDatasByPath.values.toList());
  }

  List<LinkData> get getLinkDatasByDomain {
    final linkDatasByDomain = <String, LinkData>{};

    for (var linkData in allValidatedLinkDatas!) {
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
          final result = await server.requestAndroidAppLinkSettings(
            selectedProject.value!.path,
            buildVariant: variant,
          );
          _androidAppLinks[selectedVariantIndex.value] = result;
        },
      );
    }
    await validateLinks();
  }

  /// Get all unverified link data.
  List<LinkData> get _allRawLinkDatas {
    final appLinks = _androidAppLinks[selectedVariantIndex.value]?.deeplinks;
    if (appLinks == null) {
      return const <LinkData>[];
    }
    final domainPathToScheme = <_DomainAndPath, Set<String>>{};
    for (final appLink in appLinks) {
      final schemes = domainPathToScheme.putIfAbsent(
        (domain: appLink.host, path: appLink.path),
        () => <String>{},
      );
      schemes.add(appLink.scheme);
    }
    return domainPathToScheme.entries
        .map(
          (entry) => LinkData(
            domain: entry.key.domain,
            path: entry.key.path,
            os: [PlatformOS.android],
            scheme: entry.value.toList(),
          ),
        )
        .toList();
  }

  final selectedProject = ValueNotifier<FlutterProject?>(null);
  final selectedLink = ValueNotifier<LinkData?>(null);
  final pagePhase = ValueNotifier<PagePhase>(PagePhase.emptyState);

  List<LinkData>? allValidatedLinkDatas;
  final displayLinkDatasNotifier = ValueNotifier<List<LinkData>?>(null);
  final generatedAssetLinksForSelectedLink = ValueNotifier<GenerateAssetLinksResult?>(null);

  final displayOptionsNotifier =
      ValueNotifier<DisplayOptions>(DisplayOptions());

  /// The [TextEditingController] for the search text field.
  final textEditingController = TextEditingController();
  final deepLinksServices = DeepLinksServices();

  Future<void> _generateAssetLinks() async {
    generatedAssetLinksForSelectedLink.value =
        await deepLinksServices.generateAssetLinks(
      domain: selectedLink.value!.domain,
      applicationId: applicationId,
    );
  }

  Future<List<LinkData>> _validateAndroidDomain() async {
    final List<LinkData> linkdatas = _allRawLinkDatas;
    if (linkdatas.isEmpty) {
      pagePhase.value = PagePhase.noLinks;
      return const <LinkData>[];
    }
    final domains = linkdatas
        .where((linkdata) => linkdata.os.contains(PlatformOS.android))
        .map((linkdata) => linkdata.domain)
        .toSet()
        .toList();

    late final Map<String, List<DomainError>> domainErrors;

    try {
      domainErrors = await deepLinksServices.validateAndroidDomain(
        domains: domains,
        applicationId: applicationId,
      );
    } catch (e) {
      //TODO(hangyujin): Add more error handling for cases like RPC error and invalid json.
      pagePhase.value = PagePhase.errorPage;
      return linkdatas;
    }

    return linkdatas.map((linkdata) {
      if (domainErrors[linkdata.domain]?.isNotEmpty ?? false) {
        return LinkData(
          domain: linkdata.domain,
          domainErrors: domainErrors[linkdata.domain]!,
          path: linkdata.path,
          pathError: linkdata.pathError,
          os: linkdata.os,
          scheme: linkdata.scheme,
          associatedDomains: linkdata.associatedDomains,
          associatedPath: linkdata.associatedPath,
        );
      }
      return linkdata;
    }).toList();
  }

  Future<void> validateLinks() async {
    pagePhase.value = PagePhase.linksValidating;
    allValidatedLinkDatas = await _validateAndroidDomain();
    if (pagePhase.value == PagePhase.linksValidating) {
      pagePhase.value = PagePhase.linksValidated;
    }
    displayLinkDatasNotifier.value = getFilterredLinks(allValidatedLinkDatas!);

    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount: getLinkDatasByDomain
          .where((element) => element.domainErrors.isNotEmpty)
          .length,
      pathErrorCount:
          getLinkDatasByPath.where((element) => element.pathError).length,
    );
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
    displayLinkDatasNotifier.value = getFilterredLinks(allValidatedLinkDatas!);
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

    displayLinkDatasNotifier.value = getFilterredLinks(allValidatedLinkDatas!);
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
          (linkData.pathError &&
              displayOptions.filters.contains(FilterOption.failedPathCheck)) ||
          (!linkData.domainErrors.isNotEmpty &&
              !linkData.pathError &&
              displayOptions.filters.contains(FilterOption.noIssue)))) {
        return false;
      }

      return true;
    }).toList();

    return linkDatas;
  }
}
