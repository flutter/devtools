// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_shared/devtools_deeplink.dart';

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
      "status": "VALIDATION_COMPLETE",
      "aasaAppPaths": [
        {
          "aasaAppId": {
            "bundleId": "bundle.id",
            "teamId": "AAABBB"
          },
          "aasaPaths": [
            {
              "path": "/ios-path1",
              "queryParams": [
                {
                  "key": "dplnk",
                  "value": "?*"
                }
              ],
              "isCaseSensitive": true,
              "isPercentEncoded": true
            },
            {
              "path": "/ios-path2",
              "isExcluded": true,
              "queryParams": [
                {
                  "key": "dplnk",
                  "value": "?*"
                }
              ],
              "isCaseSensitive": true,
              "isPercentEncoded": true
            },
            {
              "queryParams": [
                {
                  "key": "dplnk",
                  "value": "?*"
                }
              ],
              "isCaseSensitive": true,
              "isPercentEncoded": true
            }
          ]
        }
      ]
    }
  ]
}
''';

const iosValidationResponseWithWarning = '''
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
      "failedChecks": [
        {
          "checkName": "DEFAULTS_FORMAT",
          "resultType": "FAILED_INDEPENDENTLY",
          "severityLevel": "WARNING"
        }
      ],
      "status": "VALIDATION_COMPLETE",
      "aasaAppPaths": [
        {
          "aasaAppId": {
            "bundleId": "bundle.id",
            "teamId": "AAABBB"
          },
          "aasaPaths": [
            {
              "path": "/ios-path1",
              "queryParams": [
                {
                  "key": "dplnk",
                  "value": "?*"
                }
              ],
              "isCaseSensitive": true,
              "isPercentEncoded": true
            },
            {
              "path": "/ios-path2",
              "isExcluded": true,
              "queryParams": [
                {
                  "key": "dplnk",
                  "value": "?*"
                }
              ],
              "isCaseSensitive": true,
              "isPercentEncoded": true
            }
          ]
        }
      ]
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
          "resultType": "FAILED_INDEPENDENTLY",
          "severityLevel": "ERROR",
          "subCheckResults": [
            {
              "checkName": "APPLINKS_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "ERROR"
            },
            {
              "checkName": "DETAIL_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "ERROR"
            },
            {
              "checkName": "DEFAULTS_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "DEFAULTS_PERCENT_ENCODED_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "DEFAULTS_CASE_SENSITIVE_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "DETAIL_PATHS_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "COMPONENT_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "COMPONENT_PATH_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "COMPONENT_QUERY_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "COMPONENT_FRAGMENT_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "COMPONENT_EXCLUDE_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "COMPONENT_COMMENT_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "COMPONENT_CASE_SENSITIVE_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "COMPONENT_PERCENT_ENCODED_FORMAT",
              "resultType": "FAILED_INDEPENDENTLY",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "DETAIL_DEFAULTS_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "DETAIL_DEFAULTS_CASE_SENSITIVE_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "DETAIL_DEFAULTS_PERCENT_ENCODED_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            },
            {
              "checkName": "APPLINKS_SUBSTITUTION_VARIABLES_FORMAT",
              "resultType": "PASSED",
              "severityLevel": "WARNING"
            }
          ]
        }
      ],
      "status": "VALIDATION_COMPLETE",
      "aasaAppPaths": [
        {
          "aasaAppId": {
            "bundleId": "bundle.id",
            "teamId": "AAABBB"
          },
          "aasaPaths": [
            {
              "path": "/ios-path1",
              "queryParams": [
                {
                  "key": "dplnk",
                  "value": "?*"
                }
              ],
              "isCaseSensitive": true,
              "isPercentEncoded": true
            },
            {
              "path": "/ios-path2",
              "isExcluded": true,
              "queryParams": [
                {
                  "key": "dplnk",
                  "value": "?*"
                }
              ],
              "isCaseSensitive": true,
              "isPercentEncoded": true
            }
          ]
        }
      ]
    }
  ]
}
''';

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

const defaultDomain = 'example.com';

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

UniversalLinkSettings fakeUniversalLinkSettings(List<String> domains) {
  return UniversalLinkSettings.fromJson('''
{
  "bundleIdentifier": "app.id",
  "teamIdentifier": "AAAABBBB",
  "associatedDomains": [
    ${domains.map((d) => '"$d"').join(',')}
  ]
}
''');
}
