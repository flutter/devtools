## DevTools Charting

![GitHub contributors](https://img.shields.io/github/contributors/flutter/devtools.svg)

We gladly accept contributions via GitHub pull requests!

You must complete the
[Contributor License Agreement](https://cla.developers.google.com/clas).
You can do this online, and it only takes a minute. If you've never submitted code before,
you must add your (or your organization's) name and contact info to the [AUTHORS](AUTHORS)
file.

See Development prep in [CONTRIBUTING](https://github.com/flutter/devtools/blob/master/CONTRIBUTING.md)

## Overview

DevTools has used a number of existing charting packages with various issues e.g.,
* rich set of charts, more than DevTools would produce
* complex abstraction to support rich set of charts
* not extensible stuff
* not flexible enough without hacky code to augment
* not Dart or Flutter compliant

This charting subsystem plots [timeseries data](https://en.wikipedia.org/wiki/Time_series).  Two basic charts are supported:
1. line chart to display non-numeric values e.g., events
1. scatter chats with or without shading from 0 to their Y coordinate.

## The Data
A chart consist of one or more traces. A trace is a collection of data to be plotted in the same chart on the same temporal X-axis (time).  For example, a chart could have 4 traces:
1. current capacity of the heap (free/used) at every sample period (time)
1. amount of heap used at every sample period (time)
1. number of objects in the heap at every sample period (time)
1. when a GC (garbage collection) occurred.

In all cases, the above 4 traces share the same X-Axis time scale.  However, the first two traces have numeric data a real value in total bytes, the third is number of objects and the last is when a GC occurred.  There are a few ways to display these seemly disparate pieces of data.

## Charts

First, create a StatefulWidget to contain the chart e.g.,
```
class MyChart extends StatefulWidget {
  MyChart({super.key});

  final controller = ChartController();

  @override
  State<StatefulWidget> createState() => MyChartState();
}

class MyChartState extends State<MyChart> {
  MyChartState(this.controller);

  ChartController get controller => widget.controller;
}
```
Then, override the State's initState and build methods in MyChartState e.g.,

```
  @override
  void initState() {
    super.initState();

    // If you're creating a line chart then fix the Y-range. For a scatter chart
    // don't create a fixed range, then the chart will autmatically compute the
    // min/max range and rescale the axis.
    controller.setFixedYRange(0.4, 2.4);            // Line chart fixed.

    // Create the traces to hold each set of data points e.g., temperature
    // collected every hour as well as barametric pressure collected every hour.
    setupTraces();
  }

  @override
  Widget build(BuildContext context) {
    final ballChart = Chart(controller, 'Balls Chart');

    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: ballChart,
    );
  }
```
## Create a Trace
Create each trace, in this example we're creating a red circle and blue ball to appear at particular points in time. The Y coordinate of a datum (for a line chart) is not significant other than where to place the event in time.  For a scatter chart, the datum's Y coordinate would be significant e.g., temperature. For both the line and scatter charts the X coordinate is the time. Important note a trace contains the specific plotting characteristers e.g., color, shape, connected line, etc.

This implies that even though different datum could be contained in a single trace each datum would need to hold its rendering characteristics when a datum is rendered in the trace. Considering that a trace may contain many thousands (tens of thousands) of pieces of data that would create unnessary datum overhead as well as more complex painting inside the canvas code when rendering different datum in a trace. The internal chart rendering instead, blasts each trace's data with the same trace's monolithic rendering characterstics.
```
  void setupTraces() {
    // Green Circle
    greenTraceIndex = controller.createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.green,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: 0.4,
        fixedMaxY: 2.4,
      ),
      name: 'Green Circle',
    );

    // Small Blue Ball
    blueTraceIndex = controller.createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.blue,
        symbol: ChartSymbol.disc,
        diameter: 4,
        fixedMinY: 0.4,
        fixedMaxY: 2.4,
      ),
      name: 'Blue Ball',
    );

    // Red Circle
    redTraceIndex = controller.createTrace(
      ChartType.symbol,
      PaintCharacteristics(
        color: Colors.red,
        strokeWidth: 4,
        diameter: 6,
        fixedMinY: 0.4,
        fixedMaxY: 2.4,
      ),
      name: 'Red Circle',
    );
  }
```
## Adding Data
Create a datum (see Data class) and add the data to a trace (adddatum). In the below example, a datum is created first and added to the green trace (green circle), every second a datum is added to the blue trace (blue ball) then after 30 seconds the last datum is added to the red trace (red circle).
```
  static const greenPosition = 0.4;    // Starting symbol position
  static const bluePosition = 1.4;     // Every second symbol position
  static const redPosition = 2.4;      // Stoping symbol position

  var previousTime = DateTime.now();
  final startDatum = Data(previousTime.millisecondsSinceEpoch, greenPosition);

  // Start the heartbeat.
  controller.addTimestamp(startDatum.timestamp);
  
  // Add the first real datum.
  controller.trace(greenTraceIndex).addDatum(startDatum);

  Timer.periodic(
    const Duration(seconds: 1),
    (Timer timer) {
      if (controller.trace(blueTraceIndex).data.length < 30) {
        final currentTime = DateTime.now();
        final  = currentTime.millisecondsSinceEpoch;

        // Once a second heartbeat.
        controller.addTimestamps(timestamp);

        // Add the blue ball.
        final datum = Data(timestamp, bluePosition);
        controller.trace(blueTraceIndex).addDatum(datum);

        previousTime = currentTime;
      } else {
        controller.addTimestamps(previousTime.millisecondsSinceEpoch);
        final stopDatum = Data(
          previousTime.millisecondsSinceEpoch,
          redPosition,
        );
        // Last datum is the red circle.
        controller.trace(redTraceIndex).addDatum(stopDatum);

        timer.cancel();
      }
    },
  );
```
Each call to addDatum will 
1. notifies the chart that new data has arrived.
1. compute the Y-axis scale (if not fixed)
1. chart the data
1. update the X-axis.

 One important piece of information is adding a heartbeat. If a live chart is needed where the timeline (X axis) moves in a linear fashion requires adding a heart beat (at the granularity requested of the X axis) a tickstamp is added to the ChartController timestamps field on every tick e.g.,

```
            controller.addTimestamps(currentTime.millisecondsSinceEpoch)
```
The heartbeat allows the data to be replayed as if the data collection is live, at the same rate of experiencing the collecting of the live data.
