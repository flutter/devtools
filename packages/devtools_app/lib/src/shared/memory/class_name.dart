// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../primitives/simple_items.dart';
import '../ui/icons.dart';

/// Class types to color code and filter classes in tables.
enum ClassType {
  runtime(
    color: Color.fromARGB(255, 238, 109, 99),
    label: 'R',
    alias: '\$runtime',
    aliasDescription: 'Dart runtime classes',
    classTooltip: 'Dart runtime class',
  ),
  sdk(
    color: Color.fromARGB(255, 122, 188, 124),
    label: 'S',
    alias: '\$sdk',
    aliasDescription: 'Dart and Flutter SDK',
    classTooltip: 'SDK class',
  ),
  dependency(
    color: Color.fromARGB(255, 69, 153, 221),
    label: 'D',
    alias: '\$dependency',
    aliasDescription: 'dependencies',
    classTooltip: 'dependency',
  ),
  rootPackage(
    color: Color.fromARGB(255, 255, 200, 0),
    label: 'P',
    alias: '\$project',
    aliasDescription: 'classes of the project',
    classTooltip: 'project class',
  ),
  ;

  const ClassType({
    required this.color,
    required this.label,
    required this.alias,
    required this.aliasDescription,
    required this.classTooltip,
  });

  /// Color of the icon.
  final Color color;

  /// Label for the icon.
  final String label;

  /// Alias for filter string, should start with `$`.
  final String alias;

  /// Description to show in filter dialog.
  ///
  /// Should be in lower case.
  final String aliasDescription;

  /// String to be added to tooltip in table for class name.
  ///
  /// Should be in lower case.
  final String classTooltip;

  Widget get icon =>
      CircleIcon(color: color, text: label, textColor: Colors.white);
}

class _Json {
  static const className = 'n';
  static const library = 'l';
}

/// Fully qualified Class name.
///
/// Equal class names are not stored twice in memory.
class HeapClassName with Serializable {
  @visibleForTesting
  HeapClassName({required String? library, required this.className})
      : library = _normalizeLibrary(library);

  factory HeapClassName.fromJson(Map<String, dynamic> json) {
    return HeapClassName(
      library: json[_Json.library] as String?,
      className: json[_Json.className] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      _Json.className: className,
      _Json.library: library,
    };
  }

  static final _instances = <HeapClassName>{};

  static HeapClassName fromPath({
    required String? library,
    required String className,
  }) {
    final newInstance = HeapClassName(library: library, className: className);

    final existingInstance = _instances.lookup(newInstance);
    if (existingInstance != null) return existingInstance;

    _instances.add(newInstance);
    return newInstance;
  }

  static HeapClassName fromClassRef(ClassRef? classRef) => fromPath(
        library: _library(
          classRef?.library?.name,
          classRef?.library?.uri,
        ),
        className: classRef?.name ?? '',
      );

  static HeapClassName fromHeapSnapshotClass(HeapSnapshotClass? theClass) =>
      fromPath(
        library: _library(
          theClass?.libraryName,
          theClass?.libraryUri.toString(),
        ),
        className: theClass?.name ?? '',
      );

  static String _library(String? libName, String? libUrl) {
    if (libName != null && libName.isNotEmpty) return libName;
    return libUrl ?? '';
  }

  final String className;
  final String library;

  late final String fullName =
      library.isNotEmpty ? '$library/$shortName' : shortName;

  late final isSentinel = className == 'Sentinel' && library.isEmpty;

  late final isRoot = className == 'Root' && library.isEmpty;

  late final bool isNull = className == 'Null' && library == 'dart:core';

  /// Whether a class can hold a reference to an object
  /// without preventing garbage collection.
  late final bool isWeak = _isWeak(className, library);

  /// See [isWeak].
  static bool _isWeak(String className, String library) {
    // Classes that hold reference to an object without preventing
    // its collection.
    const weakHolders = {
      '_WeakProperty': '${PackagePrefixes.dart}core',
      '_WeakReferenceImpl': '${PackagePrefixes.dart}core',
      'FinalizerEntry': '${PackagePrefixes.dart}_internal',
    };

    if (!weakHolders.containsKey(className)) return false;
    if (weakHolders[className] == library) return true;

    // If a class lives in unexpected library, this can be because of
    // (1) name collision or (2) bug in this code.
    // Throwing exception in debug mode to verify option #2.
    // TODO(polina-c): create a way for users to add their weak classes
    // or detect weak references automatically, without hard coding
    // class names.
    assert(false, 'Unexpected library for $className: $library.');
    return false;
  }

  late final shortName =
      className == 'Context' && library == '' ? 'Closure Context' : className;

  ClassType? _cachedClassType;

  ClassType classType(String? rootPackage) =>
      _cachedClassType ??= _classType(rootPackage);

  ClassType _classType(String? rootPackage) {
    if (rootPackage != null && library.startsWith(rootPackage)) {
      return ClassType.rootPackage;
    }

    if (isPackageless) return ClassType.runtime;

    if (isDartOrFlutter) return ClassType.sdk;

    return ClassType.dependency;
  }

  bool get isCreatedByGoogle => isPackageless || isDartOrFlutter;

  /// True, if the library does not belong to a package.
  ///
  /// I.e. if the library does not have prefix
  /// `dart:` or `package:`.
  /// Examples of such classes: Code, Function, Class, Field,
  /// number_symbols/NumberSymbols, vector_math_64/Matrix4.
  late final bool isPackageless = library.isEmpty ||
      (!library.startsWith(PackagePrefixes.dart) &&
          !library.startsWith(PackagePrefixes.genericDartPackage));

  /// True, if the package has prefix `dart:` or has prefix `package:` and is
  /// published by Dart or Flutter org.
  late final isDartOrFlutter = _isDartOrFlutter(library);

