import 'dart:io';

import 'package:devtools_shared/src/utils/license_utils.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../helpers/helpers.dart';

const licenseText1 = 
'''// This is some 2015 multiline license
// text that should be removed from the file.
''';

const licenseText2 = 
'''/* This is other 1999 multiline license
text that should be removed from the file. */
''';

const licenseText3 = 
'''# This some more 2001 multiline license
# text that should be removed from the file.
''';

const extraText = '''

This is just some extra text to fill in the
contents following the license text in the test files.

It really doesn't matter what the text says.''';

late Directory testDirectory;

late File configFile;

late Directory repoRoot;
late File hiddenFile;
late File testFile1;
late File testFile2;
late File testFile3;
late File testFile4;
late File testFile5;
late File testFile6;
late File testFile7;
late File testFile8;
late File testFile9;
late File testFile10;
late File excludeFile1;
late File excludeFile2;

void main() {
  group('config file tests', () {
    setUp(() async {
      await _setupTestConfigFile();
    });

    tearDownAll(() async {
      await deleteDirectoryWithRetry(testDirectory);
    });

    test('config can be read from disk without any errors', () {
      expect(() => LicenseConfig.fromYamlFile(configFile), returnsNormally);
    });

    test('remove licenses text is parsed correctly', () {
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);
      
      expect(config.removeLicenses.length, equals(3));

      var expectedVal = '''// This is some {value} multiline license
// text that should be removed from the file.
''';
      expect(config.removeLicenses[0], equals(expectedVal));
      
      expectedVal = '''/* This is other {value} multiline license
text that should be removed from the file. */
''';
      expect(config.removeLicenses[1], equals(expectedVal));

      expectedVal = '''# This is more {value} multiline license
# text that should be removed from the file.
''';
      expect(config.removeLicenses[2], equals(expectedVal));
    });

    test('add licenses text is parsed correctly', () {
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);
      
      expect(config.addLicenses.length, equals(2));

      var expectedVal = '''// This is some {value} multiline license
// text that should be added from the file.
''';
      expect(config.addLicenses[0], equals(expectedVal));
      
      expectedVal = '''# This is more {value} multiline license
# text that should be removed from the file.
''';
      expect(config.addLicenses[1], equals(expectedVal));

    });

    test('file types parsed correctly', () {
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);

      YamlList removeIndices = config.getRemoveIndicesForExtension('ext1');
      expect(removeIndices.length, equals(2));
      expect(removeIndices[0],equals(0));
      expect(removeIndices[1],equals(1));

      int addIndex = config.getAddIndexForExtension('ext1');
      expect(addIndex, equals(0));

      removeIndices = config.getRemoveIndicesForExtension('ext2');
      expect(removeIndices.length, equals(1));
      expect(removeIndices[0],equals(2));

      addIndex = config.getAddIndexForExtension('ext2');
      expect(addIndex, equals(1));

    });
  });

  group('license update tests', () {
    setUp(() async {
      await _setupTestDirectoryStructure();
    });

    tearDownAll(() async {
      await deleteDirectoryWithRetry(testDirectory);
    });

    test('value preserved', () {

    });

    test('update skipped if license not found', () {

    });
  });
}

/// Sets up the config file
Future<void> _setupTestConfigFile() async {

  testDirectory = Directory.systemTemp.createTempSync();
  configFile = File(p.join(testDirectory.path, 'test_config.yaml'))
    ..createSync(recursive: true);

  const contents = 
'''---
# sequence of license text strings that should be matched against at the top of a file and removed. {value} will be stored.
remove_licenses:
  - |
    // This is some {value} multiline license
    // text that should be removed from the file.
  - |
    /* This is other {value} multiline license
    text that should be removed from the file. */
  - |
    # This is more {value} multiline license
    # text that should be removed from the file.
# sequence of license text strings that should be added to the top of a file. {value} will be replaced.
add_licenses: 
  - |
    // This is some {value} multiline license 
    // text that should be added to the file.
  - |
    # This is other {value} multiline license
    # text that should be added to the file.
# defines which files should have license text added or updated.
update_paths:
  # path(s) to recursively check for files to remove/add license
  include:
      - /repo_root
  # path(s) to recursively check for files to ignore
  exclude:
    # exclude everything in the /repo_root/sub_dir1 directory
    - /repo_root/sub_dir1/
    # exclude the given files
    - /repo_root/sub_dir2/exclude1.ext1
    - /repo_root/sub_dir2/sub_dir3/exclude2.ext2
  # extensions
  file_types:
    ext1:
      # one or more indices of remove_licenses to remove
      remove:
        - 0
        - 1
      # index of add_licenses to add
      add: 0
    ext2:
      remove:
        - 2
      add: 1''';

  await configFile.writeAsString(contents);
}

