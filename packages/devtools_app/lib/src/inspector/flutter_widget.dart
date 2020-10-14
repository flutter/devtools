// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library flutter_widget;

import 'package:flutter/material.dart';

import '../ui/icons.dart';
import '../utils.dart';

class Category {
  const Category(this.label, this.icon);

  static Category accessibility = Category(
    'Accessibility',
    createImageIcon('icons/inspector/balloonInformation.png'),
  );
  static Category animationAndMotion = Category(
    'Animation and Motion',
    createImageIcon('icons/inspector/resume.png'),
  );
  static Category assetsImagesAndIcons = Category(
    'Assets, Images, and Icons',
    createImageIcon('icons/inspector/any_type.png'),
  );
  static Category asyncCategory = Category(
    'Async',
    createImageIcon('icons/inspector/threads.png'),
  );
  static const Category basics = Category(
    'Basics',
    null, // TODO(jacobr): add an icon.
  );
  static const Category cupertino = Category(
    'Cupertino (iOS-style widgets)',
    null, // TODO(jacobr): add an icon.
  );
  static Category input = Category(
    'Input',
    createImageIcon('icons/inspector/renderer.png'),
  );
  static Category paintingAndEffects = Category(
    'Painting and effects',
    createImageIcon('icons/inspector/colors.png'),
  );
  static Category scrolling = Category(
    'Scrolling',
    createImageIcon('icons/inspector/scrollbar.png'),
  );
  static Category stack = Category(
    'Stack',
    createImageIcon('icons/inspector/value.png'),
  );
  static Category styling = Category(
    'Styling',
    createImageIcon('icons/inspector/atrule.png'),
  );
  static Category text = Category(
    'Text',
    createImageIcon('icons/inspector/textArea.png'),
  );

  static List<Category> values = [
    accessibility,
    animationAndMotion,
    assetsImagesAndIcons,
    asyncCategory,
    basics,
    cupertino,
    input,
    paintingAndEffects,
    scrolling,
    stack,
    styling,
    text,
  ];

  final String label;
  final Image icon;

  static Map<String, Category> _categories;

  static Category forLabel(String label) {
    if (_categories == null) {
      _categories = {};
      for (var category in values) {
        _categories[category.label] = category;
      }
    }
    return _categories[label];
  }
}

class FlutterWidget {
  FlutterWidget(this.json) : icon = initIcon(json);

  final Map<String, Object> json;
  final Image icon;

  static Image initIcon(Map<String, Object> json) {
    final List<Object> categories = json['categories'];
    if (categories != null) {
      // TODO(pq): consider priority over first match.
      for (String label in categories) {
        final Category category = Category.forLabel(label);
        if (category != null) {
          final icon = category.icon;
          if (icon != null) return icon;
        }
      }
    }
    return null;
  }

  String get name => JsonUtils.getStringMember(json, 'name');

  List<String> get categories => JsonUtils.getValues(json, 'categories');

  List<String> get subCategories => JsonUtils.getValues(json, 'subcategories');
}