  static bool _isDartOrFlutter(String library) {
    if (library.startsWith(PackagePrefixes.dart)) return true;
    if (library.startsWith(PackagePrefixes.flutterPackage)) return true;

    if (!library.startsWith(PackagePrefixes.genericDartPackage)) return false;

    final slashIndex = library.indexOf('/');
    if (slashIndex == -1) return false;
    final packageName = library.substring(
      PackagePrefixes.genericDartPackage.length,
      slashIndex,
    );

    return _dartAndFlutterPackages.contains(packageName);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is HeapClassName && other.fullName == fullName;
  }

  @override
  late final hashCode = fullName.hashCode;

  static String _normalizeLibrary(String? library) =>
      (library ?? '').trim().replaceFirst(
            RegExp('^${PackagePrefixes.dartInSnapshot}'),
            PackagePrefixes.dart,
          );

  bool matches(ClassRef ref) {
    return HeapClassName.fromClassRef(ref) == this;
  }

  static void dispose() {
    _instances.clear();
  }
}

/// Packages that are published by Google.
///
/// There is no active monitoring for new packages.
/// If you see something is missing here,
/// please, create a PR to add it.
/// TODO(polina-c): may be add a test that verifies if there are missing
/// packages.
const _dartAndFlutterPackages = {
  'flutter',
  'flutter_localizations',

  // https://pub.dev/publishers/dart.dev/packages
  'args',
  'async',
  'build',
  'characters',
  'collection',
  'convert',
  'crypto',
  'fake_async',
  'ffi',
  'fixnum',
  'grpc',
  'http_parser',
  'http',
  'http2',
  'intl_translation',
  'intl',
  'js',
  'leak_tracker',
  'logging',
  'matcher',
  'meta',
  'mockito',
  'os_detect',
  'path',
  'test',
  'typed_data',

  // https://pub.dev/publishers/flutter.dev/packages
  'android_alarm_manager',
  'android_intent',
  'animations',
  'battery',
  'battery_platform_interface',
  'bsdiff',
  'camera',
  'camera_android',
  'camera_avfoundation',
  'camera_platform_interface',
  'camera_web',
  'camera_windows',
  'cocoon_scheduler',
  'connectivity',
  'connectivity_for_web',
  'connectivity_macos',
  'connectivity_platform_interface',
  'cross_file',
  'css_colors',
  'cupertino_icons',
  'device_info',
  'device_info_platform_interface',
  'devtools',
  'devtools_app',
  'devtools_server',
  'devtools_shared',
  'devtools_testing',
  'e2e',
  'espresso',
  'extension_google_sign_in_as_googleapis_auth',
  'file_selector',
  'file_selector_ios',
  'file_selector_linux',
  'file_selector_macos',
  'file_selector_platform_interface',
  'file_selector_web',
  'file_selector_windows',
  'flutter_adaptive_scaffold',
  'flutter_image',
  'flutter_lints',
  'flutter_markdown',
  'flutter_plugin_android_lifecycle',
  'flutter_plugin_tools',
  'flutter_template_images',
  'go_router',
  'go_router_builder',
  'google_identity_services_web',
  'google_maps_flutter',
  'google_maps_flutter_android',
  'google_maps_flutter_ios',
  'google_maps_flutter_platform_interface',
  'google_maps_flutter_web',
  'google_sign_in',
  'google_sign_in_android',
  'google_sign_in_ios',
  'google_sign_in_platform_interface',
  'google_sign_in_web',
  'image_picker',
  'image_picker_android',
  'image_picker_for_web',
  'image_picker_ios',
  'image_picker_platform_interface',
  'image_picker_windows',
  'imitation_game',
  'in_app_purchase',
  'in_app_purchase_android',
  'in_app_purchase_ios',
  'in_app_purchase_platform_interface',
  'in_app_purchase_storekit',
  'integration_test',
  'ios_platform_images',
  'local_auth',
  'local_auth_android',
  'local_auth_ios',
  'local_auth_platform_interface',
  'local_auth_windows',
  'metrics_center',
  'multicast_dns',
  'package_info',
  'palette_generator',
  'path_provider',
  'path_provider_android',
  'path_provider_ios',
  'path_provider_linux',
  'path_provider_macos',
  'path_provider_platform_interface',
  'path_provider_windows',
  'pigeon',
  'plugin_platform_interface',
  'pointer_interceptor',
  'quick_actions',
  'quick_actions_android',
  'quick_actions_ios',
  'quick_actions_platform_interface',
  'rfw',
  'sensors',
  'share',
  'shared_preferences',
  'shared_preferences_android',
  'shared_preferences_foundation',
  'shared_preferences_ios',
  'shared_preferences_linux',
  'shared_preferences_macos',
  'shared_preferences_platform_interface',
  'shared_preferences_web',
  'shared_preferences_windows',
  'snippets',
  'standard_message_codec',
  'url_launcher',
  'url_launcher_android',
  'url_launcher_ios',
  'url_launcher_linux',
  'url_launcher_macos',
  'url_launcher_platform_interface',
  'url_launcher_web',
  'url_launcher_windows',
  'video_player',
  'video_player_android',
  'video_player_avfoundation',
  'video_player_platform_interface',
  'video_player_web',
  'web_benchmarks',
  'webview_flutter',
  'webview_flutter_android',
  'webview_flutter_platform_interface',
  'webview_flutter_web',
  'webview_flutter_wkwebview',
  'wifi_info_flutter',
  'wifi_info_flutter_platform_interface',
  'xdg_directories',

  // https://pub.dev/publishers/material.io/packages
  'dynamic_color',
  'adaptive_breakpoints',
  'adaptive_navigation',
  'adaptive_components',
  'material_color_utilities',
  'google_fonts',
};
