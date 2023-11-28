// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'deep_links_model.dart';

const String _apiKey = 'AIzaSyDVE6FP3GpwxgS4q8rbS7qaf6cAbxc_elc';
const String _assetLinksGenerationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/generation/v1/assetlinks:generate?key=$_apiKey';
const String _androidDomainValidationURL =
    'https://deeplinkassistant-pa.googleapis.com/android/validation/v1/domains:batchValidate?key=$_apiKey';
const postHeader = {'Content-Type': 'application/json'};
const String _packageNameKey = 'package_name';
const String _domainsKey = 'domains';
const String _errorCodeKey = 'errorCode';
const String _appLinkDomainsKey = 'app_link_domains';
const String _validationResultKey = 'validationResult';
const String _domainNameKey = 'domainName';
const String _checkNameKey = 'checkName';
const String _failedChecksKey = 'failedChecks';
const String _generatedContentKey = 'generatedContent';
const String _existenceCheckKey = 'EXISTENCE';
const String _fingerPrintChecktKey = 'FINGERPRINT';

class DeepLinksServices {
  Future<Map<String, List<DomainError>>> validateAndroidDomain({
    required List<String> domains,
    required String applicationId,
  }) async {
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

    final domainErrors = <String, List<DomainError>>{
      for (var domain in domains) domain: <DomainError>[],
    };

    final validationResult = result[_validationResultKey] as List;
    for (final Map<String, dynamic> domainResult in validationResult) {
      final String domainName = domainResult[_domainNameKey];
      final List? failedChecks = domainResult[_failedChecksKey];
      if (failedChecks != null) {
        for (final Map<String, dynamic> failedCheck in failedChecks) {
          switch (failedCheck[_checkNameKey]) {
            case _existenceCheckKey:
              domainErrors[domainName]!.add(DomainError.existence);
            case _fingerPrintChecktKey:
              domainErrors[domainName]!.add(DomainError.fingerprints);
          }
        }
      }
    }
    return domainErrors;
  }

  Future<String> generateAssetLinks({
    required String applicationId,
    required String domain,
  }) async {
    final response = await http.post(
      Uri.parse(_assetLinksGenerationURL),
      headers: postHeader,
      body: jsonEncode(
        {
          _packageNameKey: applicationId,
          _domainsKey: [domain],
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

    if (result[_errorCodeKey] != null) {
      return 'Content generation failed.\n Reason: ${result[_errorCodeKey]}';
    }
    if (result[_domainsKey] != null) {
      final String generatedContent = (((result[_domainsKey] as List).first)
          as Map<String, dynamic>)[_generatedContentKey];

      return generatedContent;
    }
    return '';
  }
}
