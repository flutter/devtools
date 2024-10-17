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

  /// If the [file] has the given [licenseText] within the first number of
  /// [byteCount] bytes, return the stored name and value map which can be empty
  /// when no stored value is requested. (For now, only up to one stored value 
  /// is supported.) Otherwise, throw an exception.
  Future<Map<String,String>> getStoredValue(File file, String licenseText, int byteCount) async {
    final stream = file
      .openRead(0, byteCount)
      .transform(utf8.decoder)
      .handleError((e) => throw Exception('License header expected, but error reading file - $e'));
    await for (final content in stream) {
      // Return an empty map for the simple case with no stored value requested 
      // (i.e. content matches licenseText verbatim)
      if (content.contains(licenseText)) {
        return {};
      }
      // Return a non-empty map for the case where there is a stored value 
      // requested (i.e. when there is a '<value>' defined in the license text)
      final String storedName = _parseStoredName(licenseText);
      if (storedName.isNotEmpty) {
        final String storedValue = 
          _parseStoredValue(storedName, licenseText, content);
        return {storedName:storedValue};
      }
    }
    throw Exception('License header expected, but not found!');
  }

  String _parseStoredValue(String storedName, String licenseText, String content) {
    String matchStr = RegExp.escape(licenseText);
    String? storedValue = '';
    final int storedNameIndex = matchStr.indexOf('<$storedName>');
    if (storedNameIndex != -1) {
      final String beforeStoredName = matchStr.substring(0, storedNameIndex);
      final String afterStoredName = matchStr
        .substring(storedNameIndex + storedName.length + 2)
        .trimRight();
      final storedMatch = RegExp(r'' + beforeStoredName + 
        r'(?<' + storedName + r'>\S+)' + 
        afterStoredName + r'.*',);
      storedValue = storedMatch.firstMatch(content)?.namedGroup(storedName);
    }
    return storedValue ?? '';
  }

  // TODO: [mossmana] Add support for multiple stored names?
  String _parseStoredName(String licenseText) {
    final storedMatch = RegExp(r'<(\S+)>').firstMatch(licenseText);
    final storedName = storedMatch?.group(1);
    return storedName ?? '';
  }
}