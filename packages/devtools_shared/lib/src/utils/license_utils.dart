import 'dart:io';

import 'package:yaml/yaml.dart';

class LicenseConfig {

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

  YamlList getRemoveIndicesForExtension(String ext) {
    final YamlMap fileType = fileTypes[ext];
    return fileType['remove'] as YamlList;
  }

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