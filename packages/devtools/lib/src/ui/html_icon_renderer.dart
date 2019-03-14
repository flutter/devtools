// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Library to render icons to an Canvas or as HTML elements.
library icon_renderer;

import 'dart:async';
import 'dart:html';

import 'package:meta/meta.dart';

import 'elements.dart';
import 'environment.dart' as environment;
import 'fake_flutter/fake_flutter.dart';
import 'flutter_html_shim.dart';
import 'icons.dart';
import 'material_icons.dart';
import 'theme.dart';
import 'ui_utils.dart';

final Expando<HtmlIconRenderer> rendererExpando = Expando('IconRenderer');

typedef DrawIconImageCallback = void Function(CanvasRenderingContext2D element);

abstract class HtmlIconRenderer<T extends Icon> {
  HtmlIconRenderer(this.icon);

  CanvasImageSource get image;

  bool get loaded => image != null;

  CoreElement createCoreElement() {
    final element = createElement();
    return CoreElement.from(element);
  }

  Element createElement() {
    // All CanvasImageSource types are elements but until Dart has Union types
    // that is hard to express.
    final Object canvasSource = createCanvasSource();
    final Element element = canvasSource;

    element.style
      ..width = '${icon.iconWidth}px'
      ..height = '${icon.iconHeight}px';
    element.classes.add('flutter-icon');
    return element;
  }

  @protected
  CanvasImageSource createCanvasSource();

  Future<CanvasImageSource> loadImage();

  final T icon;

  int get iconWidth => icon.iconWidth;
  int get iconHeight => icon.iconHeight;
}

class _UrlIconRenderer extends HtmlIconRenderer<UrlIcon> {
  _UrlIconRenderer(UrlIcon icon)
      : src = _maybeRewriteIconUrl(icon.src),
        super(icon);

  static String _maybeRewriteIconUrl(String url) {
    if (environment.devicePixelRatio > 1 &&
        url.endsWith('.png') &&
        !url.endsWith('@2x.png')) {
      // By convention icons all have high DPI verisons with @2x added to the
      // file name.
      return '${url.substring(0, url.length - 4)}@2x.png';
    }
    return url;
  }

  final String src;

  @override
  CanvasImageSource get image => _image;
  ImageElement _image;

  Future<CanvasImageSource> _imageFuture;

  @override
  ImageElement createCanvasSource() => ImageElement(src: src);

  @override
  Element createElement() {
    // We use a div rather than an ImageElement to display the image directly
    // in the DOM as backgroundImage styling is more flexible.
    final element = Element.div();
    element.classes.add('flutter-icon');
    element.style
      ..width = '${icon.iconWidth}px'
      ..height = '${icon.iconHeight}px'
      ..backgroundImage = 'url($src)';
    if (icon.invertDark && isDarkTheme) {
      element.style.filter = 'invert(1)';
    }
    return element;
  }

  @override
  Future<CanvasImageSource> loadImage() {
    if (_imageFuture != null) {
      return _imageFuture;
    }
    final Completer<CanvasImageSource> completer = Completer();
    final imageElement = createCanvasSource();
    imageElement.onLoad.listen((e) {
      _image = imageElement;
      completer.complete(imageElement);
    });
    document.head.append(imageElement);
    _imageFuture = completer.future;
    return _imageFuture;
  }
}

class _ColorIconRenderer extends HtmlIconRenderer<ColorIcon> {
  _ColorIconRenderer(ColorIcon icon) : super(icon);

  static const int iconMargin = 1;

  Color get color => icon.color;

  @override
  CanvasElement createCanvasSource() {
    final canvas = createHighDpiCanvas(iconWidth, iconHeight);
    final context = canvas.context2D;
    context.clearRect(0, 0, iconWidth, iconHeight);

    // draw a black and gray grid to use as the background to disambiguate
    // opaque colors from translucent colors.
    context
      ..fillStyle = colorToCss(defaultBackground)
      ..fillRect(iconMargin, iconMargin, iconWidth - iconMargin * 2,
          iconHeight - iconMargin * 2)
      ..fillStyle = colorToCss(grey)
      ..fillRect(iconMargin, iconMargin, iconWidth / 2 - iconMargin,
          iconHeight / 2 - iconMargin)
      ..fillRect(iconWidth / 2, iconHeight / 2, iconWidth / 2 - iconMargin,
          iconHeight / 2 - iconMargin)
      ..fillStyle = colorToCss(color)
      ..fillRect(iconMargin, iconMargin, iconWidth - iconMargin * 2,
          iconHeight - iconMargin * 2)
      ..strokeStyle = colorToCss(defaultForeground)
      ..rect(iconMargin, iconMargin, iconWidth - iconMargin * 2,
          iconHeight - iconMargin * 2)
      ..stroke();
    return canvas;
  }

  @override
  // TODO: implement image
  CanvasImageSource get image {
    if (_image != null) {
      return _image;
    }
    _image = createCanvasSource();
    return _image;
  }

  CanvasElement _image;

  @override
  Future<CanvasImageSource> loadImage() async {
    // This icon does not perform any async work.
    return image;
  }

  @override
  int get iconWidth => 18;

