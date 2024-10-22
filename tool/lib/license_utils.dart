// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class LicenseConfig {
  /// Sequence of license text strings that should be matched against at the top
  /// of a file and removed.
  YamlList removeLicenses = YamlList();

  /// Sequence of license text strings that should be added to the top of a
  /// file.
  YamlList addLicenses = YamlList();

  /// Path(s) to recursively check for file to remove/add license text
  YamlList includePaths = YamlList();

  /// Path(s) to recursively check for files to ignore
  YamlList excludePaths = YamlList();

  /// Contains the extension (without a '.') and the associated indices
  /// of [removeLicenses] to remove and index of [addLicenses] to add for the
  /// file type.
  YamlMap fileTypes = YamlMap();

  /// Builds a [LicenseConfig] from the provided values.
  LicenseConfig.fromValues( {
    required this.removeLicenses,
    required this.addLicenses,
    required this.includePaths,
    required this.excludePaths,
    required this.fileTypes,
  });

  /// Reads the contents of the yaml [file] and parses it into a [LicenseConfig]
  /// object.
  LicenseConfig.fromYamlFile(File file) {
    final String yamlString = file.readAsStringSync();
    final YamlDocument yamlDoc = loadYamlDocument(yamlString);
    final YamlMap yaml = yamlDoc.contents as YamlMap;
    final YamlMap updatePaths = yaml['update_paths'];

    removeLicenses = yaml['remove_licenses'];
    addLicenses = yaml['add_licenses'];
    includePaths = updatePaths['include'];
    excludePaths = updatePaths['exclude'];
    fileTypes = updatePaths['file_types'];
  }

  /// Returns the list of indices for the given [ext] of [removeLicenses]
  /// containing the license text to remove.
  YamlList getRemoveIndicesForExtension(String ext) {
    final YamlMap fileType = fileTypes[_removeDotFromExtension(ext)];
    return fileType['remove'] as YamlList;
  }

  /// Returns the index for the given [ext] of [removeLicenses] containing the
  /// license text to remove.
  int getAddIndexForExtension(String ext) {
    final YamlMap fileType = fileTypes[_removeDotFromExtension(ext)];
    return fileType['add'];
  }

  /// Returns 'true' if the file should be excluded according to the config,
  /// 'false' otherwise.
  bool shouldExclude(File file) {
    bool included = false;
    for (final includePath in includePaths) {
      if (file.path.startsWith(includePath)) {
        included = true;
        break;
      }
    }
    bool excluded = false;
    for (final excludePath in excludePaths) {
      if (file.path.startsWith(excludePath)) {
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
      if (ext.startsWith('.')) {
        return ext.replaceFirst('.', '');
      }
      return ext;
  }
}

class LicenseHeader {
  /// If the [file] matches the given [existingLicenseText] within the first
  /// number of [byteCount] bytes, return the 'existing_header' and
  /// 'replacement_header' each with the stored value ('<value>'
  /// if configured, defaults to [defaultStoreValue] or current year)
  /// populated. For now, only up to one stored value is supported.
  /// If the file can't be read or no match is found, throws an exception.
  Future<Map<String, String>> getReplacementInfo(
    File file,
    String existingLicenseText,
    String replacementLicenseText,
    int byteCount, [
    defaultStoredValue,
  ]) async {
    final stream = file
        .openRead(0, byteCount)
        .transform(utf8.decoder)
        .handleError((e) => throw Exception(
            'License header expected, but error reading file - $e',),);
    await for (final content in stream) {
      // Return just the license headers for the simple case with no stored
      // value requested (i.e. content matches licenseText verbatim)
      if (content.contains(existingLicenseText)) {
        final String storedName = _parseStoredName(replacementLicenseText);
        replacementLicenseText = replacementLicenseText.replaceAll(
          '<$storedName>',
          defaultStoredValue ?? DateTime.now().year.toString(),
        );
        return {
          existingHeaderKey: existingLicenseText,
          replacementHeaderKey: replacementLicenseText,
        };
      }
      // Return a non-empty map for the case where there is a stored value
      // requested (i.e. when there is a '<value>' defined in the license text)
      final String storedName = _parseStoredName(existingLicenseText);
      if (storedName.isNotEmpty) {
        return _processHeaders(
          storedName,
          existingLicenseText,
          replacementLicenseText,
          content,
        );
      }
    }
    throw Exception('License header expected in ${file.path}, but not found!');
  }

  /// Returns a copy of the given [file] with the [existingHeader] replaced by
  /// the [replacementHeader]. Reads and writes the entire file contents all
  /// at once, so performance may degrade for large files.
  Future<File> rewriteLicenseHeader(
    File file,
    String existingHeader,
    String replacementHeader,
  ) async {
    final File rewrittenFile = File('${file.path}.tmp');
    // TODO: [mossmana] Convert to using a stream
    await file.readAsString().then((String contents) async {
      final String replacementContents = contents.replaceFirst(
        existingHeader,
        replacementHeader,
      );
      await rewrittenFile.writeAsString(replacementContents);
    });
    return rewrittenFile;
  }

  /// Bulk update license headers for files in the [directory] as configured
  /// in the [config]. Returns a list of file paths that were updated.
  Future<Map<String, List<String>>> bulkUpdate(
      Directory directory, LicenseConfig config,) async {
    final includedPaths = <String>[];
    final updatedPaths = <String>[];
    final List<File> files =
        directory.listSync(recursive: true).whereType<File>().toList();
    for (final file in files) {
      if (!config.shouldExclude(file)) {
        includedPaths.add(file.path);
        final String extension = p.extension(file.path);
        final YamlList removeIndices =
            config.getRemoveIndicesForExtension(extension);
        for (final removeIndex in removeIndices) {
          final String existingLicenseText = config.removeLicenses[removeIndex];
          final int addIndex = config.getAddIndexForExtension(extension);
          final String replacementLicenseText = config.addLicenses[addIndex];
          final int fileLength = await file.length();
          final int existingLicenseTextLength = existingLicenseText.length;
          const int buffer = 20;
          // Assume that the license text will be near the start of the file,
          // but add in some buffer.
          final byteCount = min(existingLicenseTextLength + buffer, fileLength);
          final Map<String, String> replacementInfo = await getReplacementInfo(
            file,
            existingLicenseText,
            replacementLicenseText,
            byteCount,
          );
          final String? existingHeader =
              replacementInfo[LicenseHeader.existingHeaderKey];
          final String? replacementHeader =
              replacementInfo[LicenseHeader.replacementHeaderKey];
          if (existingHeader != null && replacementHeader != null) {
            final File rewrittenFile = await rewriteLicenseHeader(
              file,
              existingHeader,
              replacementHeader,
            );
            final File backupFile = file.copySync('${file.path}.bak');
            if (await rewrittenFile.length() > 0) {
              file.writeAsStringSync(
                rewrittenFile.readAsStringSync(),
                mode: FileMode.writeOnly,
              );
              updatedPaths.add(file.path);
            }
            rewrittenFile.deleteSync();
            backupFile.deleteSync();
          }
        }
      }
    }
    return {
      includedPathsKey: includedPaths,
      updatedPathsKey: updatedPaths,
    };
  }

  static const existingHeaderKey = 'existing_header';
  static const replacementHeaderKey = 'replacement_header';
  static const includedPathsKey = 'included_paths';
  static const updatedPathsKey = 'update_paths';

  Map<String, String> _processHeaders(
    String storedName,
    String existingLicenseText,
    String replacementLicenseText,
    String content,
  ) {
    final String matchStr = RegExp.escape(existingLicenseText);
    final int storedNameIndex = matchStr.indexOf('<$storedName>');
    if (storedNameIndex != -1) {
      final String beforeStoredName = matchStr.substring(0, storedNameIndex);
      final String afterStoredName = matchStr
          .substring(storedNameIndex + storedName.length + 2)
          .trimRight();
      final RegExp storedMatcher = RegExp(
        r'' +
            beforeStoredName +
            r'((?<' +
            storedName +
            r'>\S+))' +
            afterStoredName,
      );
      if (storedMatcher.hasMatch(content)) {
        final RegExpMatch? match = storedMatcher.firstMatch(content);
        final String? existingHeaderValue = match?.group(0);
        final String? storedValue = match?.namedGroup(storedName);
        final String replacementHeaderValue = replacementLicenseText.replaceAll(
          '<$storedName>',
          storedValue ?? DateTime.now().year.toString(),
        );
        return {
          LicenseHeader.existingHeaderKey: existingHeaderValue ?? '',
          LicenseHeader.replacementHeaderKey: replacementHeaderValue,
        };
      }
    }
    return {};
  }

  // TODO: [mossmana] Add support for multiple stored names
  String _parseStoredName(String licenseText) {
    final storedMatch = RegExp(r'<(\S+)>').firstMatch(licenseText);
    final storedName = storedMatch?.group(1);
    return storedName ?? '';
  }
}
