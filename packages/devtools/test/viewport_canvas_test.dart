// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
import 'dart:html';

import 'package:devtools/src/ui/environment.dart' as environment;
import 'package:devtools/src/ui/fake_flutter/fake_flutter.dart';
import 'package:devtools/src/ui/viewport_canvas.dart';
import 'package:test/test.dart';

Future<void> settleUi() async {
  // Wait a few frames to ensure that the ui has updated.
  await window.animationFrame;
  await window.animationFrame;
  await window.animationFrame;
}

void main() {
  // Use a floating point device pixel ratio to put more pressure on the canvas
  // logic to round pixel values correctly.
  environment.overrideDevicePixelRatio(2.3);

  group('virtual canvas logic', () {
    ViewportCanvas viewportCanvas;
    final paintsRequested = <Rect>[];
    // TODO(devoncarew): Remove this suppression once after a few Dart releases.
    // ignore: prefer_collection_literals
    final canvasesPainted = Set<CanvasRenderingContext2D>();
    void loggingPaintCallback(CanvasRenderingContext2D context, Rect rect) {
      paintsRequested.add(rect);
      canvasesPainted.add(context);
    }

    setUp(() async {
      paintsRequested.clear();
      canvasesPainted.clear();
      viewportCanvas = ViewportCanvas(
        paintCallback: loggingPaintCallback,
        addBuffer: false,
      );
      // About 10 rows of data visible.
      viewportCanvas.setContentSize(2000, 10000);
      viewportCanvas.element.element.style
        ..height = '300px'
        ..width = '500px'
        ..left = '0'
        ..top = '0'
        ..position = 'absolute';
      document.body.append(viewportCanvas.element.element);
      await settleUi();
    });

    tearDown(() {
      viewportCanvas.element.element.remove();
      viewportCanvas.dispose();
    });

    test('render only first rect', () async {
      expect(paintsRequested.length, equals(1));
      expect(paintsRequested.first, equals(Rect.fromLTWH(0, 0, 512, 512)));
    });

    test('visibility observer fired', () async {
      await settleUi();
      expect(paintsRequested.length, equals(1));

      expect(viewportCanvas.viewport, equals(Rect.fromLTWH(0, 0, 500, 300)));
      viewportCanvas.element.element.style..height = '1000px';

      await window.animationFrame;
      await window.animationFrame;
      expect(viewportCanvas.viewport, equals(Rect.fromLTWH(0, 0, 500, 1000)));

      expect(paintsRequested.length, equals(2));
      expect(paintsRequested[0], equals(Rect.fromLTWH(0, 0, 512, 512)));
      expect(paintsRequested[1], equals(Rect.fromLTWH(0, 512, 512, 512)));
    });

    test('scroll to rect', () async {
      await settleUi();

      expect(viewportCanvas.viewport.left, equals(0));
      expect(viewportCanvas.viewport.top, equals(0));

      viewportCanvas.scrollToRect(Rect.fromLTWH(1000.0, 1500.0, 100.0, 100.0));

      await settleUi();

      expect(viewportCanvas.viewport.left, equals(600.0));
      expect(viewportCanvas.viewport.top, equals(1500.0));

      // Scroll down slightly. The top should not move all the way to match the
      // top of the target.
      viewportCanvas.scrollToRect(Rect.fromLTWH(1000.0, 1700.0, 100.0, 200.0));

      await settleUi();

      expect(viewportCanvas.viewport.left, equals(600.0));
      expect(viewportCanvas.viewport.top, equals(1600.0));

      // Doesn't cause a scroll
      viewportCanvas.scrollToRect(Rect.fromLTWH(1000.0, 1600.0, 100.0, 200.0));

      await settleUi();

      expect(viewportCanvas.viewport.left, equals(600.0));
      expect(viewportCanvas.viewport.top, equals(1600.0));

      // Scroll back to top.
      viewportCanvas.scrollToRect(Rect.fromLTWH(0.0, 0.0, 100.0, 100.0));

      await settleUi();

      expect(viewportCanvas.viewport.left, equals(0));
      expect(viewportCanvas.viewport.top, equals(0));
    });

    test('force rebuild', () async {
      // Set the canvas to be 2x2 tiles.
      viewportCanvas.element.element.style
        ..height = '1000px'
        ..width = '1000px';

      await settleUi();
      paintsRequested.clear();
      // Nothing to actually rebuild
      viewportCanvas.rebuild(force: false);
      expect(paintsRequested, isEmpty);
      viewportCanvas.rebuild(force: true);
      expect(paintsRequested.length, equals(4));

      paintsRequested.clear();
      canvasesPainted.clear();
      viewportCanvas.rebuild(force: true);
      expect(paintsRequested.length, equals(4));
      // Ensure paints hit 4 unique canvases instead of all referencing the same
      // canvas.
      expect(canvasesPainted.length, equals(4));
    });

    test('mark needs paint', () async {
      // Set the canvas to be 2x2 tiles.
      viewportCanvas.element.element.style
        ..height = '1000px'
        ..width = '1000px';

      await settleUi();
      paintsRequested.clear();
      // Nothing to actually rebuild
      viewportCanvas.markNeedsPaint(Rect.fromLTWH(0, 0, 50, 50));
      await settleUi();
      expect(paintsRequested.length, 1);
      expect(paintsRequested.first, equals(Rect.fromLTWH(0, 0, 512, 512)));
      paintsRequested.clear();
      // Off the edge of the ui.
      viewportCanvas.markNeedsPaint(Rect.fromLTWH(300000, 0, 50, 50));
      await settleUi();
      expect(paintsRequested, isEmpty);

      // Request triggering multiple chunks to paint
      paintsRequested.clear();
      viewportCanvas.markNeedsPaint(Rect.fromLTWH(400, 600, 512, 40));
      await settleUi();
      expect(paintsRequested.length, equals(2));
      expect(paintsRequested[0], equals(Rect.fromLTWH(0, 512, 512, 512)));
      expect(paintsRequested[1], equals(Rect.fromLTWH(512, 512, 512, 512)));
    });
  });

  group('virtual canvas paint', () {
    ViewportCanvas viewportCanvas;
    final canvasesPainted = <CanvasRenderingContext2D, Rect>{};
    void loggingPaintCallback(CanvasRenderingContext2D context, Rect rect) {
      canvasesPainted[context] = rect;
      context.fillStyle = 'red';
      // Fill the whole area except for an outer 1 pixel border.
      context.fillRect(
        rect.left + 1,
        rect.top + 1,
        rect.width - 2,
        rect.height - 2,
      );
    }

    setUp(() async {
      canvasesPainted.clear();
      viewportCanvas = ViewportCanvas(
        paintCallback: loggingPaintCallback,
        addBuffer: false,
      );
      // About 10 rows of data visible.
      viewportCanvas.setContentSize(2000, 10000);
      viewportCanvas.element.element.style
        ..height = '1000px'
        ..width = '1000px'
        ..left = '0'
        ..top = '0'
        ..position = 'absolute';
      document.body.append(viewportCanvas.element.element);
      await settleUi();
    });

    List<CanvasElement> findCanvases() {
      return viewportCanvas.element.element.querySelectorAll('canvas');
    }

    tearDown(() {
      viewportCanvas.element.element.remove();
      viewportCanvas.dispose();
    });

    test('verify paint', () async {
      final canvases = findCanvases();
      expect(canvases.length, equals(4));
      final viewportRect =
          viewportCanvas.element.element.getBoundingClientRect();

      for (var canvas in canvases) {
        final context = canvas.context2D;
        expect(canvas.width,
            equals((chunkSize * environment.devicePixelRatio).ceil()));
        expect(canvas.height,
            equals((chunkSize * environment.devicePixelRatio).ceil()));
        final imageData =
            context.getImageData(0, 0, canvas.width, canvas.height);
        // Verify outer margin is transparent.
        // This ensures the logic transforming to chunk coordinates worked
        // correctly. We indent more than 1 pixel from the margin so that the
        // devicePixelRatio does not impact the results.
        expect(imageData.data[0], equals(0));
        expect(imageData.data[(imageData.width - 1) * 4], equals(0));
        expect(imageData.data[0], equals(0));
        expect(
            imageData.data[(imageData.width * (imageData.height - 1) - 1) * 4],
            equals(0));
        // Verify interior is not transparent.
        expect(imageData.data[(imageData.width * 4 + 7) * 4], equals(255));
        expect(
            imageData.data[(imageData.width * (imageData.height - 10) + 7) * 4],
            equals(255));
        final Rect expectedRect = canvasesPainted[context];
        expect(expectedRect, isNotNull);
        // Make sure the canvases were actually placed where we expected.
        final actualRect = canvas.getBoundingClientRect();
        final top = actualRect.top - viewportRect.top;
        final left = actualRect.left - viewportRect.left;
        expect(top.toInt(), equals(expectedRect.top.toInt()));
        expect(left.toInt(), equals(expectedRect.left.toInt()));
        expect(actualRect.width, equals(expectedRect.width));
        expect(actualRect.height, equals(expectedRect.height));
      }
    });
  });
}
