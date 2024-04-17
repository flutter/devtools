// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import 'extension_test_manager.dart';

void main() {
  group('$ExtensionTestManager', () {});

  group('$TestPackageWithExtension', () {
    test('$driftPackage', () {
      expect(driftPackage.name, 'drift');
      expect(
        driftPackage.issueTracker,
        'https://github.com/simolus3/drift/issues',
      );
      expect(driftPackage.version, '0.0.1');
      expect(driftPackage.materialIconCodePoint, 62494);
      expect(driftPackage.requiresConnection, true);
      expect(driftPackage.isPubliclyHosted, true);
      expect(driftPackage.packageVersion, '2.16.0');
      expect(driftPackage.relativePathFromExtensions, driftPackage.name);
    });

    test('$providerPackage', () {
      expect(providerPackage.name, 'provider');
      expect(
        providerPackage.issueTracker,
        'https://github.com/rrousselGit/provider/issues',
      );
      expect(providerPackage.version, '0.0.1');
      expect(providerPackage.materialIconCodePoint, 57521);
      expect(providerPackage.requiresConnection, true);
      expect(providerPackage.isPubliclyHosted, true);
      expect(providerPackage.packageVersion, '6.1.2');
      expect(providerPackage.relativePathFromExtensions, providerPackage.name);
    });

    test('$staticExtension1Package', () {
      expect(staticExtension1Package.name, 'static_extension_1');
      expect(staticExtension1Package.issueTracker, 'https://www.google.com/');
      expect(staticExtension1Package.version, '1.0.0');
      expect(staticExtension1Package.materialIconCodePoint, 0xe50a);
      expect(staticExtension1Package.requiresConnection, false);
      expect(staticExtension1Package.isPubliclyHosted, false);
      expect(staticExtension1Package.packageVersion, null);
      expect(
        staticExtension1Package.relativePathFromExtensions,
        staticExtension1Package.name,
      );
      expect(
        staticExtension1Package.pubspecContent,
        '''
name: static_extension_1
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
''',
      );
      expect(
        staticExtension1Package.configYamlContent,
        '''
name: static_extension_1
issueTracker: https://www.google.com/
version: 1.0.0
materialIconCodePoint: 0xe50a
requiresConnection: false
''',
      );
    });

    test('$staticExtension2Package', () {
      expect(staticExtension2Package.name, 'static_extension_2');
      expect(staticExtension2Package.issueTracker, 'https://www.google.com/');
      expect(staticExtension2Package.version, '2.0.0');
      expect(staticExtension2Package.materialIconCodePoint, 0xe50a);
      expect(staticExtension2Package.requiresConnection, false);
      expect(staticExtension2Package.isPubliclyHosted, false);
      expect(staticExtension2Package.packageVersion, null);
      expect(
        staticExtension2Package.relativePathFromExtensions,
        staticExtension2Package.name,
      );
      expect(
        staticExtension2Package.pubspecContent,
        '''
name: static_extension_2
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
''',
      );
      expect(
        staticExtension2Package.configYamlContent,
        '''
name: static_extension_2
issueTracker: https://www.google.com/
version: 2.0.0
materialIconCodePoint: 0xe50a
requiresConnection: false
''',
      );
    });

    test('$newerStaticExtension1Package', () {
      expect(newerStaticExtension1Package.name, 'static_extension_1');
      expect(
        newerStaticExtension1Package.issueTracker,
        'https://www.google.com/',
      );
      expect(newerStaticExtension1Package.version, '2.0.0');
      expect(newerStaticExtension1Package.materialIconCodePoint, 0xe50a);
      expect(newerStaticExtension1Package.requiresConnection, false);
      expect(newerStaticExtension1Package.isPubliclyHosted, false);
      expect(newerStaticExtension1Package.packageVersion, null);
      expect(
        newerStaticExtension1Package.relativePathFromExtensions,
        'newer/static_extension_1',
      );
      expect(
        newerStaticExtension1Package.pubspecContent,
        '''
name: static_extension_1
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
''',
      );
      expect(
        newerStaticExtension1Package.configYamlContent,
        '''
name: static_extension_1
issueTracker: https://www.google.com/
version: 2.0.0
materialIconCodePoint: 0xe50a
requiresConnection: false
''',
      );
    });

    test('$badExtensionPackage', () {
      expect(badExtensionPackage.name, 'BAD_EXTENSION');
      expect(badExtensionPackage.issueTracker, 'https://www.google.com/');
      expect(badExtensionPackage.version, '1.0.0');
      expect(badExtensionPackage.materialIconCodePoint, 0xe50a);
      expect(badExtensionPackage.requiresConnection, true);
      expect(badExtensionPackage.isPubliclyHosted, false);
      expect(badExtensionPackage.packageVersion, null);
      expect(
        badExtensionPackage.relativePathFromExtensions,
        badExtensionPackage.name.toLowerCase(),
      );
      expect(
        badExtensionPackage.pubspecContent,
        '''
name: bad_extension
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
''',
      );
      expect(
        badExtensionPackage.configYamlContent,
        '''
name: BAD_EXTENSION
issueTracker: https://www.google.com/
version: 1.0.0
materialIconCodePoint: 0xe50a

''',
      );
    });
  });

  group('$TestPackage', () {
    test('$myAppPackage', () {
      expect(myAppPackage.name, 'my_app');
      expect(myAppPackage.dependencies.length, 3);
      expect(
        myAppPackage.pubspecContent,
        '''
name: my_app
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:
  drift: 2.16.0
  provider: 6.1.2
  static_extension_1:
    path: ../../extensions/static_extension_1

''',
      );
    });

    test('$myAppPackageWithBadExtension', () {
      expect(myAppPackageWithBadExtension.name, 'my_app');
      expect(myAppPackageWithBadExtension.dependencies.length, 4);
      expect(
        myAppPackageWithBadExtension.pubspecContent,
        '''
name: my_app
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:
  drift: 2.16.0
  provider: 6.1.2
  static_extension_1:
    path: ../../extensions/static_extension_1
  bad_extension:
    path: ../../extensions/bad_extension

''',
      );
    });

    test('$otherRoot1Package', () {
      expect(otherRoot1Package.name, 'other_root_1');
      expect(otherRoot1Package.dependencies.length, 2);
      expect(
        otherRoot1Package.pubspecContent,
        '''
name: other_root_1
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:
  static_extension_1:
    path: ../../extensions/static_extension_1
  static_extension_2:
    path: ../../extensions/static_extension_2

''',
      );
    });

    test('$otherRoot2Package', () {
      expect(otherRoot2Package.name, 'other_root_2');
      expect(otherRoot2Package.dependencies.length, 1);
      expect(
        otherRoot2Package.pubspecContent,
        '''
name: other_root_2
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:
  static_extension_1:
    path: ../../extensions/newer/static_extension_1

''',
      );
    });

    test('createTestPackageFrom when excluding dependencies', () {
      var pkg = createTestPackageFrom(
        myAppPackage,
        includeDependenciesWithExtensions: false,
      );
      expect(
        pkg.pubspecContent,
        '''
name: my_app
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:

''',
      );
      pkg = createTestPackageFrom(
        myAppPackageWithBadExtension,
        includeDependenciesWithExtensions: false,
      );
      expect(
        pkg.pubspecContent,
        '''
name: my_app
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:

''',
      );
      pkg = createTestPackageFrom(
        otherRoot1Package,
        includeDependenciesWithExtensions: false,
      );
      expect(
        pkg.pubspecContent,
        '''
name: other_root_1
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:

''',
      );
      pkg = createTestPackageFrom(
        otherRoot2Package,
        includeDependenciesWithExtensions: false,
      );
      expect(
        pkg.pubspecContent,
        '''
name: other_root_2
environment:
  sdk: ">=3.4.0-282.1.beta <4.0.0"
dependencies:

''',
      );
    });
  });
}
