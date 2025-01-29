// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import 'theme/theme.dart';

/// A widget that renders either an [icon] from a font glyph or an [iconAsset]
/// from the app bundle.
final class DevToolsIcon extends StatelessWidget {
  DevToolsIcon({super.key, this.icon, this.iconAsset, this.color, double? size})
      : assert(
          (icon == null) != (iconAsset == null),
          'Exactly one of icon and iconAsset must be specified.',
        ),
        size = size ?? defaultIconSize;

  /// The icon to use for this screen's tab.
  ///
  /// Exactly one of [icon] and [iconAsset] must be non-null.
  final IconData? icon;

  /// The icon asset path to render as the icon for this screen's tab.
  ///
  /// Exactly one of [icon] and [iconAsset] must be non-null.
  final String? iconAsset;

  final double size;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.onSurface;
    return icon != null
        ? Icon(icon, size: size, color: color)
        : AssetImageIcon(
            asset: iconAsset!,
            height: size,
            width: size,
            color: color,
          );
  }
}

/// A widget that renders an [asset] image styled as an icon.
final class AssetImageIcon extends StatelessWidget {
  const AssetImageIcon({
    super.key,
    required this.asset,
    this.color,
    double? height,
    double? width,
  })  : _width = width,
        _height = height;

  final String asset;
  final Color? color;
  final double? _height;
  final double? _width;

  double get width => _width ?? defaultIconSize;
  double get height => _height ?? defaultIconSize;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: AssetImage(asset),
      height: height,
      width: width,
      fit: BoxFit.fill,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }
}
