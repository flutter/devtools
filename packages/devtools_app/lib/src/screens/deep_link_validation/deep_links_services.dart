// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deep_links_model.dart';

const String _apiKey = 'AIzaSyCf_2E9N2AUZR-YSnZTQ72YbCNhKIskIsw';
const String _assetLinksGenerationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/generation/v1/assetlinks:generate?key=$_apiKey';
const String _androidDomainValidationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/validation/v1/domains:batchValidate?key=$_apiKey';
const postHeader = {'Content-Type': 'application/json'};
const String _packageNameKey = 'package_name';
const String _domainsKey = 'domains';
const String _errorCodeKey = 'errorCode';
const String _appLinkDomainsKey = 'app_link_domains';
const String _fingerprintsKey = 'supplemental_sha256_cert_fingerprints';
const String _validationResultKey = 'validationResult';
const String _googlePlayFingerprintsAvailabilityKey =
    'googlePlayFingerprintsAvailability';
const String _googlePlayFingerprintsAvailableValue = 'FINGERPRINTS_AVAILABLE';
const String _domainNameKey = 'domainName';
const String _checkNameKey = 'checkName';
const String _failedChecksKey = 'failedChecks';
const String _generatedContentKey = 'generatedContent';
const int _domainBatchSize = 500;

const Map<String, DomainError> checkNameToDomainError = {
  'EXISTENCE': DomainError.existence,
  'APP_IDENTIFIER': DomainError.appIdentifier,
  'FINGERPRINT': DomainError.fingerprints,
  'CONTENT_TYPE': DomainError.contentType,
  'HTTPS_ACCESSIBILITY': DomainError.httpsAccessibility,
  'NON_REDIRECT': DomainError.nonRedirect,
  'HOST_FORMED_PROPERLY': DomainError.hostForm,
  'OTHER_CHECKS': DomainError.other,
};

class GenerateAssetLinksResult {
  GenerateAssetLinksResult(this.errorCode, this.generatedString);
  String errorCode;
  String generatedString;
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

    // The request can take 1000 domains at most, make a few calls in serial with a batch of _domainBatchSize.
    final List<List<String>> domainsBybatch = List.generate(
      (domains.length / _domainBatchSize).ceil(),
      (index) => domains.sublist(
        index * _domainBatchSize,
        (index + 1) * _domainBatchSize > domains.length
            ? domains.length
            : (index + 1) * _domainBatchSize,
      ),
    );
    late bool googlePlayFingerprintsAvailable;

    for (final domainList in domainsBybatch) {
      final response = await http.post(
        Uri.parse(_androidDomainValidationURL),
        headers: postHeader,
        body: jsonEncode({
          _packageNameKey: applicationId,
          _appLinkDomainsKey: domainList,
          if (localFingerprint != null) _fingerprintsKey: [localFingerprint],
        }),
      );

      final Map<String, dynamic> result =
          json.decode(response.body) as Map<String, dynamic>;

      final validationResult = result[_validationResultKey] as List;
      googlePlayFingerprintsAvailable =
          result[_googlePlayFingerprintsAvailabilityKey] ==
              _googlePlayFingerprintsAvailableValue;
      for (final Map<String, dynamic> domainResult in validationResult) {
        final String domainName = domainResult[_domainNameKey];
        final List? failedChecks = domainResult[_failedChecksKey];
        if (failedChecks != null) {
          for (final Map<String, dynamic> failedCheck in failedChecks) {
            final checkName = failedCheck[_checkNameKey] as String;
            final domainError = checkNameToDomainError[checkName];
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
    final Map<String, dynamic> result =
        json.decode(response.body) as Map<String, dynamic>;
    final String errorCode = result[_errorCodeKey] ?? '';
    String generatedContent = '';

    if (result[_domainsKey] != null) {
      generatedContent = (((result[_domainsKey] as List).first)
          as Map<String, dynamic>)[_generatedContentKey];
    }

    return GenerateAssetLinksResult(errorCode, generatedContent);
  }
}
