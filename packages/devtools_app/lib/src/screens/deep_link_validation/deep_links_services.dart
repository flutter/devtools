// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart';

import '../../shared/primitives/utils.dart';
import 'deep_links_model.dart';

const _apiKey = 'AIzaSyCf_2E9N2AUZR-YSnZTQ72YbCNhKIskIsw';

@visibleForTesting
const assetLinksGenerationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/generation/v1/assetlinks:generate?key=$_apiKey';
@visibleForTesting
const androidDomainValidationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/validation/v1/domains:batchValidate?key=$_apiKey';
@visibleForTesting
const iosDomainValidationURL =
    'https://deeplinkassistant-pa.googleapis.com/ios/validation/v1/domains:batchValidate?key=$_apiKey';
const postHeader = {'Content-Type': 'application/json'};

// The keys used in both android and ios domain validation API.
const _domainNameKey = 'domainName';
const _checkNameKey = 'checkName';
const _severityLevelKey = 'severityLevel';
const _severityLevelError = 'ERROR';
const _failedChecksKey = 'failedChecks';
const _subCheckResultsKey = 'subCheckResults';
const _resultTypeKey = 'resultType';
const _passedKey = 'PASSED';
const _domainBatchSize = 500;

// The keys for the Android domain validation API.
const _packageNameKey = 'package_name';
const _domainsKey = 'domains';
const _errorCodeKey = 'errorCode';
const _appLinkDomainsKey = 'app_link_domains';
const _fingerprintsKey = 'supplemental_sha256_cert_fingerprints';
const _googlePlayFingerprintsAvailabilityKey =
    'googlePlayFingerprintsAvailability';
const _googlePlayFingerprintsAvailableValue = 'FINGERPRINTS_AVAILABLE';
const _generatedContentKey = 'generatedContent';
const _androidValidationResultKey = 'validationResult';

const androidCheckNameToDomainError = <String, DomainError>{
  'EXISTENCE': AndroidDomainError.existence,
  'APP_IDENTIFIER': AndroidDomainError.appIdentifier,
  'FINGERPRINT': AndroidDomainError.fingerprints,
  'CONTENT_TYPE': AndroidDomainError.contentType,
  'HTTPS_ACCESSIBILITY': AndroidDomainError.httpsAccessibility,
  'NON_REDIRECT': AndroidDomainError.nonRedirect,
  'HOST_FORMED_PROPERLY': AndroidDomainError.hostForm,
  'OTHER_CHECKS': AndroidDomainError.other,
};

// The keys for the iOS domain validation API.
const _appIdKey = 'aasa_app_id';
const _bundleIdKey = 'bundle_id';
const _teamIdKey = 'team_id';
const _universalLinkDomainsKey = 'universal_link_domains';
const _iosDomainNameKey = 'domain_name';
const _iosValidationResultsKey = 'validationResults';
const _aasaAppPathsKey = 'aasaAppPaths';
const _aasaPathsKey = 'aasaPaths';
const _pathKey = 'path';
const _isExcludedKey = 'isExcluded';
const _queryParamsKey = 'queryParams';
const _keyKey = 'key';
const _valueKey = 'value';

const _fileFormatKey = 'FILE_FORMAT';
final iosCheckNameToDomainError = <String, DomainError>{
  'EXISTENCE': IosDomainError.existence,
  'APP_IDENTIFIER': IosDomainError.appIdentifier,
  'HTTPS_ACCESSIBILITY': IosDomainError.httpsAccessibility,
  'NON_REDIRECT': IosDomainError.nonRedirect,
};
final aasaFileFormatSubCheck = {
  'APPLINKS_FORMAT': AASAfileFormatSubCheck.appLinksFormat,
  'APPLINKS_SUBSTITUTION_VARIABLES_FORMAT':
      AASAfileFormatSubCheck.appLinksSubstitutionVariablesFormat,
  'DEFAULTS_FORMAT': AASAfileFormatSubCheck.defaultsFormat,
  'DEFAULTS_PERCENT_ENCODED_FORMAT':
      AASAfileFormatSubCheck.defaultsPercentEncodedFormat,
  'DETAIL_FORMAT': AASAfileFormatSubCheck.detailsFormat,
  'DETAIL_APP_ID_FORMAT': AASAfileFormatSubCheck.detailsAppIdFormat,
  'DETAIL_PATHS_FORMAT': AASAfileFormatSubCheck.detailsPathsFormat,
  'DETAIL_DEFAULTS_FORMAT': AASAfileFormatSubCheck.detailsDefaultsFormat,
  'DETAIL_DEFAULTS_PERCENT_ENCODED_FORMAT':
      AASAfileFormatSubCheck.detailsDefaultsPercentEncodedFormat,
  'DETAIL_DEFAULTS_CASE_SENSITIVE_FORMAT ':
      AASAfileFormatSubCheck.detailsDefaultsCaseSensitiveFormat,
  'COMPONENT_FORMAT': AASAfileFormatSubCheck.componentFormat,
  'COMPONENT_PATH_FORMAT': AASAfileFormatSubCheck.componentPathFormat,
  'COMPONENT_QUERY_FORMAT': AASAfileFormatSubCheck.componentQueryFormat,
  'COMPONENT_FRAGMENT_FORMAT': AASAfileFormatSubCheck.componentFragmentFormat,
  'COMPONENT_EXCLUDE_FORMAT': AASAfileFormatSubCheck.componentExcludeFormat,
  'COMPONENT_PERCENT_ENCODED_FORMAT':
      AASAfileFormatSubCheck.componentPercentEncodedFormat,
  'COMPONENT_CASE_SENSITIVE_FORMAT':
      AASAfileFormatSubCheck.componentCaseSensitiveFormat,
  'COMPONENT_COMMENT_FORMAT': AASAfileFormatSubCheck.componentCommentFormat,
};

