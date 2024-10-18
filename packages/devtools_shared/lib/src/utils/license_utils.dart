import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

class LicenseConfig {

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

  // Builds a [LicenseConfig] from the provided values.
  LicenseConfig.fromValues(
    this.removeLicenses,
    this.addLicenses,
    this.includePaths,
    this.excludePaths,
    this.fileTypes,
  );

  /// Returns the list of indices for the given [ext] of [removeLicenses] 
  /// containing the license text to remove.
  YamlList getRemoveIndicesForExtension(String ext) {
    final YamlMap fileType = fileTypes[ext];
    return fileType['remove'] as YamlList;
  }

  /// Returns the index for the given [ext] of [removeLicenses] containing the 
  /// license text to remove.
  int getAddIndexForExtension(String ext) {
    final YamlMap fileType = fileTypes[ext];
    return fileType['add'];
  }

  YamlList removeLicenses = YamlList();
  YamlList addLicenses = YamlList();
  YamlList includePaths = YamlList();
  YamlList excludePaths = YamlList();
  YamlMap fileTypes = YamlMap();
}

class LicenseHeader {

  /// If the [file] matches the given [existingLicenseText] within the first
  /// number of [byteCount] bytes, return the 'existing_header' and
  /// 'replacement_header' each with the stored value ('<value>'
  /// if configured, defaults to [defaultStoreValue] or current year)
  /// populated. For now, only up to one stored value is supported.
  /// If the file can't be read or no match is found, throw an exception.
  Future<Map<String,String>> getReplacementInfo(
    File file,
    String existingLicenseText,
    String replacementLicenseText, 
    int byteCount,
    [defaultStoredValue,]) async {
    final stream = file
      .openRead(0, byteCount)
      .transform(utf8.decoder)
      .handleError((e) => throw Exception('License header expected, but error reading file - $e'));
    await for (final content in stream) {
      // Return just the license headers for the simple case with no stored
      // value requested (i.e. content matches licenseText verbatim)
      if (content.contains(existingLicenseText)) {
        final String storedName = _parseStoredName(replacementLicenseText);
        replacementLicenseText = 
          replacementLicenseText.replaceAll(
            '<$storedName>',
            defaultStoredValue ?? DateTime.now().year.toString(),
          );
        return {
          'existing_header':existingLicenseText,
          'replacement_header':replacementLicenseText,
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
            content,);
      }
    }
    throw Exception('License header expected, but not found!');
  }

  static const String existingHeaderKey = 'existing_header';
  static const String replacementHeaderKey = 'replacement_header';

  Map<String,String> _processHeaders(
    String storedName,
    String existingLicenseText,
    String replacementLicenseText,
    String content,) {
    final String matchStr = RegExp.escape(existingLicenseText);
    final int storedNameIndex = matchStr.indexOf('<$storedName>');
    if (storedNameIndex != -1) {
      final String beforeStoredName = matchStr.substring(0, storedNameIndex);
      final String afterStoredName = matchStr
        .substring(storedNameIndex + storedName.length + 2)
        .trimRight();
      final RegExp storedMatcher = RegExp(r'' + beforeStoredName + 
        r'((?<' + storedName + r'>\S+))' + 
        afterStoredName,);
      if (storedMatcher.hasMatch(content)) {
        final RegExpMatch? match = storedMatcher.firstMatch(content);
        final String? existingHeaderValue = match?.group(0);
        final String? storedValue = match?.namedGroup(storedName);
        final String replacementHeaderValue = 
          replacementLicenseText.replaceAll(
            '<$storedName>', 
            storedValue ?? DateTime.now().year.toString(),
          );
        return {LicenseHeader.existingHeaderKey:existingHeaderValue ?? '',
          LicenseHeader.replacementHeaderKey:replacementHeaderValue,
        }; 
      }
    }
    return {};
  }

  // TODO: [mossmana] Add support for multiple stored names?
  String _parseStoredName(String licenseText) {
    final storedMatch = RegExp(r'<(\S+)>').firstMatch(licenseText);
    final storedName = storedMatch?.group(1);
    return storedName ?? '';
  }
}