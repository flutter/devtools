// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/inspector/diagnostics_node.dart';
import 'package:devtools_app/src/inspector/inspector_data_models.dart';
import 'package:devtools_app/src/inspector/layout_explorer/flex/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'layout_explorer_test_utils.dart';

void main() {
  group('FlexLayoutProperties tests', () {
    testWidgets('FlexLayoutProperties.fromJson creates correct value from enum',
        (tester) async {
      final widget = Row(
        children: const [SizedBox()],
        textDirection: TextDirection.ltr,
      );
      final diagnostics = await widgetToLayoutExplorerRemoteDiagnosticsNode(
        widget: widget,
        tester: tester,
      );
      final FlexLayoutProperties flexProperties =
          FlexLayoutProperties.fromDiagnostics(diagnostics);
      expect(flexProperties.direction, Axis.horizontal);
      expect(flexProperties.mainAxisAlignment, MainAxisAlignment.start);
      expect(flexProperties.mainAxisSize, MainAxisSize.max);
      expect(flexProperties.crossAxisAlignment, CrossAxisAlignment.center);
      expect(flexProperties.textDirection, TextDirection.ltr);
      expect(flexProperties.verticalDirection, VerticalDirection.down);
      expect(flexProperties.textBaseline, TextBaseline.alphabetic);
    });

    testWidgets('startIsTopLeft should return false', (tester) async {
      final columnWidget = Column(
        children: const [SizedBox()],
        verticalDirection: VerticalDirection.up,
      );
      final columnNode = await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: columnWidget, tester: tester);
      final columnProperties = FlexLayoutProperties.fromDiagnostics(columnNode);
      expect(columnProperties.startIsTopLeft, false);

      final rowWidget = Row(
        children: const [SizedBox()],
        textDirection: TextDirection.rtl,
      );
      final rowNode = await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: rowWidget, tester: tester);
      final rowProperties = FlexLayoutProperties.fromDiagnostics(rowNode);
      expect(rowProperties.startIsTopLeft, false);
    });

    testWidgets(
        'displayChildren is the same as children when start is top left',
        (tester) async {
      final widget = Column(children: [
        const SizedBox(),
        Container(),
      ]);
      final node = await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: widget, tester: tester);
      final properties = FlexLayoutProperties.fromDiagnostics(node);
      expect(properties.startIsTopLeft, true);
      expect(properties.displayChildren[0].description, 'SizedBox');
      expect(properties.displayChildren[1].description, 'Container');
    });

    testWidgets(
        'displayChildren is a reversed children when start is not top left',
        (tester) async {
      final widget = Column(
        children: [
          const SizedBox(),
          Container(),
        ],
        verticalDirection: VerticalDirection.up,
      );
      final node = await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: widget, tester: tester);
      final properties = FlexLayoutProperties.fromDiagnostics(node);
      expect(properties.startIsTopLeft, false);
      expect(properties.displayChildren[0].description, 'Container');
      expect(properties.displayChildren[1].description, 'SizedBox');
    });
  });

  group('LayoutProperties tests', () {
    testWidgets('deserializes RemoteDiagnosticsNode correctly', (tester) async {
      const constraints = BoxConstraints(
        minWidth: 432.0,
        maxWidth: 432.0,
        minHeight: 56.0,
        maxHeight: 56.0,
      );
      const size = Size(432.0, 56.0);
      final widget = Container(
        width: size.width,
        height: size.height,
        constraints: constraints,
        child: Row(
          children: const [SizedBox()],
        ),
      );
      final diagnosticsNode = await widgetToLayoutExplorerRemoteDiagnosticsNode(
        widget: widget,
        tester: tester,
        subtreeDepth: 2,
      );
      final rowDiagnosticsNode = diagnosticsNode.childrenNow.first;
      final layoutProperties = LayoutProperties(rowDiagnosticsNode);

      expect(layoutProperties.size, size);
      expect(layoutProperties.constraints, constraints);
      expect(layoutProperties.totalChildren, 1);
    });

    group('describeWidthConstraints and describeHeightConstraints', () {
      testWidgets('single value', (tester) async {
        const width = 25.0;
        const height = 56.0;
        const constraints = BoxConstraints.tightFor(
          width: width,
          height: height,
        );
        final widget = ConstrainedBox(
          constraints: constraints,
          child: const SizedBox(),
        );
        final constrainedBoxDiagnosticsNode =
            await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: widget,
          tester: tester,
        );
        final sizedBoxDiagnosticsNode =
            constrainedBoxDiagnosticsNode.childrenNow.first;
        final layoutProperties = LayoutProperties(sizedBoxDiagnosticsNode);
        expect(layoutProperties.describeHeightConstraints(), 'h=$height');
        expect(layoutProperties.describeWidthConstraints(), 'w=$width');
      });

      testWidgets('range value', (tester) async {
        const minWidth = 25.0, maxWidth = 50.0;
        const minHeight = 75.0, maxHeight = 100.0;
        const constraints = BoxConstraints(
          minWidth: minWidth,
          maxWidth: maxWidth,
          minHeight: minHeight,
          maxHeight: maxHeight,
        );
        final widget = ConstrainedBox(
          constraints: constraints,
          child: const SizedBox(),
        );
        final constrainedBoxDiagnosticsNode =
            await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: widget,
          tester: tester,
        );
        final sizedBoxDiagnosticsNode =
            constrainedBoxDiagnosticsNode.childrenNow.first;
        final layoutProperties = LayoutProperties(sizedBoxDiagnosticsNode);
        expect(layoutProperties.describeHeightConstraints(),
            '$minHeight<=h<=$maxHeight');
        expect(layoutProperties.describeWidthConstraints(),
            '$minWidth<=w<=$maxWidth');
      });

      testWidgets('unconstrained width', (tester) async {
        final widget = Row(children: [
          Container(),
        ]);
        final rowDiagnosticsNode =
            await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: widget,
          tester: tester,
        );
        final containerDiagnosticsNode = rowDiagnosticsNode.childrenNow.first;
        final layoutProperties = LayoutProperties(containerDiagnosticsNode);
        expect(layoutProperties.describeWidthConstraints(),
            'width is unconstrained');
      });

      testWidgets('unconstrained height', (tester) async {
        final widget = Column(children: [
          Container(),
        ]);
        final columnDiagnosticsNode =
            await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: widget,
          tester: tester,
        );
        final containerDiagnosticsNode =
            columnDiagnosticsNode.childrenNow.first;
        final layoutProperties = LayoutProperties(containerDiagnosticsNode);
        expect(
          layoutProperties.describeHeightConstraints(),
          'height is unconstrained',
        );
      });
    });

    testWidgets('describeWidth and describeHeight', (tester) async {
      const width = 432.5, height = 56.0;
      final widget = SizedBox(
        width: width,
        height: height,
        child: Container(),
      );
      final sizedBoxNode = await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: widget, tester: tester);
      final containerNode = sizedBoxNode.childrenNow.first;
      final layoutProperties = LayoutProperties(containerNode);
      expect(layoutProperties.describeHeight(), 'h=$height');
      expect(layoutProperties.describeWidth(), 'w=$width');
    });
  });

  group('computeRenderSizes', () {
    test(
        'scale sizes so the largestSize maps to largestRenderSize with forceToOccupyMaxSize=false',
        () {
      final renderSizes = computeRenderSizes(
        sizes: [100.0, 200.0, 300.0],
        smallestSize: 100.0,
        largestSize: 300.0,
        smallestRenderSize: 200.0,
        largestRenderSize: 600.0,
        maxSizeAvailable: 2000,
        useMaxSizeAvailable: false,
      );
      expect(renderSizes, [200.0, 400.0, 600.0]);
      expect(sum(renderSizes), lessThan(2000));
    });

    test(
        'scale sizes so the items fit maxSizeAvailable with forceToOccupyMaxSize=true',
        () {
      final renderSizes = computeRenderSizes(
        sizes: [100.0, 200.0, 300.0],
        smallestSize: 100.0,
        largestSize: 300.0,
        smallestRenderSize: 200.0,
        largestRenderSize: 600.0,
        maxSizeAvailable: 2000,
      );
      expect(renderSizes, [200.0, 666.6666666666667, 1133.3333333333335]);
      expect(sum(renderSizes) - 2000.0, lessThan(0.01));
    });

    test(
        'scale sizes when the items exceeds maxSizeAvailable with forceToOccupyMaxSize=true should not change any behavior',
        () {
      final renderSizes = computeRenderSizes(
        sizes: [100.0, 200.0, 300.0],
        smallestSize: 100.0,
        largestSize: 300.0,
        smallestRenderSize: 300.0,
        largestRenderSize: 900.0,
        maxSizeAvailable: 250.0,
      );
      expect(renderSizes, [300.0, 600.0, 900.0]);
      expect(sum(renderSizes), greaterThan(250.0));
    });
  });
}