class ValidateIosDomainResult {
  ValidateIosDomainResult(this.errorCode, this.domainErrors, this.paths);
  final String errorCode;
  final Map<String, List<DomainError>> domainErrors;
  final Map<String, List<Path>> paths;
}

class GenerateAssetLinksResult {
  GenerateAssetLinksResult(this.errorCode, this.generatedString);
  final String errorCode;
  final String generatedString;
}

class ValidateAndroidDomainResult {
  ValidateAndroidDomainResult(
    this.googlePlayFingerprintsAvailability,
    this.domainErrors,
  );
  bool googlePlayFingerprintsAvailability;
  Map<String, List<DomainError>> domainErrors;
}

class DeepLinksService {
  final client = Client();

  void dispose() {
    client.close();
  }

  Future<ValidateAndroidDomainResult> validateAndroidDomain({
    required List<String> domains,
    required String applicationId,
    required String? localFingerprint,
  }) async {
    final domainErrors = <String, List<DomainError>>{
      for (final domain in domains) domain: <DomainError>[],
    };

    final domainsByBatch = _splitDomains(domains);
    late bool googlePlayFingerprintsAvailable;

    for (final domainList in domainsByBatch) {
      final response = await client.post(
        Uri.parse(androidDomainValidationURL),
        headers: postHeader,
        body: jsonEncode({
          _packageNameKey: applicationId,
          _appLinkDomainsKey: domainList,
          if (localFingerprint != null) _fingerprintsKey: [localFingerprint],
        }),
      );

      final result = json.decode(response.body) as Map<String, Object?>;

      final validationResult =
          (result[_androidValidationResultKey] as List)
              .cast<Map<String, Object?>>();
      googlePlayFingerprintsAvailable =
          result[_googlePlayFingerprintsAvailabilityKey] ==
          _googlePlayFingerprintsAvailableValue;
      for (final domainResult in validationResult) {
        final domainName = domainResult[_domainNameKey] as String;
        final failedChecks =
            (domainResult[_failedChecksKey] as List?)
                ?.cast<Map<String, Object?>>();
        if (failedChecks != null) {
          for (final failedCheck in failedChecks) {
            final checkName = failedCheck[_checkNameKey] as String;
            final domainError = androidCheckNameToDomainError[checkName];
            if (domainError != null) {
              domainErrors[domainName]!.add(domainError);
            }
          }
        }
      }
    }

    return ValidateAndroidDomainResult(
      googlePlayFingerprintsAvailable,
      domainErrors,
    );
  }

