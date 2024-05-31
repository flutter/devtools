// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/inspector_v2/inspector_data_models.dart';
import 'package:devtools_app/src/screens/inspector_v2/layout_explorer/ui/theme.dart';
import 'package:devtools_app/src/shared/primitives/math_utils.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'layout_explorer_test_utils.dart';

void main() {
  setGlobal(IdeTheme, IdeTheme());

  group('FlexLayoutProperties tests', () {
    Future<FlexLayoutProperties> toFlexLayoutProperties(
      Flex flex, {
      required WidgetTester tester,
      int subtreeDepth = 2,
      double? width,
      double? height,
    }) async {
      final wrappedWidget = SizedBox(
        width: width,
        height: height,
        child: flex,
      );
      final rootNodeDiagnostics =
          await widgetToLayoutExplorerRemoteDiagnosticsNode(
        widget: wrappedWidget,
        tester: tester,
        subtreeDepth: subtreeDepth,
      );
      final flexDiagnostics = rootNodeDiagnostics.childrenNow.first;
      return FlexLayoutProperties.fromDiagnostics(flexDiagnostics);
    }

    testWidgets(
      'FlexLayoutProperties.fromJson creates correct value from enum',
      (tester) async {
        const widget = Row(
          textDirection: TextDirection.ltr,
          children: [SizedBox()],
        );
        final flexProperties =
            await toFlexLayoutProperties(widget, tester: tester);
        expect(flexProperties.direction, Axis.horizontal);
        expect(flexProperties.mainAxisAlignment, MainAxisAlignment.start);
        expect(flexProperties.mainAxisSize, MainAxisSize.max);
        expect(flexProperties.crossAxisAlignment, CrossAxisAlignment.center);
        expect(flexProperties.textDirection, TextDirection.ltr);
        expect(flexProperties.verticalDirection, VerticalDirection.down);
        expect(flexProperties.textBaseline, null);
      },
    );

    testWidgets('startIsTopLeft should return false', (tester) async {
      const columnWidget = Column(
        verticalDirection: VerticalDirection.up,
        children: [SizedBox()],
      );
      final columnProperties =
          await toFlexLayoutProperties(columnWidget, tester: tester);
      expect(columnProperties.startIsTopLeft, false);

      const rowWidget = Row(
        textDirection: TextDirection.rtl,
        children: [SizedBox()],
      );
      final rowProperties =
          await toFlexLayoutProperties(rowWidget, tester: tester);
      expect(rowProperties.startIsTopLeft, false);
    });

    testWidgets(
      'displayChildren is the same as children when start is top left',
      (tester) async {
        final widget = Column(
          children: [
            const SizedBox(),
            Container(),
          ],
        );
        final properties = await toFlexLayoutProperties(widget, tester: tester);
        expect(properties.startIsTopLeft, true);
        expect(properties.displayChildren[0].description, 'SizedBox');
        expect(properties.displayChildren[1].description, 'Container');
      },
    );

    testWidgets(
      'displayChildren is a reversed children when start is not top left',
      (tester) async {
        final widget = Column(
          verticalDirection: VerticalDirection.up,
          children: [
            const SizedBox(),
            Container(),
          ],
        );
        final properties = await toFlexLayoutProperties(widget, tester: tester);
        expect(properties.startIsTopLeft, false);
        expect(properties.displayChildren[0].description, 'Container');
        expect(properties.displayChildren[1].description, 'SizedBox');
      },
    );

    group('childrenRenderProperties tests', () {
      const maxMainAxisDimension = 500.0;

      double maxSizeAvailable(Axis _) => maxMainAxisDimension;

      List<RenderProperties> childrenRenderProperties(
        FlexLayoutProperties properties,
      ) =>
          properties.childrenRenderProperties(
            smallestRenderWidth: minRenderWidth,
            largestRenderWidth: defaultMaxRenderWidth,
            smallestRenderHeight: minRenderHeight,
            largestRenderHeight: defaultMaxRenderHeight,
            maxSizeAvailable: maxSizeAvailable,
          );

      final childrenWidgets = <Widget>[
        const SizedBox(
          width: 50.0,
        ),
        const SizedBox(
          width: 75.0,
          height: 25.0,
        ),
      ];

      testWidgets(
        'returns correct RenderProperties with main axis not flipped when start is top left',
        (tester) async {
          final widget = Row(children: childrenWidgets);
          final properties = await toFlexLayoutProperties(
            widget,
            width: maxMainAxisDimension,
            tester: tester,
            subtreeDepth: 3,
          );
          final renderProps = properties.childrenRenderProperties(
            smallestRenderWidth: minRenderWidth,
            largestRenderWidth: defaultMaxRenderWidth,
            smallestRenderHeight: minRenderHeight,
            largestRenderHeight: defaultMaxRenderHeight,
            maxSizeAvailable: maxSizeAvailable,
          );
          expect(renderProps.length, 3);
          expect(renderProps, [
            RenderProperties(
              axis: Axis.horizontal,
              size: const Size(250, 250),
              realSize: const Size(50.0, 0.0),
              offset: const Offset(0.0, 125.0),
            ),
            RenderProperties(
              axis: Axis.horizontal,
              size: const Size(261.5, 500),
              realSize: const Size(75.0, 25.0),
              offset: const Offset(250.0, 0.0),
            ),
            RenderProperties(
              axis: Axis.horizontal,
              size: const Size(400, 500),
              realSize: const Size(375.0, 25.0),
              offset: const Offset(511.5, 0.0),
              isFreeSpace: true,
            ),
          ]);
        },
      );

      testWidgets(
        'returns correct RenderProperties with main axis flipped when start is not top left',
        (tester) async {
          final widget = Row(
            textDirection: TextDirection.rtl,
            children: childrenWidgets,
          );
          final properties = await toFlexLayoutProperties(
            widget,
            tester: tester,
            width: maxMainAxisDimension,
            subtreeDepth: 3,
          );
          final renderProps = properties.childrenRenderProperties(
            smallestRenderWidth: minRenderWidth,
            largestRenderWidth: defaultMaxRenderWidth,
            smallestRenderHeight: minRenderHeight,
            largestRenderHeight: defaultMaxRenderHeight,
            maxSizeAvailable: maxSizeAvailable,
          );
          expect(renderProps.length, 3);
          expect(renderProps, [
            RenderProperties(
              axis: Axis.horizontal,
              size: const Size(261.5, 500.0),
              realSize: const Size(75.0, 25.0),
              offset: const Offset(400.0, 0.0),
            ),
            RenderProperties(
              axis: Axis.horizontal,
              size: const Size(250.0, 250.0),
              realSize: const Size(50.0, 0.0),
              offset: const Offset(661.5, 125.0),
            ),
            RenderProperties(
              axis: Axis.horizontal,
              size: const Size(400, 500),
              realSize: const Size(375.0, 25.0),
              offset: const Offset(0.0, 0.0),
              isFreeSpace: true,
            ),
          ]);
        },
      );

      testWidgets(
        'when the start is not top left, render properties should be equals to its mirrored version',
        (tester) async {
          Row buildWidget({
            required bool flipMainAxis,
            required MainAxisAlignment mainAxisAlignment,
          }) =>
              Row(
                textDirection:
                    flipMainAxis ? TextDirection.rtl : TextDirection.ltr,
                mainAxisAlignment: flipMainAxis
                    ? mainAxisAlignment.reversed
                    : mainAxisAlignment,
                children: flipMainAxis
                    ? childrenWidgets.reversed.toList()
                    : childrenWidgets,
              );
          for (final mainAxisAlignment in MainAxisAlignment.values) {
            final originalWidgetRenderProperties = childrenRenderProperties(
              await toFlexLayoutProperties(
                buildWidget(
                  flipMainAxis: false,
                  mainAxisAlignment: mainAxisAlignment,
                ),
                tester: tester,
              ),
            );
            final mirroredWidgetRenderProperties = childrenRenderProperties(
              await toFlexLayoutProperties(
                buildWidget(
                  flipMainAxis: true,
                  mainAxisAlignment: mainAxisAlignment,
                ),
                tester: tester,
              ),
            );
            expect(
              originalWidgetRenderProperties,
              mirroredWidgetRenderProperties,
            );
          }
        },
      );
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
        child: const Row(
          children: [SizedBox()],
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
        expect(
          layoutProperties.describeHeightConstraints(),
          '$minHeight<=h<=$maxHeight',
        );
        expect(
          layoutProperties.describeWidthConstraints(),
          '$minWidth<=w<=$maxWidth',
        );
      });

      testWidgets('unconstrained width', (tester) async {
        final widget = Row(
          children: [
            Container(),
          ],
        );
        final rowDiagnosticsNode =
            await widgetToLayoutExplorerRemoteDiagnosticsNode(
          widget: widget,
          tester: tester,
        );
        final containerDiagnosticsNode = rowDiagnosticsNode.childrenNow.first;
        final layoutProperties = LayoutProperties(containerDiagnosticsNode);
        expect(
          layoutProperties.describeWidthConstraints(),
          'width is unconstrained',
        );
      });

      testWidgets('unconstrained height', (tester) async {
        final widget = Column(
          children: [
            Container(),
          ],
        );
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
        widget: widget,
        tester: tester,
      );
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
      },
    );

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
      },
    );

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
      },
    );
  });
}
