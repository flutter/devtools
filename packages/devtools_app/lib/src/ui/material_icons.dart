// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library material_icons;

import 'fake_flutter/fake_flutter.dart';
import 'icons.dart';
import 'theme.dart';

const Icon clearIcon = MaterialIcon('block', defaultButtonIconColor);

const Icon exitIcon = MaterialIcon('clear', defaultButtonIconColor);

const Icon exportIcon = MaterialIcon('file_download', defaultButtonIconColor);

const Icon recordPrimary =
    MaterialIcon('fiber_manual_record', defaultPrimaryButtonIconColor);

const Icon record = MaterialIcon('fiber_manual_record', defaultButtonIconColor);

const Icon stop = MaterialIcon('stop', defaultButtonIconColor);

/// Class for icons consistent with
/// https://docs.flutter.io/flutter/material/Icons-class.html
class MaterialIcon extends Icon {
  const MaterialIcon(
    this.text,
    this.color, {
    this.fontSize = 18,
    this.iconWidth = 18,
    this.angle = 0.0,
  });

  final String text;
  final Color color;
  final int fontSize;
  final double angle;
  @override
  final int iconWidth;
}

class FlutterMaterialIcons {
  FlutterMaterialIcons._();

  static final Map<String, MaterialIcon> _iconCache = {};

  static Icon getIconForCodePoint(int charCode) {
    final String code = String.fromCharCode(charCode);
    return _iconCache.putIfAbsent(
        code, () => MaterialIcon(code, defaultForeground));
  }
}
