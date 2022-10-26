// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../../primitives/simple_items.dart';

@immutable
class HeapClassName {
  HeapClassName({required this.className, required library})
      : library = _normalizeLibrary(library) {
    assert(
      !isCore || !isDartOrFlutter,
      'isCore and isDartOrFlutter must be exclusive',
    );
  }

  HeapClassName.fromClassRef(ClassRef? classRef)
      : this(
          library: _library(
            classRef?.library?.name,
            classRef?.library?.uri,
          ),
          className: classRef?.name ?? '',
        );

  HeapClassName.fromHeapSnapshotClass(HeapSnapshotClass? theClass)
      : this(
          library: _library(
            theClass?.libraryName,
            theClass?.libraryUri.toString(),
          ),
          className: theClass?.name ?? '',
        );

  static String _library(String? libName, String? libUrl) {
    libName ??= '';
    if (libName.isNotEmpty) return libName;
    return libUrl ?? '';
  }

  final String className;
  final String library;

  String get fullName => library.isNotEmpty ? '$library/$className' : className;

  bool get isSentinel => className == 'Sentinel' && library.isEmpty;

  /// Detects if a class can retain an object from garbage collection.
  bool get isWeakEntry {
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

  /// True, if the library is a core library.
  ///
  /// I.e. if the library name is empty or does not have prefix
  /// `dart:` or `package:`.
  bool get isCore =>
      library.isEmpty ||
      (!library.startsWith(PackagePrefixes.dart) &&
          !library.startsWith(PackagePrefixes.genericDartPackage));

  /// True, if the package has prefix `dart:` or has perfix `package:` and is
  /// published by Dart or Flutter org.
  bool get isDartOrFlutter {
    if (library.startsWith(PackagePrefixes.dart)) return true;

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
  int get hashCode => fullName.hashCode;

  static String _normalizeLibrary(String library) =>
      library.trim().replaceFirst(
            RegExp('^${PackagePrefixes.dartInSnapshot}'),
            PackagePrefixes.dart,
          );
}

/// Packages that are published by dart.dev or flutter.dev.
///
/// There is no active monitoring for new packages.
/// If you see something is missing here,
/// please, create a PR to add it.
/// TODO(polina-c): add a test that verifies if there are missing
/// packages.
const _dartAndFlutterPackages = {
  'flutter',

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
};
