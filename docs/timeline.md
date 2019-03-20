---
title: Using the Timeline View
---

* toc
{:toc}

## What is it?

The timeline view displays information about Flutter frames. It consists of
 three parts, each increasing in granularity:
- Frame Rendering Chart
- Flame Chart
- Event Details

**Use a profile build of your application to analyze performance.** Frame rendering times are not indicative of release
performance unless your application is run in profile mode.

## Frame Rendering Chart

This chart is populated with individual frames as they are rendered in your application. Each bar in the chart
represents a frame. The bars are color-coded to highlight the different portions of work that occur when rendering a
Flutter frame: work from the UI thread and work from the GPU thread.

<img src="images/timeline_frame_rendering_chart.png" width="800" />

Clicking a bar will display additional details about the frame.

### UI

The UI thread executes Dart code in the Dart VM. This includes code from your application as well as the
Flutter framework. When your app creates and displays a scene, the UI thread creates a layer tree, a lightweight object
containing device-agnostic painting commands, and sends the layer tree to the GPU thread to be rendered on the device.
Do **not** block this thread.

### GPU

The GPU thread executes graphics code from the Flutter Engine. This thread takes the layer tree and displays it by
talking to the GPU (graphic processing unit). You cannot directly access the GPU thread or its data, but if this thread
is slow, it’s a result of something you’ve done in the Dart code. Skia, the graphics library, runs on this thread, which
is sometimes called the rasterizer thread.

Sometimes a scene results in a layer tree that is easy to construct, but expensive to render on the GPU thread. In this
case, you’ll need to figure out what your code is doing that is causing rendering code to be slow. Specific kinds of
workloads are more difficult for the GPU. They may involve unnecessary calls to
[saveLayer](https://docs.flutter.io/flutter/dart-ui/Canvas/saveLayer.html), intersecting opacities with multiple
objects, and clips or shadows in specific situations.

More information on profiling the GPU thread can be found at
[flutter.dev](https://flutter.dev/docs/testing/ui-performance#identifying-problems-in-the-gpu-graph).

### Jank

The frame rendering chart shows UI and GPU jank in shades of red. We consider a portion of the frame to be janky when
it takes more than 8 ms to complete.

To achieve a frame rendering rate of 60 FPS (frames per second), each frame must render in ~16 ms or less. Since there
are two portions of work for each frame (UI and GPU), each portion should complete in 8 ms or less. When this target is
missed, you may experience UI jank or dropped frames.

See [Flutter performance profiling](https://flutter.dev/docs/testing/ui-performance) for more detailed information on
how to analyze your app's performance.

## Flame Chart

The flame chart shows the event trace for a single frame. The top-most event spawns the event below it, and so on and so
forth. The UI and GPU events are separate event flows, but they share a common timeline (displayed at the top of the
flame chart). This timeline is strictly for the given frame. It does not reflect the clock shared by all frames.

<img src="images/timeline_flame_chart.png" width="800" />

The flame chart supports zooming and panning. Scroll up and down to zoom in and out, respectively. To pan around, you
can either click and drag the chart or scroll horizontally. You can also click an event to view more details in the
details section below the chart.

## Event Details

This section shows details for a specific event. Currently, only the event name and duration are displayed. This feature
is actively being worked on. We are planning to display CPU sampling data here in the future.

<img src="images/timeline_event_details.png" width="800" />