/// Sets up the directory structure for the tests
/// repo_root/
///    test1.ext1
///    test2.ext2
///    .hidden/
///       test3.ext1
///    sub_dir1/
///       test4.ext1
///       sub_dir1a/
///          test5.ext2
///          sub_dir1b/
///             test6.ext1
///    sub_dir2/
///       exclude1.ext1
///       test7.ext2
///       sub_dir3/
///          test8.ext1
///          exclude2.ext2
///       sub_dir4/
///          test9.ext1
///          sub_dir5/
///            test10.ext2
///          
Future<void> _setupTestDirectoryStructure() async {

  testDirectory = Directory.systemTemp.createTempSync();

  // Setup /repo_root directory structure
  repoRoot = Directory(p.joinAll([testDirectory.path, 'repo_root']))
    ..createSync(recursive: true);

  testFile1 = File(p.join(repoRoot.path, 'test1.ext1'))
    ..createSync(recursive: true);
  await testFile1.writeAsString(licenseText1 + extraText);

  testFile2 = File(p.join(repoRoot.path, 'test2.ext2'))
    ..createSync(recursive: true);
  await testFile2.writeAsString(licenseText3 + extraText);

  // Setup /repo_root/.hidden directory structure
  Directory(p.join(repoRoot.path, '.hidden'))
    .createSync(recursive: true);

  testFile3 = File(p.join(repoRoot.path, '.hidden', 'test3.ext1'))
    ..createSync(recursive: true);
  await testFile3.writeAsString(licenseText2 + extraText);

  // Setup /repo_root/sub_dir1/sub_dir1a/sub_dir1b directory structure
  Directory(
    p.join(
      repoRoot.path, 
      'sub_dir1',
      'sub_dir1a',
      'sub_dir1b',
    ),
  ).createSync(recursive: true);

  testFile4 = File(p.join(repoRoot.path, 'sub_dir1', 'test4.ext1'))
    ..createSync(recursive: true);
  await testFile4.writeAsString(licenseText1 + extraText);
  testFile5 = File(p.join(repoRoot.path, 'sub_dir1', 'sub_dir1a', 'test5.ext2'))
    ..createSync(recursive: true);
  await testFile5.writeAsString(licenseText3 + extraText);
  testFile6 = File(p.join(repoRoot.path, 'sub_dir1', 'sub_dir1a', 'sub_dir1b', 'test6.ext2'))
    ..createSync(recursive: true);
  await testFile6.writeAsString(licenseText3 + extraText);

  // Setup /repo_root/sub_dir2 directory structure
  Directory(p.join(repoRoot.path, 'sub_dir2'))
    .createSync(recursive: true);

  excludeFile1 = File(p.join(repoRoot.path, 'sub_dir2', 'exclude1.ext1'))
    ..createSync(recursive: true);
  await excludeFile1.writeAsString(licenseText2 + extraText);
  testFile7 = File(p.join(repoRoot.path, 'sub_dir2', 'test7.ext2'))
    ..createSync(recursive: true);
  await testFile7.writeAsString(licenseText3 + extraText);
    
  // Setup /repo_root/sub_dir2/sub_dir3 directory structure
  Directory(
    p.join(
      repoRoot.path, 
      'sub_dir2',
      'sub_dir3',
    ),
  ).createSync(recursive: true);

  testFile8 = File(p.join(repoRoot.path, 'sub_dir2', 'sub_dir3', 'test8.ext1'))
    ..createSync(recursive: true);
  await testFile8.writeAsString(licenseText2 + extraText);
  excludeFile2 = File(p.join(repoRoot.path, 'sub_dir2', 'sub_dir3', 'exclude2.ext2'))
    ..createSync(recursive: true);
  await excludeFile2.writeAsString(licenseText3 + extraText);

  // Setup /repo_root/sub_dir2/sub_dir4 directory structure
  Directory(
    p.join(
      repoRoot.path, 
      'sub_dir2',
      'sub_dir4',
    ),
  ).createSync(recursive: true);

  testFile9 = File(p.join(repoRoot.path, 'sub_dir2', 'sub_dir4', 'test9.ext1'))
    ..createSync(recursive: true);
  await testFile9.writeAsString(licenseText3 + extraText);

  // Setup /repo_root/sub_dir2/sub_dir4/sub_dir5 directory structure
  Directory(
    p.join(
      repoRoot.path, 
      'sub_dir2',
      'sub_dir4',
      'sub_dir5',
    ),
  ).createSync(recursive: true);

  testFile10 = File(p.join(repoRoot.path, 'sub_dir2', 'sub_dir4', 'sub_dir5', 'test10.ext2'))
    ..createSync(recursive: true);
  await testFile10.writeAsString(licenseText2 + extraText);
}