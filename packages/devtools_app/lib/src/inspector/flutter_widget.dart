// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library flutter_widget;

import '../ui/icons.dart';
import '../utils.dart';

class Category {
  const Category(this.label, this.icon);

  static Category accessibility = const Category(
    'Accessibility',
    AssetImageIcon(url: 'icons/inspector/balloonInformation.png'),
  );
  static Category animationAndMotion = const Category(
    'Animation and Motion',
    AssetImageIcon(url: 'icons/inspector/resume.png'),
  );
  static Category assetsImagesAndIcons = const Category(
    'Assets, Images, and Icons',
    AssetImageIcon(url: 'icons/inspector/any_type.png'),
  );
  static Category asyncCategory = const Category(
    'Async',
    AssetImageIcon(url: 'icons/inspector/threads.png'),
  );
  static const Category basics = Category(
    'Basics',
    null, // TODO(jacobr): add an icon.
  );
  static const Category cupertino = Category(
    'Cupertino (iOS-style widgets)',
    null, // TODO(jacobr): add an icon.
  );
  static Category input = const Category(
    'Input',
    AssetImageIcon(url: 'icons/inspector/renderer.png'),
  );
  static Category paintingAndEffects = const Category(
    'Painting and effects',
    AssetImageIcon(url: 'icons/inspector/colors.png'),
  );
  static Category scrolling = const Category(
    'Scrolling',
    AssetImageIcon(url: 'icons/inspector/scrollbar.png'),
  );
  static Category stack = const Category(
    'Stack',
    AssetImageIcon(url: 'icons/inspector/value.png'),
  );
  static Category styling = const Category(
    'Styling',
    AssetImageIcon(url: 'icons/inspector/atrule.png'),
  );
  static Category text = const Category(
    'Text',
    AssetImageIcon(url: 'icons/inspector/textArea.png'),
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
  final AssetImageIcon icon;

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
  final AssetImageIcon icon;

  static AssetImageIcon initIcon(Map<String, Object> json) {
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
