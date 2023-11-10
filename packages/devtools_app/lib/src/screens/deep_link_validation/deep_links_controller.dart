// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/config_specific/server/server.dart' as server;
import 'deep_links_model.dart';

const String _apiKey = 'AIzaSyDVE6FP3GpwxgS4q8rbS7qaf6cAbxc_elc';
const String _assetLinksGenerationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/generation/v1/assetlinks:generate?key=$_apiKey';
const String _androidDomainValidationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/validation/v1/domains:batchValidate?key=$_apiKey';
const postHeader = {'Content-Type': 'application/json'};
const String _packageNameKey = 'package_name';
const String _domainsKey = 'domains';
const String _appLinkDomainsKey = 'app_link_domains';
const String _validationResultKey = 'validationResult';
const String _domainNameKey = 'domainName';
const String _checkNameKey = 'checkName';
const String _failedChecksKey = 'failedChecks';
const String _generatedContentKey = 'generatedContent';

typedef _DomainAndPath = ({String domain, String path});

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

  List<LinkData> get getLinkDatasByPath {
    final linkDatasByPath = <String, LinkData>{};
    for (var linkData in allLinkDatasNotifier.value!) {
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

    return _getFilterredLinks(linkDatasByPath.values.toList());
  }

  List<LinkData> get getLinkDatasByDomain {
    final linkDatasByDomain = <String, LinkData>{};

    for (var linkData in allLinkDatasNotifier.value!) {
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
    return _getFilterredLinks(linkDatasByDomain.values.toList());
  }

  final Map<int, AppLinkSettings> _androidAppLinks = <int, AppLinkSettings>{};

  late final selectedVariantIndex = ValueNotifier<int>(0);
  void _handleSelectedVariantIndexChanged() {
    unawaited(_loadAndroidAppLinks());
  }

  Future<void> _loadAndroidAppLinks() async {
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

  List<LinkData> get _allLinkDatas {
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

  final allLinkDatasNotifier = ValueNotifier<List<LinkData>?>(null);
  final displayLinkDatasNotifier = ValueNotifier<List<LinkData>?>(null);
  final generatedAssetLinksForSelectedLink = ValueNotifier<String?>(null);

  final displayOptionsNotifier =
      ValueNotifier<DisplayOptions>(DisplayOptions());

  /// The [TextEditingController] for the search text field.
  final textEditingController = TextEditingController();

  Future<void> _generateAssetLinks() async {
    final applicationId =
        _androidAppLinks[selectedVariantIndex.value]?.applicationId ?? '';

    final response = await http.post(
      Uri.parse(_assetLinksGenerationURL),
      headers: postHeader,
      body: jsonEncode(
        {
          _packageNameKey: applicationId,
          _domainsKey: [selectedLink.value!.domain],
          // TODO(hangyujin): The fake fingerprints here is just for testing usage, should remove it later.
          // TODO(hangyujin): Handle the error case when user doesn't have play console project set up.
          'supplemental_sha256_cert_fingerprints': [
            '5A:33:EA:64:09:97:F2:F0:24:21:0F:B6:7A:A8:18:1C:18:A9:83:03:20:21:8F:9B:0B:98:BF:43:69:C2:AF:4A',
          ],
        },
      ),
    );

    final Map<String, dynamic> result =
        json.decode(response.body) as Map<String, dynamic>;
    if (result[_domainsKey] != null) {
      final String generatedContent = ((result[_domainsKey] as List).first
          as Map<String, dynamic>)[_generatedContentKey];

      generatedAssetLinksForSelectedLink.value = generatedContent;
    }
  }

  Future<List<LinkData>> _validateAndroidDomain() async {
    final List<LinkData> linkdatas = _allLinkDatas;
    final domains = linkdatas
        .where((linkdata) => linkdata.os.contains(PlatformOS.android))
        .map((linkdata) => linkdata.domain)
        .toSet()
        .toList();

    final applicationId =
        _androidAppLinks[selectedVariantIndex.value]?.applicationId ?? '';

    final response = await http.post(
      Uri.parse(_androidDomainValidationURL),
      headers: postHeader,
      body: jsonEncode({
        _packageNameKey: applicationId,
        _appLinkDomainsKey: domains,
      }),
    );

    final Map<String, dynamic> result =
        json.decode(response.body) as Map<String, dynamic>;

    final Map<String, List<DomainError>> domainErrors = {
      for (var domain in domains) domain: <DomainError>[],
    };

    final validationResult = result[_validationResultKey] as List;
    for (final Map<String, dynamic> domainResult in validationResult) {
      final String domainName = domainResult[_domainNameKey];
      final List? failedChecks = domainResult[_failedChecksKey];
      if (failedChecks != null) {
        for (final Map<String, dynamic> failedCheck in failedChecks) {
          switch (failedCheck[_checkNameKey]) {
            case 'EXISTENCE':
              domainErrors[domainName]!.add(DomainError.existence);
            case 'FINGERPRINT':
              domainErrors[domainName]!.add(DomainError.fingerprints);
          }
        }
      }
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
    allLinkDatasNotifier.value = await _validateAndroidDomain();
    displayLinkDatasNotifier.value =
        _getFilterredLinks(allLinkDatasNotifier.value!);

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
    displayLinkDatasNotifier.value =
        _getFilterredLinks(allLinkDatasNotifier.value!);
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

    displayLinkDatasNotifier.value =
        _getFilterredLinks(allLinkDatasNotifier.value!);
  }

  List<LinkData> _getFilterredLinks(List<LinkData> linkDatas) {
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
