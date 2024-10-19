import 'dart:convert';
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
'''# This is more 2001 multiline license
# text that should be removed from the file.
''';

const licenseText4 =
'''// This is some multiline license text to
// remove that does not contain a stored value.
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
      await _setupTestDirectoryStructure();
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
      
      expect(config.removeLicenses.length, equals(4));

      var expectedVal = '''// This is some <value1> multiline license
// text that should be removed from the file.
''';
      expect(config.removeLicenses[0], equals(expectedVal));
      
      expectedVal = '''/* This is other <value2> multiline license
text that should be removed from the file. */
''';
      expect(config.removeLicenses[1], equals(expectedVal));

      expectedVal = '''# This is more <value3> multiline license
# text that should be removed from the file.
''';
      expect(config.removeLicenses[2], equals(expectedVal));

      expectedVal = '''// This is some multiline license text to
// remove that does not contain a stored value.
''';
      expect(config.removeLicenses[3], equals(expectedVal));
    });

    test('add licenses text is parsed correctly', () {
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);
      
      expect(config.addLicenses.length, equals(3));

      var expectedVal = '''// This is some <value1> multiline license
// text that should be added to the file.
''';
      expect(config.addLicenses[0], equals(expectedVal));
      
      expectedVal = '''# This is other <value3> multiline license
# text that should be added to the file.
''';
      expect(config.addLicenses[1], equals(expectedVal));

      expectedVal = '''// This is some multiline license text to
// add that does not contain a stored value.
''';
      expect(config.addLicenses[2], equals(expectedVal));
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

    test("included files shouldn't be excluded", () {
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);
      expect(config.shouldExclude(testFile1), false);
      expect(config.shouldExclude(testFile2), false);
      expect(config.shouldExclude(testFile3), false);
      expect(config.shouldExclude(testFile7), false);
      expect(config.shouldExclude(testFile8), false);
      expect(config.shouldExclude(testFile9), false);
      expect(config.shouldExclude(testFile10), false);
    });

    test('excluded files should be excluded', () {
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);
      expect(config.shouldExclude(excludeFile1), true);
      expect(config.shouldExclude(excludeFile2), true);
    });

    test('files in an excluded directory should be excluded', () {
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);
      expect(config.shouldExclude(testFile4), true);
      expect(config.shouldExclude(testFile5), true);
      expect(config.shouldExclude(testFile6), true);
    });

    test('files not in an included directory should be excluded', () {
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);

      final File fileNotInTestDirectory = File('test.txt');
      expect(config.shouldExclude(fileNotInTestDirectory), true);
    });
  });

  group('license update tests', () {
    setUp(() async {
      await _setupTestDirectoryStructure();
    });

    tearDownAll(() async {
      await deleteDirectoryWithRetry(testDirectory);
    });

    test('default to the current year in replacement header', () async {
      const existingLicenseText = '''// This is some multiline license text to
