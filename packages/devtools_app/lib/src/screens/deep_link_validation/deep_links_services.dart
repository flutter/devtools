// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deep_links_model.dart';

const _apiKey = 'AIzaSyCf_2E9N2AUZR-YSnZTQ72YbCNhKIskIsw';
const _assetLinksGenerationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/generation/v1/assetlinks:generate?key=$_apiKey';
const _androidDomainValidationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/validation/v1/domains:batchValidate?key=$_apiKey';
const _iosDomainValidationURL =
    'https://deeplinkassistant-pa.googleapis.com/ios/validation/v1/domains:batchValidate?key=$_apiKey';
const postHeader = {'Content-Type': 'application/json'};

// The keys used in both android and ios domain validation API.
const _domainNameKey = 'domainName';
const _checkNameKey = 'checkName';
const _failedChecksKey = 'failedChecks';
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

const iosCheckNameToDomainError = <String, DomainError>{
  'EXISTENCE': IosDomainError.existence,
  'APP_IDENTIFIER': IosDomainError.appIdentifier,
  'HTTPS_ACCESSIBILITY': IosDomainError.httpsAccessibility,
  'NON_REDIRECT': IosDomainError.nonRedirect,
  'FILE_FORMAT': IosDomainError.fileFormat,
};

class ValidateIosDomainResult {
  ValidateIosDomainResult(this.errorCode, this.domainErrors);
  final String errorCode;
  final Map<String, List<DomainError>> domainErrors;
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

class DeepLinksServices {
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
      final response = await http.post(
        Uri.parse(_androidDomainValidationURL),
        headers: postHeader,
        body: jsonEncode({
          _packageNameKey: applicationId,
          _appLinkDomainsKey: domainList,
          if (localFingerprint != null) _fingerprintsKey: [localFingerprint],
        }),
      );

      final result = json.decode(response.body) as Map<String, Object?>;

      final validationResult = (result[_androidValidationResultKey] as List)
          .cast<Map<String, Object?>>();
      googlePlayFingerprintsAvailable =
          result[_googlePlayFingerprintsAvailabilityKey] ==
              _googlePlayFingerprintsAvailableValue;
      for (final domainResult in validationResult) {
        final domainName = domainResult[_domainNameKey] as String;
        final failedChecks = (domainResult[_failedChecksKey] as List?)
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
    final domainErrors = <String, List<DomainError>>{
      for (final domain in domains) domain: <DomainError>[],
    };
    // TODO(hangyujin): Add error code to the result.
    const errorCode = '';

    final domainsByBatch = _splitDomains(domains);

    for (final domainList in domainsByBatch) {
      final response = await http.post(
        Uri.parse(_iosDomainValidationURL),
        headers: postHeader,
        body: jsonEncode({
          _appIdKey: {
            _bundleIdKey: bundleId,
            _teamIdKey: teamId,
          },
          _universalLinkDomainsKey: [
            for (final domain in domainList) {_iosDomainNameKey: domain},
          ],
        }),
      );
      final result = json.decode(response.body) as Map<String, Object?>;
      final validationResult = (result[_iosValidationResultsKey] as List)
          .cast<Map<String, Object?>>();

      for (final domainResult in validationResult) {
        if (domainResult[_domainNameKey] case final String domainName) {
          final failedChecks = (domainResult[_failedChecksKey] as List?)
              ?.cast<Map<String, Object?>>();
          if (failedChecks != null) {
            for (final failedCheck in failedChecks) {
              final checkName = failedCheck[_checkNameKey] as String;
              final domainError = iosCheckNameToDomainError[checkName];
              if (domainError != null) {
                domainErrors[domainName]!.add(domainError);
              }
            }
          }
        }
        // TODO(hangyujin): Add path from AASA file check result.
      }
    }
    return ValidateIosDomainResult(
      errorCode,
      domainErrors,
    );
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
    final response = await http.post(
      Uri.parse(_assetLinksGenerationURL),
      headers: postHeader,
      body: jsonEncode(
        {
          _packageNameKey: applicationId,
          _domainsKey: [domain],
          if (localFingerprint != null) _fingerprintsKey: [localFingerprint],
        },
      ),
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
