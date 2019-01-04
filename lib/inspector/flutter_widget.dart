// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library flutter_widget;

import 'dart:convert';

import 'package:http/http.dart';

import '../ui/icons.dart';
import '../utils.dart';

class Category {
  const Category(this.label, this.icon);

  static const Category ACCESSIBILITY =
      Category('Accessibility', FlutterIcons.Accessibility);
  static const Category ANIMATION_AND_MOTION =
      Category('Animation and Motion', FlutterIcons.Animation);
  static const Category ASSETS_IMAGES_AND_ICONS =
      Category('Assets, Images, and Icons', FlutterIcons.Assets);
  static const Category ASYNC = Category('Async', FlutterIcons.Async);
  static const Category BASICS =
      Category('Basics', null); // TODO(jacobr): add an icon.
  static const Category CUPERTINO = Category(
      'Cupertino (iOS-style widgets)', null); // TODO(jacobr): add an icon.
  static const Category INPUT = Category('Input', FlutterIcons.Input);
  static const Category PAINTING_AND_EFFECTS =
      Category('Painting and effects', FlutterIcons.Painting);
  static const Category SCROLLING =
      Category('Scrolling', FlutterIcons.Scrollbar);
  static const Category STACK = Category('Stack', FlutterIcons.Stack);
  static const Category STYLING = Category('Styling', FlutterIcons.Styling);
  static const Category TEXT = Category('Text', FlutterIcons.Text);

  static const List<Category> values = [
    ACCESSIBILITY,
    ANIMATION_AND_MOTION,
    ASSETS_IMAGES_AND_ICONS,
    ASYNC,
    BASICS,
    CUPERTINO,
    INPUT,
    PAINTING_AND_EFFECTS,
    SCROLLING,
    STACK,
    STYLING,
    TEXT,
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

  static Future<Catalog> load() async {
    final Map<String, FlutterWidget> widgets = {};
    // Local copy of: https\://github.com/flutter/website/tree/master/_data/catalog/widget.json
    final Response response = await get('widgets.json');
    final List<Object> json = jsonDecode(response.body);

    for (Map<String, Object> element in json) {
      final FlutterWidget widget = new FlutterWidget(element);
      final String name = widget.name;
      // TODO(pq): add validation once json is repaired (https://github.com/flutter/flutter/issues/12930).
      // if (widgets.containsKey(name)) throw new IllegalStateException('Unexpected contents: widget `${name}` is duplicated');
      widgets[name] = widget;
    }
    return new Catalog._(widgets);
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