  Future<ValidateIosDomainResult> validateIosDomain({
    required String bundleId,
    required String teamId,
    required List<String> domains,
  }) async {
    final domainErrors = <String, List<DomainError>>{};
    final paths = <String, List<Path>>{};
    // TODO(hangyujin): Add error code to the result.
    const errorCode = '';

    final domainsByBatch = _splitDomains(domains);

    for (final domainList in domainsByBatch) {
      final response = await client.post(
        Uri.parse(iosDomainValidationURL),
        headers: postHeader,
        body: jsonEncode({
          _appIdKey: {_bundleIdKey: bundleId, _teamIdKey: teamId},
          _universalLinkDomainsKey: [
            for (final domain in domainList) {_iosDomainNameKey: domain},
          ],
        }),
      );
      final result = json.decode(response.body) as Map<String, Object?>;
      final validationResult =
          (result[_iosValidationResultsKey] as List)
              .cast<Map<String, Object?>>();

      for (final domainResult in validationResult) {
        if (domainResult[_domainNameKey] case final String domainName) {
          final failedChecks =
              (domainResult[_failedChecksKey] as List?)
                  ?.cast<Map<String, Object?>>();
          if (failedChecks != null) {
            for (final failedCheck in failedChecks) {
              final checkName = failedCheck[_checkNameKey] as String;
              final domainError = iosCheckNameToDomainError[checkName];
              final severityLevel = failedCheck[_severityLevelKey] as String;
              if (severityLevel == _severityLevelError) {
                if (checkName == _fileFormatKey) {
                  final failedAasaFileFormatSubCheck =
                      <AASAfileFormatSubCheck>[];

                  // Adds sub checks for file format error.
                  final subChecks =
                      (failedCheck[_subCheckResultsKey] as List?)
                          ?.cast<Map<String, Object?>>();
                  for (final subCheck in (subChecks ?? <Map>[])) {
                    final subCheckName = subCheck[_checkNameKey] as String;
                    final subCheckResultType =
                        subCheck[_resultTypeKey] as String;
                    if (subCheckResultType != _passedKey) {
                      failedAasaFileFormatSubCheck.add(
                        aasaFileFormatSubCheck[subCheckName]!,
                      );
                    }
                  }

                  domainErrors
                      .putIfAbsent(domainName, () => <DomainError>[])
                      .add(
                        IosDomainError.iosFileFormatDomainError(
                          subcheckErrors: failedAasaFileFormatSubCheck,
                        ),
                      );
                } else if (domainError != null) {
                  domainErrors
                      .putIfAbsent(domainName, () => <DomainError>[])
                      .add(domainError);
                }
              }
            }
          }

          final aasaAppPaths =
              (domainResult[_aasaAppPathsKey] as List?)
                  ?.cast<Map<String, Object?>>();
          if (aasaAppPaths != null) {
            for (final aasaAppPath in aasaAppPaths) {
              final aasaPaths =
                  (aasaAppPath[_aasaPathsKey] as List?)
                      ?.cast<Map<String, Object?>>();
              if (aasaPaths != null) {
                for (final aasaPath in aasaPaths) {
                  final path = aasaPath[_pathKey] as String?;
                  if (path.isNullOrEmpty) {
                    continue;
                  }
                  final rawQueryParams =
                      (aasaPath[_queryParamsKey] as List?)
                          ?.cast<Map<String, Object?>>();
                  final queryParams = <String, String>{
                    for (final item in rawQueryParams ?? <Map>[])
                      item[_keyKey] as String: item[_valueKey] as String,
                  };
                  paths
                      .putIfAbsent(domainName, () => <Path>[])
                      .add(
                        Path(
                          path: path!,
                          queryParams: queryParams,
                          isExcluded:
                              aasaPath[_isExcludedKey] as bool? ?? false,
                        ),
                      );
                }
                continue;
              }
            }
          }
        }
      }
    }
    return ValidateIosDomainResult(errorCode, domainErrors, paths);
  }

  // The request can take 1000 domains at most, split domains to make a few calls in serial with a batch of _domainBatchSize.
  List<List<String>> _splitDomains(List<String> domains) {
    return List.generate(
      (domains.length / _domainBatchSize).ceil(),
      (index) => domains.sublist(
        index * _domainBatchSize,
        (index + 1) * _domainBatchSize > domains.length
            ? domains.length
            : (index + 1) * _domainBatchSize,
      ),
    );
  }

  Future<GenerateAssetLinksResult> generateAssetLinks({
    required String applicationId,
    required String domain,
    required String? localFingerprint,
  }) async {
    final response = await client.post(
      Uri.parse(assetLinksGenerationURL),
      headers: postHeader,
      body: jsonEncode({
        _packageNameKey: applicationId,
        _domainsKey: [domain],
        if (localFingerprint != null) _fingerprintsKey: [localFingerprint],
      }),
    );
    final result = json.decode(response.body) as Map<String, Object?>;
    final errorCode = (result[_errorCodeKey] as String?) ?? '';
    String generatedContent = '';

    final domains =
        (result[_domainsKey] as List?)?.cast<Map<String, Object?>>();
    if (domains != null) {
      generatedContent = domains.first[_generatedContentKey]! as String;
    }

    return GenerateAssetLinksResult(errorCode, generatedContent);
  }
}
