// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library flutter_widget;

import 'dart:convert';

import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../ui/icons.dart';
import '../utils.dart';

class Category {
  const Category(this.label, this.icon);

  static const Category accessibility =
      Category('Accessibility', FlutterIcons.accessibility);
  static const Category animationAndMotion =
      Category('Animation and Motion', FlutterIcons.animation);
  static const Category assetsImagesAndIcons =
      Category('Assets, Images, and Icons', FlutterIcons.assets);
  static const Category asyncCategory =
      Category('Async', FlutterIcons.asyncUrlIcon);
  static const Category basics =
      Category('Basics', null); // TODO(jacobr): add an icon.
  static const Category cupertino = Category(
      'Cupertino (iOS-style widgets)', null); // TODO(jacobr): add an icon.
  static const Category input = Category('Input', FlutterIcons.input);
  static const Category paintingAndEffects =
      Category('Painting and effects', FlutterIcons.painting);
  static const Category scrolling =
      Category('Scrolling', FlutterIcons.scrollbar);
  static const Category stack = Category('Stack', FlutterIcons.stack);
  static const Category styling = Category('Styling', FlutterIcons.styling);
  static const Category text = Category('Text', FlutterIcons.text);

  static const List<Category> values = [
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
  final Icon icon;

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
  final Icon icon;

  static Icon initIcon(Map<String, Object> json) {
    final List<Object> categories = json['categories'];
    if (categories != null) {
      // TODO(pq): consider priority over first match.
      for (String label in categories) {
        final Category category = Category.forLabel(label);
        if (category != null) {
          final Icon icon = category.icon;
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

/// Catalog of widgets derived from widgets.json.
class Catalog {
  Catalog._(this.widgets);

  final Map<String, FlutterWidget> widgets;

  static Future<Catalog> _cachedCatalog;

  static Catalog get instance => _instance;
  static Catalog _instance;

  static Future<Catalog> load() {
    return _cachedCatalog ??= _loadHelper();
  }

  static Future<Catalog> _loadHelper() async {
    // Local copy of: https\://github.com/flutter/website/tree/master/_data/catalog/widget.json
    final Response response = await get('widgets.json');
    _instance = decode(response.body);
    return _instance;
  }

  @visibleForTesting
  static void setCatalog(Catalog catalog) {
    _instance = catalog;
    _cachedCatalog = Future.value(catalog);
  }

  static Catalog decode(String source) {
    final List<Object> json = jsonDecode(source);
    final Map<String, FlutterWidget> widgets = {};

    for (Map<String, Object> element in json) {
      final FlutterWidget widget = FlutterWidget(element);
      final String name = widget.name;
      // TODO(pq): add validation once json is repaired (https://github.com/flutter/flutter/issues/12930).
      // if (widgets.containsKey(name)) throw new IllegalStateException('Unexpected contents: widget `${name}` is duplicated');
      widgets[name] = widget;
    }
    return Catalog._(widgets);
  }

  List<FlutterWidget> get allWidgets {
    return widgets.values.toList();
  }

  FlutterWidget getWidget(String name) {
    return name != null ? widgets[name] : null;
  }

  String dumpJson() {
    return jsonEncode(json);
  }
}
