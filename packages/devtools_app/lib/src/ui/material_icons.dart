// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library material_icons;

import 'package:meta/meta.dart';

import 'fake_flutter/fake_flutter.dart' hide required;
import 'icons.dart';
import 'theme.dart';

final DevToolsIcon clearIcon = MaterialIcon('block', defaultButtonIconColor,
    codePoint: Icons.block.codePoint);

final DevToolsIcon exitIcon = MaterialIcon('clear', defaultButtonIconColor,
    codePoint: Icons.clear.codePoint);

final DevToolsIcon exportIcon = MaterialIcon(
    'file_download', defaultButtonIconColor,
    codePoint: Icons.file_download.codePoint);

final DevToolsIcon recordPrimary = MaterialIcon(
    'fiber_manual_record', defaultPrimaryButtonIconColor,
    codePoint: Icons.fiber_manual_record.codePoint);

final DevToolsIcon record = MaterialIcon(
    'fiber_manual_record', defaultButtonIconColor,
    codePoint: Icons.fiber_manual_record.codePoint);

final DevToolsIcon stop = MaterialIcon('stop', defaultButtonIconColor,
    codePoint: Icons.stop.codePoint);

// TODO(jacobr): remove this class completely once the migration to Flutter
// desktop is complete and just use Flutter native support for Material icons.
/// Class for icons consistent with
/// https://docs.flutter.io/flutter/material/Icons-class.html
class MaterialIcon extends DevToolsIcon {
  const MaterialIcon(
    this.text,
    this.color, {
    @required this.codePoint,
    this.fontSize = 18,
    this.iconWidth = 18,
    this.angle = 0.0,
  });

  final String text;

  /// If the codePoint is specified, use it directly on platforms that can run
  /// Flutter natively rather than depending on the text.
  final int codePoint;
  final Color color;
  final int fontSize;
  final double angle;
  @override
  final double iconWidth;
}

class FlutterMaterialIcons {
  FlutterMaterialIcons._();

  static final Map<String, MaterialIcon> _iconCache = {};

  static DevToolsIcon getIconForCodePoint(int charCode) {
    final String code = String.fromCharCode(charCode);
    return _iconCache.putIfAbsent(
        code, () => MaterialIcon(code, defaultForeground, codePoint: charCode));
  }
}
