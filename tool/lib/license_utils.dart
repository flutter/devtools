// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// This class contains config file related business logic for
/// [license_utils.dart].
///
/// The [LicenseConfig] reads in config data from a YAML file into an
/// object that can be used to update license headers.
///
/// The 'repo wide check' test in [license_utils_test.dart] runs this logic to
/// ensure that proper license headers are enforced.
///
/// It is also designed so that it be used by the dt command or
/// from a standalone script/application in the future.
///
/// Sample config file:
/// ```yaml
/// # sequence of license text strings that should be matched against at the top of a file and removed. <value>, which normally represents a date, will be stored.
/// remove_licenses:
///   - |
///     // This is some <value1> multiline license
///     // text that should be removed from the file.
///   - |
///     /* This is other <value2> multiline license
///     text that should be removed from the file. */
///   - |
///     # This is more <value3> multiline license
///     # text that should be removed from the file.
///   - |
///     // This is some multiline license text to
///     // remove that does not contain a stored value.
/// # sequence of license text strings that should be added to the top of a file. {value} will be replaced.
/// add_licenses:
///   - |
///     // This is some <value1> multiline license
///     // text that should be added to the file.
///   - |
///     # This is other <value3> multiline license
///     # text that should be added to the file.
///   - |
///     // This is some multiline license text to
///     // add that does not contain a stored value.
/// # defines which files should have license text added or updated.
/// update_paths:
///   # path(s) to recursively check for files to remove/add license
///   include:
///       - /repo_root
///   # path(s) to recursively check for files to ignore
///   exclude:
///     # exclude everything in the /repo_root/sub_dir1 directory
///     - /repo_root/sub_dir1/
///     # exclude the given files
///     - /repo_root/sub_dir2/exclude1.ext1
///     - /repo_root/sub_dir2/sub_dir3/exclude2.ext2
///   file_types:
///     # extension
///     ext1:
///       # one or more indices of remove_licenses to remove
///       remove:
///         - 0
///         - 1
///       # index of add_licenses to add
///       add: 0
///     ext2:
///       remove:
///         - 2
///       add: 1
/// ```
class LicenseConfig {
  /// Builds a [LicenseConfig] from the provided values.
  LicenseConfig({
    required this.removeLicenses,
    required this.addLicenses,
    required this.includePaths,
    required this.excludePaths,
    required this.fileTypes,
  });

  /// Reads the contents of the yaml [file] and parses it into a [LicenseConfig]
  /// object.
  factory LicenseConfig.fromYamlFile(File file) {
    final yamlString = file.readAsStringSync();
    final yamlDoc = loadYamlDocument(yamlString);
    final yaml = yamlDoc.contents as YamlMap;
    final updatePaths = yaml['update_paths'];

    return LicenseConfig(
      removeLicenses: yaml['remove_licenses'],
      addLicenses: yaml['add_licenses'],
      includePaths: updatePaths['include'],
      excludePaths: updatePaths['exclude'],
      fileTypes: updatePaths['file_types'],
    );
  }

  /// Sequence of license text strings that should be matched against at the top
  /// of a file and removed.
  final YamlList removeLicenses;

  /// Sequence of license text strings that should be added to the top of a
  /// file.
  final YamlList addLicenses;

  /// Path(s) to recursively check for file to remove/add license text
  final YamlList includePaths;

  /// Path(s) to recursively check for files to ignore
  final YamlList excludePaths;

  /// Contains the extension (without a '.') and the associated indices
  /// of [removeLicenses] to remove and index of [addLicenses] to add for the
  /// file type.
  final YamlMap fileTypes;

  /// Returns the list of indices for the given [ext] of [removeLicenses]
  /// containing the license text to remove.
  YamlList getRemoveIndicesForExtension(String ext) {
    final fileType = fileTypes[_removeDotFromExtension(ext)];
    return fileType['remove'] as YamlList;
  }