  @override
  int get iconHeight => 18;
}

class _CustomIconRenderer extends HtmlIconRenderer<CustomIcon> {
  _CustomIconRenderer(CustomIcon icon)
      : baseIconRenderer = getIconRenderer(icon.baseIcon),
        super(icon);

  final HtmlIconRenderer baseIconRenderer;

  @override
  CanvasImageSource createCanvasSource() {
    final baseImage = baseIconRenderer.image;
    if (baseImage == null) {
      return _buildImageAsync();
    }

    return _buildImage(baseImage);
  }

  @override
  CanvasImageSource get image {
    if (_image != null) return _image;
    final baseImage = baseIconRenderer.image;
    if (baseImage == null) return null;

    _image = createCanvasSource();
    return _image;
  }

  CanvasElement _image;

  @override
  Future<CanvasImageSource> loadImage() async {
    final source = await baseIconRenderer.loadImage();
    return _buildImage(source);
  }

  CanvasElement _buildImageAsync() {
    final CanvasElement canvas = _createCanvas();
    baseIconRenderer.loadImage().then((CanvasImageSource source) {
      _drawIcon(canvas, source);
    });
    return canvas;
  }

  CanvasElement _createCanvas() {
    return createHighDpiCanvas(iconWidth, iconHeight);
  }

  CanvasElement _buildImage(CanvasImageSource source) {
    final CanvasElement canvas = _createCanvas();
    _drawIcon(canvas, source);
    return canvas;
  }

  void _drawIcon(CanvasElement canvas, CanvasImageSource source) {
    // TODO(jacobr): define this color in terms of Color objects.
    const String normalColor = '#231F20';

    canvas.context2D
      ..drawImageScaled(source, 0, 0, iconWidth, iconHeight)
      ..strokeStyle = normalColor
      // In IntelliJ this was:
      // UIUtil.getFont(UIUtil.FontSize.MINI, UIUtil.getTreeFont());
      ..font = 'arial 8px'
      ..textBaseline = 'middle'
      ..textAlign = 'center'
      ..fillText(icon.text, iconWidth / 2, iconHeight / 2, iconWidth);
  }
}

class _MaterialIconRenderer extends HtmlIconRenderer<MaterialIcon> {
  _MaterialIconRenderer(MaterialIcon icon) : super(icon);

  @override
  CanvasImageSource get image {
    if (_image != null) return _image;
    if (!_fontLoaded) return null;

    _image = createCanvasSource();
    return _image;
  }

  CanvasElement _image;
  Future<CanvasElement> _imageFuture;

  static FontFace _iconsFont;
  static Future<FontFace> _iconsFontFuture;
  static bool _fontLoaded = false;

  @override
  Future<CanvasImageSource> loadImage() {
    if (_imageFuture != null) {
      return _imageFuture;
    }
    if (_fontLoaded) {
      return Future.value(image);
    }
    final Completer<CanvasElement> imageCompleter = Completer();
    if (!_fontLoaded) {
      if (_iconsFont == null) {
        _iconsFont = FontFace(
          'Material Icons',
          'url(packages/devtools/src/ui/MaterialIcons-Regular.woff2)',
        );
        document.fonts.add(_iconsFont);
        _iconsFontFuture = _iconsFont.load();
        _iconsFontFuture.then((_) {
          _fontLoaded = true;
        });
      }

      _iconsFontFuture.then((_) {
        _image = createCanvasSource();
        imageCompleter.complete(_image);
      });
    }
    return imageCompleter.future;
  }

  @override
  CanvasImageSource createCanvasSource() {
    final canvas = createHighDpiCanvas(iconWidth, iconHeight);
    final context2D = canvas.context2D
      ..translate(iconWidth / 2, iconHeight / 2);
    if (icon.angle != 0) {
      context2D.rotate(icon.angle);
    }
    void _drawIcon() {
      context2D
        ..font = '${icon.fontSize}px Material Icons'
        ..fillStyle = colorToCss(icon.color)
        ..textBaseline = 'middle'
        ..textAlign = 'center'
        ..fillText(icon.text, 0, 0, iconWidth + 10);
    }

    if (_fontLoaded) {
      _drawIcon();
    } else {
      loadImage().then((_) {
        _drawIcon();
      });
    }
    return canvas;
  }
}

CoreElement createIconElement(Icon icon) {
  return getIconRenderer(icon).createCoreElement();
}

HtmlIconRenderer getIconRenderer(Icon icon) {
  HtmlIconRenderer renderer = rendererExpando[icon];
  if (renderer != null) {
    return renderer;
  }

  if (icon is UrlIcon) {
    renderer = _UrlIconRenderer(icon);
  } else if (icon is ColorIcon) {
    renderer = _ColorIconRenderer(icon);
  } else if (icon is CustomIcon) {
    renderer = _CustomIconRenderer(icon);
  } else if (icon is MaterialIcon) {
    renderer = _MaterialIconRenderer(icon);
  } else {
    throw UnimplementedError(
        'No icon renderer defined for $icon of type ${icon.runtimeType}');
  }

  rendererExpando[icon] = renderer;
  return renderer;
}
