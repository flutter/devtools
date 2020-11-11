## DevTools Charting Package

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

This charting library plots [timeseries data](https://en.wikipedia.org/wiki/Time_series).  Two basic charts are supported:
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
  const MyChart({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MyChartState(ChartController());
}

class MyChartState extends State<MyChart> {
  MyChartState(this.controller);

  ChartController controller;

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

  }
```
## Adding Data
Simply create the datum (see Data class) then call addDatum on the created Trace. In the below example, a datum is created first and added to the redTrace then every 10 seconds a datum is created and added to the blueTrace:
```
const greenPosition = 0.4;  // Starting position
const bluePosition = 1.4;   // Every 10 seconds
const redPosition = 2.4;    // Stop position

var previousTime = DateTime.now();
final startDatum = Data(previousTime.millisecondsSinceEpoch, greenPosition);
controller.trace(greenTraceIndex).addDatum(startDatum);

var items = 0;
while (items < 20) {
  final currentTime = DateTime.now();
  if (current.difference(previousTime).inSeconds >= 10) {
    final datum = Data(current.millisecondsSinceEpoch, bluePosition);
    controller.trace(blueTraceIndex).addDatum(datum);
    previousTime = currentTime;
  }
}

final stopDatum = Data(previousTime.millisecondsSinceEpoch, redPosition);
controller.trace(redTraceIndex).addDatum(stopDatum);
```
Each call to addDatum will 
1. notifies the chart that new data has arrived.
1. compute the Y-axis scale (if not fixed)
1. chart the data
1. update the X-axis.