  /// Returns the index for the given [ext] of [addLicenses] containing the
  /// license text to add.
  int getAddIndexForExtension(String ext) {
    final fileType = fileTypes[_removeDotFromExtension(ext)];
    return fileType['add'];
  }

  /// Returns whether the file should be excluded according to the config.
  bool shouldExclude(File file) {
    var included = false;
    for (final includePath in includePaths) {
      if (p.equals(includePath, file.path) ||
          p.isWithin(includePath, file.path)) {
        included = true;
        break;
      }
    }
    var excluded = false;
    for (final excludePath in excludePaths) {
      if (p.equals(excludePath, file.path) ||
          p.isWithin(excludePath, file.path)) {
        excluded = true;
        break;
      }
    }
    return !included || excluded;
  }

  /// The config expects an extension without a starting dot, so remove
  /// any that might exist (e.g. in the extension that is returned by
  /// [p.extension]).
  String _removeDotFromExtension(String ext) {
    if (ext.startsWith('.') && ext.length > 1) {
      return ext.substring(1);
    }
    return ext;
  }
}

/// This class contains license update related business logic for
/// [license_utils.dart].
///
/// The [LicenseHeader] uses config data from [LicenseConfig] to update
/// license text in configured files.
class LicenseHeader {
  /// Processes the [file] for replacement information.
  ///
  /// If the [file] contains the given [existingLicenseText] within the first
  /// number of [byteCount] bytes, return a Record containing:
  /// - existingHeader: existing license header text
  /// - replacementHeader: replacement license header text
  ///
  /// If the file can't be read or no match is found, throws an exception.
  ///
  /// Note on stored values
  /// ---------------------
  /// Any instance of &lt;value&gt; in the replacement license text will be
  /// replaced with either:
  /// 1. the stored value parsed from the existing header
  /// 2. [defaultStoredValue], if no value is parsed
  /// 3. current year, if no [defaultStoredValue] is provided
  ///
  /// For now, only up to one stored value is supported.
  Future<({String existingHeader, String replacementHeader})>
  getReplacementInfo({
    required File file,
    required String existingLicenseText,
    required String replacementLicenseText,
    required int byteCount,
    String? defaultStoredValue,
  }) async {
    final stream = file
        .openRead(0, byteCount)
        .transform(utf8.decoder)
        .handleError(
          (e) =>
              throw StateError(
                'License header expected, but error reading file - $e',
              ),
        );
    await for (final content in stream) {
      // Return just the license headers for the simple case with no stored
      // value requested (i.e. content matches licenseText verbatim)
      if (content.contains(existingLicenseText)) {
        final storedName = _parseStoredName(replacementLicenseText);
        replacementLicenseText = replacementLicenseText.replaceAll(
          '<$storedName>',
          defaultStoredValue ?? DateTime.now().year.toString(),
        );
        return (
          existingHeader: existingLicenseText,
          replacementHeader: replacementLicenseText,
        );
      }
      // Return a non-empty map for the case where there is a stored value
      // requested (i.e. when there is a '<value>' defined in the license text)
      final storedName = _parseStoredName(existingLicenseText);
      if (storedName.isNotEmpty) {
        return _processHeaders(
          storedName: storedName,
          existingLicenseText: existingLicenseText,
          replacementLicenseText: replacementLicenseText,
          content: content,
        );
      }
    }
    throw StateError('License header expected in ${file.path}, but not found!');
  }

  /// Returns a copy of the given [file] with the [existingHeader] replaced by
  /// the [replacementHeader].
  ///
  /// Reads and writes the entire file contents all at once, so performance may
  /// degrade for large files.
  File rewriteLicenseHeader({
    required File file,
    required String existingHeader,
    required String replacementHeader,
  }) {
    final rewrittenFile = File('${file.path}.tmp');
    final contents = file.readAsStringSync();
    final replacementContents = contents.replaceFirst(
      existingHeader,
      replacementHeader,
    );
    rewrittenFile.writeAsStringSync(replacementContents, flush: true);
    return rewrittenFile;
  }

