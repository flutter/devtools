import 'package:devtools_app/src/charts/chart_controller.dart';
import 'package:devtools_app/src/charts/chart_trace.dart';
import 'package:devtools_app/src/charts/chart.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:devtools_testing/support/memory_test_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/wrappers.dart';

void main() {
  const windowSize = Size(2225.0, 1000.0);

  group(
    'Chart Timeseries',
    () {
      MemoryJson memoryJson;

      void loadData() {
        // Load canned data testHeapSampleData.
        memoryJson ??= MemoryJson.decode(argJsonString: testHeapSampleData);

        expect(memoryJson.data.length, equals(292));
      }

      ///////////////////////////////////////////////////////////////////////////
      // Scaled Y-axis chart.                                                                     //
      ///////////////////////////////////////////////////////////////////////////

      // Used for test.
      final _rawExternal = <Data>[];
      final _rawUsed = <Data>[];
      final _rawCapacity = <Data>[];
      final _rawRSS = <Data>[];

      int externalTraceIndex;
      int usedTraceIndex;
      int capacityTraceIndex;
      int rssTraceIndex;

      void setupTraces(ChartController controller) {
        // External Heap
        externalTraceIndex = controller.createTrace(
          ChartType.line,
          PaintCharacteristics(
            color: Colors.lightGreen,
            symbol: ChartSymbol.disc,
            diameter: 1.5,
          ),
          name: 'External',
        );

        // Used Heap
        usedTraceIndex = controller.createTrace(
          ChartType.line,
          PaintCharacteristics(
            color: Colors.blue[200],
            symbol: ChartSymbol.disc,
            diameter: 1.5,
          ),
          name: 'Used',
        );

        // Heap Capacity
        capacityTraceIndex = controller.createTrace(
          ChartType.line,
          PaintCharacteristics(
            color: Colors.grey[400],
            diameter: 0.0,
            symbol: ChartSymbol.dashedLine,
          ),
          name: 'Capacity',
        );

        // RSS
        rssTraceIndex = controller.createTrace(
          ChartType.line,
          PaintCharacteristics(
            color: Colors.yellow,
            symbol: ChartSymbol.dashedLine,
            strokeWidth: 2,
          ),
          name: 'RSS',
        );

        expect(controller.traces.length, equals(4));
        for (var index = 0; index < controller.traces.length; index++) {
          switch (index) {
            case 0:
              expect(externalTraceIndex, equals(0));
              expect(controller.traces[index].name, 'External');
              break;
            case 1:
              expect(usedTraceIndex, equals(1));
              expect(controller.traces[index].name, 'Used');
              break;
            case 2:
              expect(capacityTraceIndex, equals(2));
              expect(controller.traces[index].name, 'Capacity');
              break;
            case 3:
              expect(rssTraceIndex, equals(3));
              expect(controller.traces[index].name, 'RSS');
              break;
          }
        }
      }

      void addDataToTrace(
        ChartController controller,
        int traceIndex,
        Data data,
      ) {
        controller.trace(traceIndex).addDatum(data);
      }

      Future<void> pumpChart(WidgetTester tester, Key theKey, Chart theChart,
          double chartHeight) async {
        await tester.pumpWidget(wrap(LayoutBuilder(
            key: theKey,
            builder: (context, constraints) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: chartHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: theChart,
                    ),
                  ),
                ],
              );
            })));

        await tester.pumpAndSettle();
      }

      void chartAllData(ChartController controller) {
        for (var datumIndex = 0;
            datumIndex < memoryJson.data.length;
            datumIndex++) {
          final datum = memoryJson.data[datumIndex];

          final external = datum.external.toDouble();
          final used = datum.used.toDouble();
          final capacity = datum.capacity.toDouble();
          final rss = datum.rss.toDouble();

          controller.addTimestamp(datum.timestamp);

          _rawExternal.add(Data(datum.timestamp, external));

          addDataToTrace(controller, externalTraceIndex, _rawExternal.last);

          _rawUsed.add(Data(datum.timestamp, external + used));
          addDataToTrace(controller, usedTraceIndex, _rawUsed.last);

          _rawCapacity.add(Data(datum.timestamp, capacity));
          addDataToTrace(controller, capacityTraceIndex, _rawCapacity.last);

          _rawRSS.add(Data(datum.timestamp, rss));
          addDataToTrace(controller, rssTraceIndex, _rawRSS.last);
        }
      }

      Future<void> setupScaledChart(
          WidgetTester tester, ChartController controller, Key chartKey) async {
        final theChart = Chart(controller, title: 'Scaled Chart');

        setupTraces(controller);

        loadData();

        await pumpChart(tester, chartKey, theChart, 250);

        expect(find.byWidget(theChart), findsOneWidget);

        // Validate the X axis before data added.
        expect(controller.visibleTicks, equals(215));
        expect(controller.xCanvasChart, equals(50.0));
        expect(controller.xPaddingRight, equals(0.0));
        expect(controller.displayXLabels, true);
        expect(controller.canvasChartWidth, equals(2150.0));

        // Validate the Y axis before data added.
        expect(controller.yScale.computedMin, equals(0.0));
        expect(controller.yScale.computedMax, equals(0.0));
        expect(controller.yScale.labelTicks, equals(0.0));
        expect(controller.yScale.labelUnitExponent, 0.0);
        expect(controller.yScale.tickSpacing, equals(1.0));
        expect(controller.yScale.maxPoint, equals(0.0));
        expect(controller.yScale.maxTicks, equals(185.0));

        chartAllData(controller);
      }

      /// Validate the labels displayed on the y-axis.
      void validateScaledYLabels(ChartController controller) {
        // Validate the labels displayed on the y-axis.
        final yScale = controller.yScale;
        expect(yScale.labelTicks, equals(7));
        for (var labelIndex = yScale.labelTicks;
            labelIndex >= 0;
            labelIndex--) {
          final labelName = ChartPainter.constructLabel(
            labelIndex.toInt(),
            yScale.labelUnitExponent.toInt(),
          );

          // Ensure Y axis labels match.
          final expectedLabels = [
            '0',
            '100M',
            '200M',
            '300M',
            '400M',
            '500M',
            '600M',
            '700M',
          ];
          expect(labelName, expectedLabels[labelIndex.toInt()]);
        }
      }

      testWidgetsWithWindowSize(
        'Scaled Y-axis live',
        windowSize,
        (WidgetTester tester) async {
          const chartKey = Key('Chart');
          final controller = ChartController();

          await setupScaledChart(tester, controller, chartKey);

          // Check live view zoom.
          controller.zoomDuration = const Duration();
          await tester.pumpAndSettle(const Duration(seconds: 2));

          await expectLater(
            find.byKey(chartKey),
            matchesGoldenFile('goldens/memory_chart_scaled_live.png'),
          );
          // Await delay for golden comparison.
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Validate the X axis after data added to all traces.
          expect(controller.visibleTicks, equals(215));
          expect(controller.xCanvasChart, equals(50.0));
          expect(controller.xPaddingRight, equals(0.0));
          expect(controller.displayXLabels, true);
          expect(controller.canvasChartWidth, equals(2150.0));

          // Validate the Y axis after data added to all traces.
          expect(controller.yScale.computedMin, equals(0.0));
          expect(controller.yScale.computedMax, equals(685185185.1851852));
          expect(controller.yScale.labelTicks, equals(7.0));
          expect(controller.yScale.labelUnitExponent, 8.0);
          expect(controller.yScale.tickSpacing, equals(3703703.703703704));
          expect(controller.yScale.maxPoint, equals(684801744.0));
          expect(controller.yScale.maxTicks, equals(190.0));

          final externalTrace = controller.trace(externalTraceIndex);
          expect(externalTrace.dataYMax, equals(633719952.0));
          expect(externalTrace.data.length, equals(_rawExternal.length));

          final usedTrace = controller.trace(usedTraceIndex);
          expect(usedTrace.dataYMax, equals(675253768.0));
          expect(usedTrace.data.length, equals(_rawUsed.length));

          final capacityTrace = controller.trace(capacityTraceIndex);
          expect(capacityTrace.dataYMax, equals(684801744.0));
          expect(capacityTrace.data.length, equals(_rawCapacity.length));

          final rssTrace = controller.trace(rssTraceIndex);
          expect(rssTrace.dataYMax, equals(571727872.0));
          expect(rssTrace.data.length, equals(_rawRSS.length));

          expect(controller.timestampsLength, equals(292));

          validateScaledYLabels(controller);

          // Validate the x-axis labels.
          expect(controller.labelTimestamps.length, equals(3));
          expect(controller.labelTimestamps[0], equals(1595682513450));
          expect(controller.labelTimestamps[1], equals(1595682533744));
          expect(controller.labelTimestamps[2], equals(1595682553811));

          // Validate using UTC timezone.
          expect(
            prettyTimestamp(controller.labelTimestamps[0], isUtc: true),
            equals('13:08:33'),
          );
          expect(
            prettyTimestamp(controller.labelTimestamps[1], isUtc: true),
            equals('13:08:53'),
          );
          expect(
            prettyTimestamp(controller.labelTimestamps[2], isUtc: true),
            equals('13:09:13'),
          );
        },
      );

      void checkScaledXAxis2Labels(ChartController controller) {
        // Validate the x-axis labels.
        expect(controller.labelTimestamps.length, equals(2));
        expect(controller.labelTimestamps[0], equals(1595682492441));
        expect(controller.labelTimestamps[1], equals(1595682552535));

        // Validate using UTC timezone.
        expect(
          prettyTimestamp(controller.labelTimestamps[0], isUtc: true),
          equals('13:08:12'),
        );
        expect(
          prettyTimestamp(controller.labelTimestamps[1], isUtc: true),
          equals('13:09:12'),
        );
      }

      testWidgetsWithWindowSize('Scaled Y-axis all', windowSize,
          (WidgetTester tester) async {
        const chartKey = Key('Chart');
        final controller = ChartController();

        await setupScaledChart(tester, controller, chartKey);

        // Check A=all data view zoom.
        controller.zoomDuration = null;
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await expectLater(
          find.byKey(chartKey),
          matchesGoldenFile('goldens/memory_chart_scaled_all.png'),
        );
        // Await delay for golden comparison.
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Validate the X axis after data added to all traces.
        expect(controller.visibleTicks, equals(292));
        expect(controller.xCanvasChart, equals(50.0));
        expect(controller.xPaddingRight, equals(0.0));
        expect(controller.displayXLabels, true);
        expect(controller.canvasChartWidth, equals(2150.0));

        // Validate the Y axis after data added to all traces.
        expect(controller.yScale.computedMin, equals(0.0));
        expect(controller.yScale.computedMax, equals(685185185.1851852));
        expect(controller.yScale.labelTicks, equals(7.0));
        expect(controller.yScale.labelUnitExponent, 8.0);
        expect(controller.yScale.tickSpacing, equals(3703703.703703704));
        expect(controller.yScale.maxPoint, equals(684801744.0));
        expect(controller.yScale.maxTicks, equals(190.0));

        validateScaledYLabels(controller);

        checkScaledXAxis2Labels(controller);
      });

      testWidgetsWithWindowSize('Scaled Y-axis Five Minutes', windowSize,
          (WidgetTester tester) async {
        const chartKey = Key('Chart');
        final controller = ChartController();

        await setupScaledChart(tester, controller, chartKey);

        // Check 5 minute data view zoom.
        controller.zoomDuration = const Duration(minutes: 5);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await expectLater(
          find.byKey(chartKey),
          matchesGoldenFile('goldens/memory_chart_scaled_five_minute.png'),
        );
        // Await delay for golden comparison.
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Validate the X axis after data added to all traces.
        expect(controller.visibleTicks, equals(996));
        expect(controller.xCanvasChart, equals(50.0));
        expect(controller.xPaddingRight, equals(1.461999999999989));
        expect(controller.displayXLabels, true);
        expect(controller.canvasChartWidth, equals(2148.538));

        // Validate the Y axis after data added to all traces.
        expect(controller.yScale.computedMin, equals(0.0));
        expect(controller.yScale.computedMax, equals(685185185.1851852));
        expect(controller.yScale.labelTicks, equals(7.0));
        expect(controller.yScale.labelUnitExponent, 8.0);
        expect(controller.yScale.tickSpacing, equals(3703703.703703704));
        expect(controller.yScale.maxPoint, equals(684801744.0));
        expect(controller.yScale.maxTicks, equals(190.0));

        validateScaledYLabels(controller);

        checkScaledXAxis2Labels(controller);
      });

      ///////////////////////////////////////////////////////////////////////////
      // Fixed Y-axis chart.                                                                     //
      ///////////////////////////////////////////////////////////////////////////

      final _rawGcEvents = <Data>[];
      final _rawSnapshotEvents = <Data>[];
      final _rawAutoSnapshotEvents = <Data>[];

      int snapshotTraceIndex;
      int autoSnapshotTraceIndex;
      int manualGCTraceIndex;
      int monitorTraceIndex;
      int monitorResetTraceIndex;
      int gcTraceIndex;

      void setupFixedTraces(ChartController controller) {
        // Snapshot
        snapshotTraceIndex = controller.createTrace(
          ChartType.symbol,
          PaintCharacteristics(
            color: Colors.green,
            strokeWidth: 4,
            diameter: 6,
            fixedMinY: 0.4,
            fixedMaxY: 2.4,
          ),
          name: 'Snapshot',
        );

        // Auto-snapshot
        autoSnapshotTraceIndex = controller.createTrace(
          ChartType.symbol,
          PaintCharacteristics(
            color: Colors.red,
            strokeWidth: 4,
            diameter: 6,
            fixedMinY: 0.4,
            fixedMaxY: 2.4,
          ),
          name: 'Auto-Snapshot',
        );

        // Manual GC
        manualGCTraceIndex = controller.createTrace(
          ChartType.symbol,
          PaintCharacteristics(
            color: Colors.blue,
            strokeWidth: 4,
            diameter: 6,
            fixedMinY: 0.4,
            fixedMaxY: 2.4,
          ),
          name: 'Manual GC',
        );

        // Monitor
        monitorTraceIndex = controller.createTrace(
          ChartType.symbol,
          PaintCharacteristics(
            color: Colors.yellow,
            strokeWidth: 4,
            diameter: 6,
            fixedMinY: 0.4,
            fixedMaxY: 2.4,
          ),
          name: 'Monitor',
        );

        monitorResetTraceIndex = controller.createTrace(
          ChartType.symbol,
          PaintCharacteristics(
            color: Colors.yellowAccent,
            strokeWidth: 4,
            diameter: 6,
            fixedMinY: 0.4,
            fixedMaxY: 2.4,
          ),
          name: 'Monitor Reset',
        );

        // VM GC
        gcTraceIndex = controller.createTrace(
          ChartType.symbol,
          PaintCharacteristics(
            color: Colors.blue,
            symbol: ChartSymbol.disc,
            diameter: 4,
            fixedMinY: 0.4,
            fixedMaxY: 2.4,
          ),
          name: 'VM GC',
        );
      }

      /// Event to display in the event pane (User initiated GC, snapshot,
      /// automatic snapshot, etc.)
      const visibleEvent = 2.4;

      /// Monitor events Y axis.
      const visibleMonitorEvent = 1.4;

      /// VM's GCs are displayed in a smaller glyph and closer to the heap graph.
      const visibleVmEvent = 0.4;

      // Load all data into the chart's traces.
      void chartAllFixedData(ChartController controller) {
        for (var datumIndex = 0;
            datumIndex < memoryJson.data.length;
            datumIndex++) {
          final datum = memoryJson.data[datumIndex];

          controller.addTimestamp(datum.timestamp);

          final event = datum.memoryEventInfo;
          if (datum.isGC) {
            // VM GC
            _rawGcEvents.add(Data(datum.timestamp, visibleVmEvent));
            addDataToTrace(controller, gcTraceIndex, _rawGcEvents.last);
          } else if (event.isEventGC) {
            // Manual GC
            final rawData = Data(datum.timestamp, visibleVmEvent);
            addDataToTrace(controller, manualGCTraceIndex, rawData);
          } else if (event.isEventSnapshot) {
            _rawSnapshotEvents.add(Data(datum.timestamp, visibleEvent));
            addDataToTrace(
              controller,
              snapshotTraceIndex,
              _rawSnapshotEvents.last,
            );
          } else if (event.isEventSnapshotAuto) {
            _rawAutoSnapshotEvents.add(Data(datum.timestamp, visibleEvent));
            addDataToTrace(
              controller,
              autoSnapshotTraceIndex,
              _rawAutoSnapshotEvents.last,
            );
          } else if (event.isEventAllocationAccumulator) {
            final monitorType = event.allocationAccumulator;
            final rawData = Data(datum.timestamp, visibleMonitorEvent);
            if (monitorType.isEmpty) continue;
            if (monitorType.isStart) {
              addDataToTrace(controller, monitorTraceIndex, rawData);
            } else if (monitorType.isReset) {
              addDataToTrace(controller, monitorResetTraceIndex, rawData);
            } else {
              assert(false, 'Unknown monitor type');
            }
          } else if (event.isEmpty) {
            assert(false, 'Unexpected EventSample of isEmpty.');
          }
        }
      }

      Future<void> setupFixedChart(
          WidgetTester tester, ChartController controller, Key chartKey) async {
        controller.setFixedYRange(0.4, 2.4);

        final theChart = Chart(controller, title: 'Fixed Chart');

        await pumpChart(tester, chartKey, theChart, 150);

        expect(find.byWidget(theChart), findsOneWidget);

        setupFixedTraces(controller);

        loadData();

        // Validate the X axis before any data.
        expect(controller.visibleTicks, equals(215));
        expect(controller.xCanvasChart, equals(50.0));
        expect(controller.xPaddingRight, equals(0.0));
        expect(controller.displayXLabels, true);
        expect(controller.canvasChartWidth, equals(2150.0));

        // Validate the Y axis before any data.
        expect(controller.yScale.computedMin, equals(0.3707865168539326));
        expect(controller.yScale.computedMax, equals(2.426966292134831));
        expect(controller.yScale.labelTicks, equals(3.0));
        expect(controller.yScale.labelUnitExponent, 0.0);
        expect(controller.yScale.tickSpacing, equals(0.033707865168539325));
        expect(controller.yScale.maxPoint, equals(2.4));
        expect(controller.yScale.maxTicks, equals(90.0));

        // Load all data in the chart.
        chartAllFixedData(controller);
      }

      testWidgetsWithWindowSize(
        'Fixed Y-axis',
        windowSize,
        (WidgetTester tester) async {
          const chartKey = Key('Chart');
          final controller = ChartController();

          await setupFixedChart(tester, controller, chartKey);

          // Check live view zoom.
          controller.zoomDuration = const Duration();
          await tester.pumpAndSettle(const Duration(seconds: 2));

          await expectLater(
            find.byKey(chartKey),
            matchesGoldenFile('goldens/memory_chart_fixed_live.png'),
          );
          // Await delay for golden comparison.
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Validate the X axis after data added to all traces.
          expect(controller.visibleTicks, equals(215));
          expect(controller.xCanvasChart, equals(50.0));
          expect(controller.xPaddingRight, equals(0.0));
          expect(controller.displayXLabels, true);
          expect(controller.canvasChartWidth, equals(2150.0));

          // Validate the Y axis after data added to all traces.
          expect(controller.yScale.computedMin, equals(0.0));

          // Rest of data is out of view because we're live view max is now 1.4
          // and only 2 labels visible.
          expect(controller.yScale.computedMax, equals(1.4157303370786516));
          expect(controller.yScale.labelTicks, equals(2.0));

          expect(controller.yScale.labelUnitExponent, 0.0);
          expect(controller.yScale.tickSpacing, equals(0.02247191011235955));
          // Max live view max is 1.4 other data is not in the visible view.
          expect(controller.yScale.maxPoint, equals(1.4));
          expect(controller.yScale.maxTicks, equals(90.0));

          final snapshotTrace = controller.trace(snapshotTraceIndex);
          expect(snapshotTrace.dataYMax, equals(0.0));
          expect(snapshotTrace.data.length, equals(2));

          final autoSnapshotTrace = controller.trace(autoSnapshotTraceIndex);
          expect(autoSnapshotTrace.dataYMax, equals(0.0));
          expect(autoSnapshotTrace.data.length, equals(2));

          final manualGCTrace = controller.trace(manualGCTraceIndex);
          expect(manualGCTrace.dataYMax, equals(0.0));
          expect(manualGCTrace.data.length, equals(0));

          final monitorTrace = controller.trace(monitorTraceIndex);
          expect(monitorTrace.dataYMax, equals(0.0));
          expect(monitorTrace.data.length, equals(3));

          final monitorResetTrace = controller.trace(monitorResetTraceIndex);
          expect(monitorResetTrace.dataYMax, equals(0.0));
          expect(monitorResetTrace.data.length, equals(2));

          final gcTrace = controller.trace(gcTraceIndex);
          expect(gcTrace.dataYMax, equals(0.0));
          expect(gcTrace.data.length, equals(70));

          expect(controller.timestampsLength, equals(292));

          // Validate the labels displayed on the y-axis.
          final yScale = controller.yScale;
          expect(yScale.labelTicks, equals(2));
          for (var labelIndex = yScale.labelTicks;
              labelIndex >= 0;
              labelIndex--) {
            final labelName = ChartPainter.constructLabel(
              labelIndex.toInt(),
              yScale.labelUnitExponent.toInt(),
            );

            final expectedLabels = ['0', '1', '2'];
            expect(labelName, expectedLabels[labelIndex.toInt()]);
          }

          // Validate the x-axis labels.
          expect(controller.labelTimestamps.length, equals(3));
          expect(controller.labelTimestamps[0], equals(1595682513450));
          expect(controller.labelTimestamps[1], equals(1595682533744));
          expect(controller.labelTimestamps[2], equals(1595682553811));

          // Validate using UTC timezone.
          expect(
            prettyTimestamp(controller.labelTimestamps[0], isUtc: true),
            equals('13:08:33'),
          );
          expect(
            prettyTimestamp(controller.labelTimestamps[1], isUtc: true),
            equals('13:08:53'),
          );
          expect(
            prettyTimestamp(controller.labelTimestamps[2], isUtc: true),
            equals('13:09:13'),
          );
        },
      );

      void checkFixedXAxis2Labels(ChartController controller) {
        // Validate the x-axis labels.
        expect(controller.labelTimestamps.length, equals(2));
        expect(controller.labelTimestamps[0], equals(1595682492441));
        expect(controller.labelTimestamps[1], equals(1595682552535));

        // Validate using UTC timezone.
        expect(
          prettyTimestamp(controller.labelTimestamps[0], isUtc: true),
          equals('13:08:12'),
        );
        expect(
          prettyTimestamp(controller.labelTimestamps[1], isUtc: true),
          equals('13:09:12'),
        );
      }

      testWidgetsWithWindowSize('Fixed Y-axis all', windowSize,
          (WidgetTester tester) async {
        const chartKey = Key('Chart');
        final controller = ChartController();

        await setupFixedChart(tester, controller, chartKey);

        // Check all data view zoom.
        controller.zoomDuration = null;
        await tester.pumpAndSettle(const Duration(seconds: 15));

        await expectLater(
          find.byKey(chartKey),
          matchesGoldenFile('goldens/memory_chart_fixed_all.png'),
        );
        // Await delay for golden comparison.
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Validate the X axis after data added to all traces.
        expect(controller.visibleTicks, equals(292));
        expect(controller.xCanvasChart, equals(50.0));
        expect(controller.xPaddingRight, equals(0.0));
        expect(controller.displayXLabels, true);
        expect(controller.canvasChartWidth, equals(2150.0));

        // Validate the Y axis after data added to all traces.
        expect(controller.yScale.computedMin, equals(0.0));
        expect(controller.yScale.computedMax, equals(2.426966292134831));
        expect(controller.yScale.labelTicks, equals(3.0));
        expect(controller.yScale.labelUnitExponent, 0.0);
        expect(controller.yScale.tickSpacing, equals(0.033707865168539325));
        expect(controller.yScale.maxPoint, equals(2.4));
        expect(controller.yScale.maxTicks, equals(90.0));

        // Validate the labels displayed on the y-axis.
        final yScale = controller.yScale;
        expect(yScale.labelTicks, equals(3));
        for (var labelIndex = yScale.labelTicks;
            labelIndex >= 0;
            labelIndex--) {
          final labelName = ChartPainter.constructLabel(
            labelIndex.toInt(),
            yScale.labelUnitExponent.toInt(),
          );

          final expectedLabels = ['0', '1', '2', '3'];
          expect(labelName, expectedLabels[labelIndex.toInt()]);
        }

        checkFixedXAxis2Labels(controller);
      });

      testWidgetsWithWindowSize('Fixed Y-axis 5 Minutes', windowSize,
          (WidgetTester tester) async {
        const chartKey = Key('Chart');
        final controller = ChartController();

        await setupFixedChart(tester, controller, chartKey);

        // Check all data view zoom.
        controller.zoomDuration = const Duration(minutes: 5);
        await tester.pumpAndSettle(const Duration(seconds: 15));

        await expectLater(
          find.byKey(chartKey),
          matchesGoldenFile('goldens/memory_chart_fixed_five_minutes.png'),
        );
        // Await delay for golden comparison.
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Validate the X axis after data added to all traces.
        expect(controller.visibleTicks, equals(996));
        expect(controller.xCanvasChart, equals(50.0));
        expect(controller.xPaddingRight, equals(1.461999999999989));
        expect(controller.displayXLabels, true);
        expect(controller.canvasChartWidth, equals(2148.538));

        // Validate the Y axis after data added to all traces.
        expect(controller.yScale.computedMin, equals(0.0));
        expect(controller.yScale.computedMax, equals(2.426966292134831));
        expect(controller.yScale.labelTicks, equals(3.0));
        expect(controller.yScale.labelUnitExponent, 0.0);
        expect(controller.yScale.tickSpacing, equals(0.033707865168539325));
        expect(controller.yScale.maxPoint, equals(2.4));
        expect(controller.yScale.maxTicks, equals(90.0));

        // Validate the labels displayed on the y-axis.
        final yScale = controller.yScale;
        expect(yScale.labelTicks, equals(3));
        for (var labelIndex = yScale.labelTicks;
            labelIndex >= 0;
            labelIndex--) {
          final labelName = ChartPainter.constructLabel(
            labelIndex.toInt(),
            yScale.labelUnitExponent.toInt(),
          );

          final expectedLabels = ['0', '1', '2', '3'];
          expect(labelName, expectedLabels[labelIndex.toInt()]);
        }

        checkFixedXAxis2Labels(controller);
      });
    },
  );
}
