// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_model.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

import '../test_data/deep_link/fake_responses.dart';

final defaultAndroidDeeplink = androidDeepLinkJson(defaultDomain);

class TestDeepLinksService extends DeepLinksService {
  TestDeepLinksService({
    this.hasAndroidDomainErrors = false,
    this.iosValidationResponse = '',
  }) {
    // Create a mock client to return fake responses.
    _client = MockClient((request) async {
      if (request.url == Uri.parse(androidDomainValidationURL)) {
        if (hasAndroidDomainErrors) {
          return Response(androidValidationResponseWithError, 200);
        } else {
          return Response(androidValidationResponseWithNoError, 200);
        }
      }
      if (request.url == Uri.parse(iosDomainValidationURL)) {
        return Response(iosValidationResponse, 200);
      }
      return Response('this is a body', 404);
    });
  }

  late Client _client;

  @override
  Client get client => _client;

  final bool hasAndroidDomainErrors;
  final String iosValidationResponse;
}

class TestDeepLinksController extends DeepLinksController {
  TestDeepLinksController({
    this.hasAndroidDomainErrors = false,
    this.iosValidationResponse = iosValidationResponseWithNoError,
  }) {
    _deepLinksService = TestDeepLinksService(
      hasAndroidDomainErrors: hasAndroidDomainErrors,
      iosValidationResponse: iosValidationResponse,
    );
  }

  List<String> fakeAndroidDeepLinks = [];
  bool hasAndroidDomainErrors = false;
  bool hasAndroidPathErrors = false;
  String iosValidationResponse = '';
  List<String> fakeIosDomains = [];

  late DeepLinksService _deepLinksService;

  @override
  DeepLinksService get deepLinksService => _deepLinksService;

  @override
  Future<String?> packageDirectoryForMainIsolate() async {
    return null;
  }

  @override
  Future<void> validateLinks() async {
    androidAppLinks[selectedAndroidVariantIndex.value] = fakeAppLinkSettings(
      fakeAndroidDeepLinks,
    );
    iosLinks[selectedIosConfigurationIndex.value] = fakeUniversalLinkSettings(
      fakeIosDomains,
    );

    await super.validateLinks();
  }

  @override
  void selectLink(LinkData linkdata) async {
    selectedLink.value = linkdata;
    if (linkdata.domainErrors.isNotEmpty) {
      generatedAssetLinksForSelectedLink.value = GenerateAssetLinksResult(
        '',
        'fake generated content',
      );
    }
  }
}