  /// Bulk update license headers for files in the [directory] as configured
  /// in the [config] and return a processed paths Record containing:
  /// - list of included paths
  /// - list of updated paths
  ///
  /// If [dryRun] is set, return the processed paths Record, but no files will
  /// be actually be updated.
  Future<({List<String> includedPaths, List<String> updatedPaths})> bulkUpdate({
    required Directory directory,
    required LicenseConfig config,
    bool dryRun = false,
  }) async {
    final includedPathsList = <String>[];
    final updatedPathsList = <String>[];
    final files =
        directory.listSync(recursive: true).whereType<File>().toList();
    for (final file in files) {
      if (!config.shouldExclude(file)) {
        includedPathsList.add(file.path);
        final extension = p.extension(file.path);
        final removeIndices = config.getRemoveIndicesForExtension(extension);
        for (final removeIndex in removeIndices) {
          final existingLicenseText = config.removeLicenses[removeIndex];
          final addIndex = config.getAddIndexForExtension(extension);
          final replacementLicenseText = config.addLicenses[addIndex];
          final fileLength = file.lengthSync();
          const bufferSize = 20;
          // Assume that the license text will be near the start of the file,
          // but add in some buffer.
          final byteCount = min(
            bufferSize + existingLicenseText.length,
            fileLength,
          );
          final replacementInfo = await getReplacementInfo(
            file: file,
            existingLicenseText: existingLicenseText,
            replacementLicenseText: replacementLicenseText,
            byteCount: byteCount as int,
          );
          if (replacementInfo.existingHeader.isNotEmpty &&
              replacementInfo.replacementHeader.isNotEmpty) {
            if (dryRun) {
              updatedPathsList.add(file.path);
            } else {
              final rewrittenFile = rewriteLicenseHeader(
                file: file,
                existingHeader: replacementInfo.existingHeader,
                replacementHeader: replacementInfo.replacementHeader,
              );
              if (rewrittenFile.lengthSync() > 0) {
                file.writeAsStringSync(
                  rewrittenFile.readAsStringSync(),
                  mode: FileMode.writeOnly,
                  flush: true,
                );
                updatedPathsList.add(file.path);
              }
              rewrittenFile.deleteSync();
            }
          }
        }
      }
    }
    return (includedPaths: includedPathsList, updatedPaths: updatedPathsList);
  }

  ({String existingHeader, String replacementHeader}) _processHeaders({
    required String storedName,
    required String existingLicenseText,
    required String replacementLicenseText,
    required String content,
  }) {
    final matchStr = RegExp.escape(existingLicenseText);
    final storedNameIndex = matchStr.indexOf('<$storedName>');
    if (storedNameIndex != -1) {
      final beforeStoredName = matchStr.substring(0, storedNameIndex);
      final afterStoredName =
          matchStr
              .substring(storedNameIndex + storedName.length + 2)
              .trimRight();
      final storedMatcher = RegExp(
        r'' +
            beforeStoredName +
            r'((?<' +
            storedName +
            r'>\S+))' +
            afterStoredName,
      );
      if (storedMatcher.hasMatch(content)) {
        final match = storedMatcher.firstMatch(content);
        final existingHeaderValue = match?.group(0);
        final storedValue = match?.namedGroup(storedName);
        final replacementHeaderValue = replacementLicenseText.replaceAll(
          '<$storedName>',
          storedValue ?? DateTime.now().year.toString(),
        );
        return (
          existingHeader: existingHeaderValue ?? '',
          replacementHeader: replacementHeaderValue,
        );
      }
    }
    return const (existingHeader: '', replacementHeader: '');
  }

  // TODO(mossmana) Add support for multiple stored names
  String _parseStoredName(String licenseText) {
    final storedMatch = RegExp(r'<(\S+)>').firstMatch(licenseText);
    final storedName = storedMatch?.group(1);
    return storedName ?? '';
  }
}
