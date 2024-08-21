// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_model.dart';
import 'package:devtools_app/src/screens/deep_link_validation/deep_links_services.dart';
import 'package:devtools_shared/devtools_deeplink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

// Fake responses for the deep link validation API.
const androidValidationResponseWithNoError = '''
{
  "validationResult": [
    {
      "domainName": "example.com",
      "passedChecks": [
        {
          "checkName": "HOST_FORMED_PROPERLY",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "EXISTENCE",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "NON_REDIRECT",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "HTTPS_ACCESSIBILITY",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "CONTENT_TYPE",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "APP_IDENTIFIER",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "FINGERPRINT",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        }
      ],
      "status": "CHECKED"
    }
  ],
  "googlePlayFingerprintsAvailability": "FINGERPRINTS_AVAILABLE"
}
''';

const androidValidationResponseWithError = '''
{
  "validationResult": [
    {
      "domainName": "example.com",
      "passedChecks": [
        {
          "checkName": "HOST_FORMED_PROPERLY",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "NON_REDIRECT",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "HTTPS_ACCESSIBILITY",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        }
      ],
      "failedChecks": [
        {
          "checkName": "EXISTENCE",
          "resultType": "FAILED_INDEPENDENTLY",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "CONTENT_TYPE",
          "resultType": "FAILED_INDEPENDENTLY",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "APP_IDENTIFIER",
          "resultType": "FAILED_DUE_TO_PREREQUISITE_FAILURE",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "FINGERPRINT",
          "resultType": "FAILED_DUE_TO_PREREQUISITE_FAILURE",
          "severityLevel": "ERROR"
        }
      ],
      "status": "CHECKED"
    }
  ],
  "googlePlayFingerprintsAvailability": "FINGERPRINTS_AVAILABLE"
}
''';

const iosValidationResponseWithNoError = '''
{
  "validationResults": [
    {
      "domainName": "example.com",
      "passedChecks": [
        {
          "checkName": "HTTPS_ACCESSIBILITY",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "NON_REDIRECT",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "EXISTENCE",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "APP_IDENTIFIER",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "FILE_FORMAT",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        }
      ],
      "status": "VALIDATION_COMPLETE"
    }
  ]
}
''';

const iosValidationResponseWithError = '''
{
  "validationResults": [
    {
      "domainName": "example.com",
      "passedChecks": [
        {
          "checkName": "HTTPS_ACCESSIBILITY",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "NON_REDIRECT",
          "resultType": "PASSED",
          "severityLevel": "ERROR"
        }
      ],
      "failedChecks": [
        {
          "checkName": "EXISTENCE",
          "resultType": "FAILED_INDEPENDENTLY",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "APP_IDENTIFIER",
          "resultType": "FAILED_PREREQUISITE_FAILURE",
          "severityLevel": "ERROR"
        },
        {
          "checkName": "FILE_FORMAT",
          "resultType": "FAILED_PREREQUISITE_FAILURE",
          "severityLevel": "ERROR"
        }
      ],
      "status": "VALIDATION_COMPLETE"
    }
  ]
}
''';

final defaultAndroidDeeplink = androidDeepLinkJson(defaultDomain);

const androidDeepLinkWithPathErrors = '''{
      "host": "example.com",
      "path": "/path",
      "intentFilterCheck": {
        "hasBrowsableCategory": false,
        "hasActionView": true,
        "hasDefaultCategory": true,
        "hasAutoVerify": true
      }
    }
''';

String androidDeepLinkJson(
  String domain, {
  String? scheme = 'http',
  String? path = '/path',
  bool hasPathError = false,
}) {
  return '''{
${(scheme != null) ? '"scheme": "$scheme",' : ''}
      "host": "$domain",
      "path": "$path",
      "intentFilterCheck": {
        "hasBrowsableCategory": ${!hasPathError},
        "hasActionView": true,
        "hasDefaultCategory": true,
        "hasAutoVerify": true
      }
    }
''';
}

AppLinkSettings fakeAppLinkSettings(List<String> androidDeepLink) {
  return AppLinkSettings.fromJson('''{
  "deeplinks": [
    ${androidDeepLink.join(',')}
  ],
  "deeplinkingFlagEnabled": true,
  "applicationId": "app.id"
}
''');
}

const defaultDomain = 'example.com';
UniversalLinkSettings fakeUniversalLinkSettings(List<String> domains) {
  return UniversalLinkSettings.fromJson('''
{
  "bundleIdentifier": "app.id",
  "teamIdentifier": "AAAABBBB",
  "associatedDomains": [
    ${domains.map(
            (d) => '"$d"',
          ).join(',')}
  ]
}
''');
}

class DeepLinksTestController extends DeepLinksController {
  DeepLinksTestController() {
    // Create a mock client to return fake responses.
    final client = MockClient((request) async {
      if (request.url == Uri.parse(androidDomainValidationURL)) {
        if (hasAndroidDomainErrors) {
          return Response(androidValidationResponseWithError, 200);
        } else {
          return Response(androidValidationResponseWithNoError, 200);
        }
      }
      if (request.url == Uri.parse(iosDomainValidationURL)) {
        print('request.url == Uri.parse(iosDomainValidationURL');
        if (hasIosDomainErrors) {
          return Response(iosValidationResponseWithError, 200);
        } else {
          return Response(iosValidationResponseWithNoError, 200);
        }
      }
      return Response('this is a body', 404);
    });
    deepLinksServices = DeepLinksServices(client);
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

  List<String> fakeAndroidDeepLinks = [];
  bool hasAndroidDomainErrors = false;
  bool hasAndroidPathErrors = false;
  bool hasIosDomainErrors = false;
  List<String> fakeIosDomains = [];

  @override
  Future<String?> packageDirectoryForMainIsolate() async {
    return null;
  }

  @override
  Future<void> validateLinks() async {
    androidAppLinks[selectedAndroidVariantIndex.value] =
        fakeAppLinkSettings(fakeAndroidDeepLinks);
    iosLinks[selectedIosConfigurationIndex.value] =
        fakeUniversalLinkSettings(fakeIosDomains);

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