// remove that does not contain a stored value.''';
      const replacementLicenseText = 
        '''// This is some <value4> multiline license
// text that should be added to the file.''';

      final replacementInfo = await _getTestReplacementInfo(
        existingLicenseText, testFile10, replacementLicenseText,);
      
      const String expectedExistingHeader = 
        '''// This is some multiline license text to
// remove that does not contain a stored value.''';

      // Note: There might be a potential failure case if the test is
      // run right when the year ends and a new year starts.
      final String currentYear = DateTime.now().year.toString();
      final String expectedReplacementHeader = 
        '''// This is some $currentYear multiline license
// text that should be added to the file.''';

      expect(replacementInfo.containsKey('existing_header'), true);
      expect(replacementInfo['existing_header'], equals(expectedExistingHeader));

      expect(replacementInfo.containsKey('replacement_header'), true);
      expect(replacementInfo['replacement_header'], equals(expectedReplacementHeader));
    });

    test('stored value preserved in replacement header', () async {

      final List<File> testFiles = [testFile1,testFile2,testFile3];
      final List<String> existingLicenseTexts = [
        '''// This is some <value1> multiline license
// text that should be removed from the file.''',
        '''# This is more <value2> multiline license
# text that should be removed from the file.''',
        '''/* This is other <value3> multiline license
text that should be removed from the file. */''',
      ];
      final List<String> replacementLicenseTexts = [
        '''// This is some <value1> multiline license
// text that should be added to the file.''',
        '''# This is more <value2> multiline license
// text that should be added to the file.''',
        '''/* This is other <value3> multiline license
text that should be added to the file. */''',
      ];
      final List<String> expectedExistingHeaders = [
        '''// This is some 2015 multiline license
// text that should be removed from the file.''',
        '''# This is more 2001 multiline license
# text that should be removed from the file.''',
        '''/* This is other 1999 multiline license
text that should be removed from the file. */''',
      ];
      final List<String> expectedReplacementHeaders = [
        '''// This is some 2015 multiline license
// text that should be added to the file.''',
        '''# This is more 2001 multiline license
// text that should be added to the file.''',
        '''/* This is other 1999 multiline license
text that should be added to the file. */''',
      ];
      
      for (var i = 0; i < testFiles.length; i++) {
        final replacementInfo = await _getTestReplacementInfo(
          existingLicenseTexts[i], testFiles[i], replacementLicenseTexts[i],);

        expect(replacementInfo.containsKey('existing_header'), true, reason: 'Failed on iteration $i');
        expect(replacementInfo['existing_header'], equals(expectedExistingHeaders[i]), reason: 'Failed on iteration $i');

        expect(replacementInfo.containsKey('replacement_header'), true, reason: 'Failed on iteration $i');
        expect(replacementInfo['replacement_header'], equals(expectedReplacementHeaders[i]), reason: 'Failed on iteration $i');
      }
    });

    test('update skipped if license text not found', () async {
      String errorMessage = '';
      final LicenseHeader header = LicenseHeader();
      try {
        await header.getReplacementInfo(testFile9, 'test','test', 50);
      } on Exception catch(e) {
        errorMessage = e.toString();
      }
      expect(errorMessage, equals('Exception: License header expected in ${testFile9.path}, but not found!'));
    });

    test("update skipped if file can't be read", () async {
      String errorMessage = '';
      final LicenseHeader header = LicenseHeader();
      try {
        await header.getReplacementInfo(File('bad.txt'), 'test','test', 50);
      } on Exception catch(e) {
        errorMessage = e.toString();
      }
      expect(errorMessage, contains('Exception: License header expected, but error reading file - PathNotFoundException'));
    });

    test('license header can be rewritten on disk', () async {
      final LicenseHeader header = LicenseHeader();
      const String existingHeader = '''// This is some 2015 multiline license
// text that should be removed from the file.''';
      const String replacementHeader = '''// This is some 2015 multiline license
// text that should be added to the file.''';
      final File rewrittenFile = await header.rewriteLicenseHeader(
        testFile1, existingHeader, replacementHeader,);
      
      expect(await rewrittenFile.length(), greaterThan(0));
      
      final String existingContents = await testFile1.readAsString();
      expect(existingContents.substring(0, existingHeader.length), equals(existingHeader));
      
      final String rewrittenContents = await rewrittenFile.readAsString();
      expect(rewrittenContents.substring(0, replacementHeader.length), equals(replacementHeader));

      expect(existingContents.substring(existingHeader.length + 1),
        equals(rewrittenContents.substring(replacementHeader.length + 1)),);
    });

    test('license headers can be updated in bulk', () async {
      await _setupTestConfigFile();
      final LicenseConfig config = LicenseConfig.fromYamlFile(configFile);
      final LicenseHeader header = LicenseHeader();
      final Map<String,List<String>> results = await header.bulkUpdate(testDirectory,
        config,);
      
      final List<String>? includedPaths = results[LicenseHeader.includedPathsKey];
      expect(includedPaths, isNotNull);
      expect(includedPaths?.length, equals(7));
      // Order is not guaranteed
      expect(includedPaths?.contains(testFile1.path), true);
      expect(includedPaths?.contains(testFile2.path), true);
      expect(includedPaths?.contains(testFile3.path), true);
      expect(includedPaths?.contains(testFile7.path), true);
      expect(includedPaths?.contains(testFile8.path), true);
      expect(includedPaths?.contains(testFile9.path), true);
      expect(includedPaths?.contains(testFile10.path), true);

      final List<String>? updatedPaths = results[LicenseHeader.updatedPathsKey];
      expect(updatedPaths, isNotNull);
      // testFile9 and testFile10 are intentionally misconfigured and so they
      // won't be updated even though they are on the include list.
      expect(updatedPaths?.length, equals(5));
      // Order is not guaranteed
      expect(updatedPaths?.contains(testFile1.path), true);
      expect(updatedPaths?.contains(testFile2.path), true);
      expect(updatedPaths?.contains(testFile3.path), true);
      expect(updatedPaths?.contains(testFile7.path), true);
      expect(updatedPaths?.contains(testFile8.path), true);
    });
  });
}


Future<Map<String,String>> _getTestReplacementInfo(
  String existingLicenseText,
  File testFile,
  String replacementLicenseText,) async {
    final LicenseHeader header = LicenseHeader();
    final bytes = utf8.encode(existingLicenseText);
    return await header.getReplacementInfo(
      testFile,
      existingLicenseText,
      replacementLicenseText,
      bytes.length + 1,
    );
}

/// Sets up the config file
Future<void> _setupTestConfigFile() async {

  configFile = File(p.join(testDirectory.path, 'test_config.yaml'))
    ..createSync(recursive: true);

  final contents = 
'''---
# sequence of license text strings that should be matched against at the top of a file and removed. <value>, which normally represents a date, will be stored.
remove_licenses:
  - |
    // This is some <value1> multiline license
    // text that should be removed from the file.
  - |
    /* This is other <value2> multiline license
    text that should be removed from the file. */
  - |
    # This is more <value3> multiline license
    # text that should be removed from the file.
  - |
    // This is some multiline license text to
    // remove that does not contain a stored value.
# sequence of license text strings that should be added to the top of a file. {value} will be replaced.
add_licenses: 
  - |
    // This is some <value1> multiline license
    // text that should be added to the file.
  - |
    # This is other <value3> multiline license
    # text that should be added to the file.
  - |
    // This is some multiline license text to
    // add that does not contain a stored value.
# defines which files should have license text added or updated.
update_paths:
  # path(s) to recursively check for files to remove/add license
  include:
      - ${testDirectory.path}/repo_root
  # path(s) to recursively check for files to ignore
  exclude:
    # exclude everything in the /repo_root/sub_dir1 directory
    - ${testDirectory.path}/repo_root/sub_dir1/
    # exclude the given files
    - ${testDirectory.path}/repo_root/sub_dir2/exclude1.ext1
    - ${testDirectory.path}/repo_root/sub_dir2/sub_dir3/exclude2.ext2
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
  await testFile9.writeAsString(extraText);

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
  await testFile10.writeAsString(licenseText4 + extraText);
}