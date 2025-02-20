// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:math';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/analytics/metrics.dart';
import '../../shared/feature_flags.dart';
import '../../shared/framework/screen_controllers.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/server/server.dart' as server;
import 'deep_link_list_view.dart';
import 'deep_links_model.dart';
import 'deep_links_services.dart';

typedef _DomainAndPath = ({String? domain, String? path});
const _defaultSchemes = {'http', 'https'};

const domainAssetLinksJsonFileErrors = {
  AndroidDomainError.existence,
  AndroidDomainError.appIdentifier,
  AndroidDomainError.fingerprints,
};
const domainAndroidHostingErrors = {
  AndroidDomainError.contentType,
  AndroidDomainError.httpsAccessibility,
  AndroidDomainError.nonRedirect,
  AndroidDomainError.hostForm,
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
  // Error when analyzing the Flutter project.
  analyzeErrorPage,
  // Error when validating domains.
  validationErrorPage,
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

class DeepLinksController extends DevToolsScreenController
    with AutoDisposeControllerMixin {
  @override
  void dispose() {
    deepLinksService.dispose();
    super.dispose();
  }

  DisplayOptions get displayOptions => displayOptionsNotifier.value;
  String get applicationId =>
      androidAppLinks[selectedAndroidVariantIndex.value]?.applicationId ?? '';
  String get bundleId =>
      iosLinks[selectedIosConfigurationIndex.value]?.bundleIdentifier ?? '';
  String get teamId =>
      iosLinks[selectedIosConfigurationIndex.value]?.teamIdentifier ?? '';

  @visibleForTesting
  List<LinkData> linkDatasByPath(List<LinkData> linkdatas) {
    final linkDatasByPath = <String, LinkData>{};
    for (final linkData in linkdatas) {
      final path = linkData.path;
      if (path == null) {
        continue;
      }
      final previousRecord = linkDatasByPath[path.path];

      linkDatasByPath[path.path] = LinkData(
        domain: linkData.domain,
        path: linkData.path,
        scheme: linkData.scheme.union(previousRecord?.scheme ?? {}),
        os: {if (previousRecord != null) ...previousRecord.os, ...linkData.os},
        associatedDomains: [
          ...previousRecord?.associatedDomains ?? [],
          if (linkData.domain != null) linkData.domain!,
        ],
        pathErrors: linkData.pathErrors,
      );
    }

    return getFilterredLinks(linkDatasByPath.values.toList());
  }

  @visibleForTesting
  List<LinkData> linkDatasByDomain(List<LinkData> linkdatas) {
    final linkDatasByDomain = <String, LinkData>{};
    for (final linkData in linkdatas) {
      if (linkData.domain.isNullOrEmpty) {
        continue;
      }
      final previousRecord = linkDatasByDomain[linkData.domain];
      linkDatasByDomain[linkData.domain!] = LinkData(
        domain: linkData.domain,
        path: linkData.path,
        scheme: linkData.scheme.union(previousRecord?.scheme ?? {}),
        os: {if (previousRecord != null) ...previousRecord.os, ...linkData.os},
        associatedPath: [
          ...previousRecord?.associatedPath ?? [],
          if (linkData.path != null && !linkData.path!.isExcluded)
            linkData.path!.path,
        ],
        domainErrors: linkData.domainErrors,
        hasAndroidAssetLinksFile: linkData.hasAndroidAssetLinksFile,
        hasIosAasaFile: linkData.hasIosAasaFile,
      );
    }
    return getFilterredLinks(linkDatasByDomain.values.toList());
  }

  AppLinkSettings? get currentAppLinkSettings =>
      androidAppLinks[selectedAndroidVariantIndex.value];
  UniversalLinkSettings? get currentUniversalLinkSettings =>
      iosLinks[selectedIosConfigurationIndex.value];
  @visibleForTesting
  final androidAppLinks = <int, AppLinkSettings>{};

  @visibleForTesting
  final iosLinks = <int, UniversalLinkSettings>{};

  ValueListenable<int> get selectedAndroidVariantIndex =>
      _selectedAndroidVariantIndex;
  final _selectedAndroidVariantIndex = ValueNotifier<int>(0);

  ValueListenable<int> get selectedIosConfigurationIndex =>
      _selectedIosConfigurationIndex;
  final _selectedIosConfigurationIndex = ValueNotifier<int>(0);

  ValueListenable<int> get selectedIosTargetIndex => _selectedIosTargetIndex;
  final _selectedIosTargetIndex = ValueNotifier<int>(0);

  void updateSelectedAndroidVariantIndex(int index) {
    _selectedAndroidVariantIndex.value = index;
    _handleAndroidConfigurationChanged();
  }

  void updateSelectedIosConfigurationIndex(int index) {
    _selectedIosConfigurationIndex.value = index;
    _handleIosConfigurationChanged();
  }

  void updateSelectedIosTargetIndex(int index) {
    _selectedIosTargetIndex.value = index;
    _handleIosConfigurationChanged();
  }

  void firstLoadWithDefaultConfigurations() async {
    _selectedAndroidVariantIndex.value = _getDefaultConfigurationIndex(
      selectedProject.value!.androidVariants,
      containsString: 'release',
    );
    if (FeatureFlags.deepLinkIosCheck) {
      _selectedIosConfigurationIndex.value = _getDefaultConfigurationIndex(
        selectedProject.value!.iosBuildOptions.configurations,
        containsString: 'release',
      );
      _selectedIosTargetIndex.value = _getDefaultConfigurationIndex(
        selectedProject.value!.iosBuildOptions.configurations,
        containsString: 'runner',
      );
    }
    await loadLinksAndValidate();
  }

  void _handleAndroidConfigurationChanged() async {
    pagePhase.value = PagePhase.linksLoading;
    await _loadAndroidAppLinks();
    if (pagePhase.value == PagePhase.validationErrorPage) {
      return;
    }
    await validateLinks();
  }

  void _handleIosConfigurationChanged() async {
    pagePhase.value = PagePhase.linksLoading;
    await _loadIosLinks();
    if (pagePhase.value == PagePhase.validationErrorPage) {
      return;
    }
    await validateLinks();
  }

  int _getDefaultConfigurationIndex(
    List<String> configurations, {
    required String containsString,
  }) {
    final index = configurations.indexWhere(
      (config) => config.caseInsensitiveContains(containsString),
    );
    // If not found, default to 0.
    return max(index, 0);
  }

  Future<void> _loadAndroidAppLinks() async {
    if (selectedProject.value!.androidVariants.isEmpty) {
      return;
    }
    final variant =
        selectedProject.value!.androidVariants[selectedAndroidVariantIndex
            .value];
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
          androidAppLinks[selectedAndroidVariantIndex.value] = result;
          ga.impression(
            gac.deeplink,
            gac.AnalyzeFlutterProject.androidAppLinksSettingsLoaded.name,
            screenMetricsProvider:
                () => DeepLinkScreenMetrics(androidAppId: result.applicationId),
          );
        } catch (_) {
          ga.select(
            gac.deeplink,
            gac.AnalyzeFlutterProject.flutterAppLinkLoadingError.name,
          );
          pagePhase.value = PagePhase.validationErrorPage;
        }
      },
    );
  }

  Future<void> _loadIosLinks() async {
    final iosBuildOptions = selectedProject.value!.iosBuildOptions;
    if (iosBuildOptions.configurations.isEmpty) {
      return;
    }
    final configuration =
        iosBuildOptions.configurations[selectedIosConfigurationIndex.value];
    final target = iosBuildOptions.targets[selectedIosTargetIndex.value];
    await ga.timeAsync(
      gac.deeplink,
      gac.AnalyzeFlutterProject.loadIosLinks.name,
      asyncOperation: () async {
        final UniversalLinkSettings result;
        try {
          result = await server.requestIosUniversalLinkSettings(
            selectedProject.value!.path,
            configuration: configuration,
            target: target,
          );
          iosLinks[selectedIosConfigurationIndex.value] = result;
          ga.impression(
            gac.deeplink,
            gac.AnalyzeFlutterProject.iosUniversalLinkSettingsLoaded.name,
            screenMetricsProvider:
                () =>
                    DeepLinkScreenMetrics(iosBundleId: result.bundleIdentifier),
          );
        } catch (_) {
          pagePhase.value = PagePhase.validationErrorPage;
        }
      },
    );
  }

  Future<void> loadLinksAndValidate() async {
    pagePhase.value = PagePhase.linksLoading;
    await _loadAndroidAppLinks();
    if (pagePhase.value == PagePhase.validationErrorPage) {
      return;
    }
    if (FeatureFlags.deepLinkIosCheck) {
      await _loadIosLinks();
      if (pagePhase.value == PagePhase.validationErrorPage) {
        return;
      }
    }
    await validateLinks();
  }

  Future<String?> packageDirectoryForMainIsolate() async {
    if (!serviceConnection.serviceManager.connectedState.value.connected) {
      return null;
    }
    final packageUriString = await serviceConnection.serviceManager
        .rootPackageDirectoryForMainIsolate(dtdManager);
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
  List<LinkData> get _rawAndroidLinkDatas {
    final appLinksSettings = androidAppLinks[selectedAndroidVariantIndex.value];
    if (appLinksSettings == null) {
      return const <LinkData>[];
    }
    final appLinks = appLinksSettings.deeplinks;

    final domainPathToLinkData = <_DomainAndPath, LinkData>{};
    for (final appLink in appLinks) {
      final domainAndPath = (domain: appLink.host, path: appLink.path);
      final scheme = appLink.scheme;

      if (domainPathToLinkData[domainAndPath] == null) {
        domainPathToLinkData[domainAndPath] = LinkData(
          domain: appLink.host,
          path: Path(path: appLink.path),
          pathErrors: _getPathErrorsFromIntentFilterChecks(
            appLink.intentFilterChecks,
          ),
          os: {PlatformOS.android},
          scheme: {if (scheme != null) scheme},
        );
      } else {
        final linkData = domainPathToLinkData[domainAndPath]!;
        if (scheme != null) {
          linkData.scheme.add(scheme);
        }
        final pathErrors = {
          ...linkData.pathErrors,
          if (!appLinksSettings.deeplinkingFlagEnabled)
            PathError.missingDeepLinkingFlag,
          ..._getPathErrorsFromIntentFilterChecks(appLink.intentFilterChecks),
        };

        linkData.pathErrors = pathErrors;
      }
    }

    return domainPathToLinkData.values.toList();
  }

  List<LinkData> get _rawIosLinkDatas {
    final iosDomains =
        iosLinks[selectedIosConfigurationIndex.value]?.associatedDomains ?? [];
    return iosDomains
        .map(
          (domain) => LinkData(
            domain: domain,
            path: null,
            scheme: _defaultSchemes,
            os: {PlatformOS.ios},
          ),
        )
        .toList();
  }

  final selectedProject = ValueNotifier<FlutterProject?>(null);
  final googlePlayFingerprintsAvailability = ValueNotifier<bool>(false);
  final localFingerprint = ValueNotifier<String?>(null);
  final selectedLink = ValueNotifier<LinkData?>(null);
  final pagePhase = ValueNotifier<PagePhase>(PagePhase.emptyState);

  /// These are all link datas before applying displayOptions.
  var validatedLinkDatas = ValidatedLinkDatas.empty();

  /// These are link datas actually displayed in the data table after filtering by displayOptions.
  final displayLinkDatasNotifier = ValueNotifier<ValidatedLinkDatas>(
    ValidatedLinkDatas.empty(),
  );

  final generatedAssetLinksForSelectedLink =
      ValueNotifier<GenerateAssetLinksResult?>(null);

  final displayOptionsNotifier = ValueNotifier<DisplayOptions>(
    DisplayOptions(),
  );

  /// The [TextEditingController] for the search text field.
  final textEditingController = TextEditingController();
  final deepLinksService = DeepLinksService();

  bool addLocalFingerprint(String fingerprint) {
    // A valid fingerprint consists of 32 pairs of hexadecimal digits separated by colons.
    bool isValidFingerprint(String input) {
      final pattern = RegExp(
        r'^([0-9a-f]{2}:){31}[0-9a-f]{2}$',
        caseSensitive: false,
      );
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
    final domain = selectedLink.value!.domain;
    if (domain != null) {
      generatedAssetLinksForSelectedLink.value = await deepLinksService
          .generateAssetLinks(
            domain: domain,
            applicationId: applicationId,
            localFingerprint: localFingerprint.value,
          );
    }
  }

  Future<List<LinkData>> _validateDomain(List<LinkData> rawLinkdatas) async {
    final domains =
        rawLinkdatas
            .where((linkdata) => linkdata.domain != null)
            .map((linkdata) => linkdata.domain!)
            .toSet()
            .toList();

    Map<String, List<DomainError>> androidDomainErrors = {};
    Map<String, List<DomainError>> iosDomainErrors = {};
    Map<String, List<Path>> iosDomainPaths = {};
    try {
      if (currentAppLinkSettings != null) {
        ga.impression(
          gac.deeplink,
          gac.AnalyzeFlutterProject.androidValidateDomain.name,
          screenMetricsProvider:
              () => DeepLinkScreenMetrics(
                androidAppId: currentAppLinkSettings!.applicationId,
              ),
        );
        final androidResult = await deepLinksService.validateAndroidDomain(
          domains: domains,
          applicationId: applicationId,
          localFingerprint: localFingerprint.value,
        );
        androidDomainErrors = androidResult.domainErrors;
        googlePlayFingerprintsAvailability.value =
            androidResult.googlePlayFingerprintsAvailability;
      }
      if (FeatureFlags.deepLinkIosCheck &&
          currentUniversalLinkSettings != null) {
        ga.impression(
          gac.deeplink,
          gac.AnalyzeFlutterProject.iosValidateDomain.name,
          screenMetricsProvider:
              () => DeepLinkScreenMetrics(
                iosBundleId: currentUniversalLinkSettings!.bundleIdentifier,
              ),
        );
        final iosResult = await deepLinksService.validateIosDomain(
          bundleId: bundleId,
          teamId: teamId,
          domains: domains,
        );
        iosDomainErrors = iosResult.domainErrors;
        iosDomainPaths = iosResult.paths;
      }
    } catch (_) {
      // TODO(hangyujin): Add more error handling for cases like RPC error and invalid json.
      pagePhase.value = PagePhase.validationErrorPage;
      return rawLinkdatas;
    }

    final validatedLinkDatas = <LinkData>[];

    for (final linkdata in rawLinkdatas) {
      final errors = <DomainError>[
        if (linkdata.os.contains(PlatformOS.android))
          ...(androidDomainErrors[linkdata.domain] ?? []),
        if (linkdata.os.contains(PlatformOS.ios))
          ...(iosDomainErrors[linkdata.domain] ?? []),
      ];
      final hasAndroidAssetLinksFile =
          !(androidDomainErrors[linkdata.domain]?.contains(
                AndroidDomainError.existence,
              ) ??
              false);
      final hasIosAasaFile =
          !(iosDomainErrors[linkdata.domain]?.contains(
                IosDomainError.existence,
              ) ??
              false);

      if (linkdata.os.contains(PlatformOS.ios)) {
        final iosPaths = iosDomainPaths[linkdata.domain] ?? <Path>[];

        // If no path is provided, we will still show the domain just with domain errors.
        if (iosPaths.isEmpty) {
          validatedLinkDatas.add(
            linkdata.copyWith(
              domainErrors: errors,
              hasAndroidAssetLinksFile: hasAndroidAssetLinksFile,
              hasIosAasaFile: hasIosAasaFile,
            ),
          );
        } else {
          // If there are multiple paths for the same domain, we will show the domain with each path.
          for (final iosPath in iosPaths) {
            validatedLinkDatas.add(
              linkdata.copyWith(
                path: iosPath,
                domainErrors: errors,
                hasAndroidAssetLinksFile: hasAndroidAssetLinksFile,
                hasIosAasaFile: hasIosAasaFile,
              ),
            );
          }
        }
      }

      if (linkdata.os.contains(PlatformOS.android)) {
        validatedLinkDatas.add(
          linkdata.copyWith(
            domainErrors: errors,
            hasAndroidAssetLinksFile: hasAndroidAssetLinksFile,
            hasIosAasaFile: hasIosAasaFile,
          ),
        );
      }
    }
    return validatedLinkDatas;
  }

  Future<List<LinkData>> _validatePath(List<LinkData> linkdatas) async {
    for (final linkData in linkdatas) {
      final path = linkData.path?.path;
      if (path == null) {
        continue;
      }
      if (!(path.startsWith('/') || path == '.*')) {
        linkData.pathErrors.add(PathError.pathFormat);
      }
    }
    return linkdatas;
  }

  Future<void> validateLinks() async {
    final appLinkSettings = currentAppLinkSettings;
    if (appLinkSettings?.error != null) {
      pagePhase.value = PagePhase.analyzeErrorPage;
      ga.select(
        gac.deeplink,
        gac.AnalyzeFlutterProject.flutterAppLinkLoadingError.name,
      );
      return;
    }
    pagePhase.value = PagePhase.linksValidating;
    List<LinkData> linkdata = [
      ..._rawAndroidLinkDatas,
      if (FeatureFlags.deepLinkIosCheck) ..._rawIosLinkDatas,
    ];
    if (linkdata.isEmpty) {
      ga.select(gac.deeplink, gac.AnalyzeFlutterProject.flutterNoAppLink.name);
      pagePhase.value = PagePhase.noLinks;
      return;
    }

    // There are deep links to validate.
    ga.select(gac.deeplink, gac.AnalyzeFlutterProject.flutterHasAppLinks.name);
    linkdata = await _validateDomain(linkdata);
    if (pagePhase.value == PagePhase.validationErrorPage) {
      return;
    }
    linkdata = await _validatePath(linkdata);

    if (pagePhase.value == PagePhase.validationErrorPage) {
      return;
    }

    validatedLinkDatas = ValidatedLinkDatas(
      all: linkdata,
      byDomain: linkDatasByDomain(linkdata),
      byPath: linkDatasByPath(linkdata),
    );
    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      domainErrorCount:
          validatedLinkDatas.byDomain
              .where((element) => element.domainErrors.isNotEmpty)
              .length,
      pathErrorCount:
          validatedLinkDatas.byPath
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

  void autoSelectLink(TableViewType viewType) {
    final linkDatas = displayLinkDatasNotifier.value;
    late final LinkData linkdata;
    switch (viewType) {
      case TableViewType.domainView:
        linkdata =
            linkDatas.byDomain
                .where((e) => e.domainErrors.isNotEmpty)
                .firstOrNull ??
            linkDatas.byDomain.first;
      case TableViewType.pathView:
        linkdata =
            linkDatas.byPath
                .where((e) => e.pathErrors.isNotEmpty)
                .firstOrNull ??
            linkDatas.byPath.first;
      case TableViewType.singleUrlView:
        linkdata =
            linkDatas.all
                .where(
                  (e) => e.domainErrors.isNotEmpty || e.pathErrors.isNotEmpty,
                )
                .firstOrNull ??
            linkDatas.all.first;
    }
    selectLink(linkdata);
  }

  set searchContent(String content) {
    displayOptionsNotifier.value = displayOptionsNotifier.value.copyWith(
      searchContent: content,
    );
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
      displayOptionsNotifier.value = displayOptionsNotifier.value.updateFilter(
        addedFilter,
        true,
      );
    }
    if (removedFilter != null) {
      displayOptionsNotifier.value = displayOptionsNotifier.value.updateFilter(
        removedFilter,
        false,
      );
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
    final searchContent = displayOptions.searchContent;
    linkDatas =
        linkDatas.where((linkData) {
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
                  displayOptions.filters.contains(
                    FilterOption.failedDomainCheck,
                  )) ||
              (linkData.pathErrors.isNotEmpty &&
                  displayOptions.filters.contains(
                    FilterOption.failedPathCheck,
                  )) ||
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
