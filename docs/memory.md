---
title: Using the Memory View
---

* toc
{:toc}

## What is it?

Dynamically allocated Dart objects (e.g., new ClassName()) live in a portion of memory called the heap.

DevTool’s Memory profile tab lets you peek at how an isolate is using memory at a given moment. This page also provides accumulator counts that you can use to study the rate of memory allocation. The accumulators are useful if you suspect that your application is leaking memory, or has other bugs relating to memory allocation.

The memory view displays information about a Flutter application's memory usage as well the ability to detect memory leaks
controlling the VMs allocation accumulator. Memory profiler consists of four parts, each increasing in granularity:
- Memory usage overview chart
- Event timeline
- Classes allocated in the heap total instances, bytes allocated, accumulator of allocations since last reset
- Instances of a class type

**Use a profile build of your application to analyze performance.** Memory usages are not indicative of release
performance unless your application is run in profile mode.

## Memory Usage Overview Chart

Is a timeseries graph to visualize the state of the Flutter memory at successive intervals of time.  Each data point on
the chart corresponds to the timestamp (x-axis) of measured quantities (y-axis) of the heap e.g.,  usage, capacity, external,
garbage collection and Resident Set Size.

<img src="images/memory_anatomy.png" width="800" />

- Legend - All collected measurements regarding the memory.  Clicking on a legend name will hide or show that data.
- Range Selector - All memory data collected (timeseries) from the beginning of time, launch of the application.
- Range Selector View - Detailed view of the data collected for this timeseries range (non-gray area).
- X-axis Timestamps - Time of the collected memory information (capacity, used, external, RSS, and GC)
- Hover Information of Collected Data - At a particular time (x-axis) the detailed collected memory data.
- [Garbage Collection](#glossary-of-vm-terms) Occurred - Compaction of the heap occurred.
- Event Timeline - When a user action occurred (e.g., "Snapshot" or "Reset" button clicked) see upper right buttons.
- Snapshot - Display a list of current active memory objects (see Snapshot Classes).
- Reset Accumulators - Reset values, to zero, under the column “Accumulator” in the Snapshot Classes list.
- Filtering Classes - _TODO_
- Snapshot Classes - Clicking on the Snapshot button, top right area, will display the list of current memory objects.  The memory objedts can be sorted by class name, size, allocated instances, etc.
- Accumulator Counts Since Reset - Clicking on the Reset button, top right area, will reset the accumulated instances count.  Clicking on Snapshot after a reset will display the number of new instances allocated since last reset.  This is useful to finding memory leaks.
- Instances of selected classes - Clicking on a class in the Snapshot Classes list will display the number of active instances.
- Inspecting contents of an instance - _TODO_
- Total Active Objects and Classes in the Heap - Total Classes allocated in the Heap and Total Objects (instances) in the Heap.

### Memory Chart

<img src="images/memory_basic_chart.png" width="800" />

The chart's x-axis is a timeline of timestamps events (time series) from the VM as memory changes or the polled state of the memory
every 500 ms.  This helps to give a live appearance on the state of the memory as the application is running.  The quantities plotted on the
y-axis are (from top to bottom):
- Capacity - Current capacity of the heap.
- GC - GC has occurred.
- Used - Objects (Dart objects) in the the heap.
- External - memory not in the Dart heap, but is retained (memory read from a file) or decoded image in Flutter.

<img src="images/memory_rss_chart.png" width="800" />

To view RSS click on the RSS name in the legend.

- RSS is the Resident Set Size and is used to show how much memory is allocated to that process and is in RAM. It does not include memory that is swapped out. It does include memory from shared libraries as long as the pages from those libraries are actually in memory. It does include all stack and heap memory.

For more detailed information on the [Dart VM](https://mrale.ph/dartvm/) and memory.

### Event Timeline

<img src='images/memory_parts.png" width="800" />

Chart displaying when a DevTool event (Snapshot and Reset button clicked) in relation to the timeline of the memory chart.  Hovering over the markers in the Event timeline will display the time when the Snapshot or Reset happened.  This helps to correlate to when in the timeline (x-axis) a memory leak might have occurred.

Clicking on the Snapshot button will show the current state of the memory (heap) with regards to all active classes their instances.  When the Reset button is pressed the accumulator for all classes reset to zero, notice that the reset is tied with a faint blue when a Snapshot is again clicked displays the new accumulators values since the last Reset. 


### Snapshot Classes
- Size - Total amount of memory used by current objects in the heap.
- Count - Total number of current objects in the heap.
- Accumulator - Total number of objects in the heap since the last reset.
- Class - An aggregate of the objects allocated to this class. Clicking the class takes you to the list of all instances of this class.

### Instances of a Class
Displays a list of all instances by their handle name. _TODO INSPECTING AN INSTANCE_.

### Memory Actions
####Liveness of the Memory Usage Overview Chart
- Pause - Pause the memory usage overview chart to allow inspecting of of the data currently being plotted.  New memory data continues to receive new data, notice the Range Selector grows, to the right.
- Resume - The memroy usage overview chart is live and displaying the current time and the latest memory data received.
####Managing the Objects and Statistics in the Heap
- Snapshot - Returns the list of all active classes in the heap.  The Accumulator column displays the number of allocated objects since the previous "Reset".
- Reset - Zeroes out the Accumulator column in the Snapshot Classes table and refreshes the displayed data.
- Filter - TODO
- GC - Initiates a garbage collection.

### Glossary of VM Terms
To truly understand how DevTool works, you need to understand computer science concepts such as memory allocation, the heap, garbage collection, and memory leaks. This glossary contains brief definitions of some of the terms used by DevTool.
- Garbage collection - (GC) is the process of searching the heap to locate, and reclaim, regions of “dead” memory—memory that is no longer being used by an application. This process allows the memory to be re-used and minimizes the risk of an application running out of memory, causing it to crash. Garbage collection is performed automatically by the Dart VM. In DevTool, you can perform garbage collection on demand by clicking the GC button.
- Heap - Dart objects that are dynamically allocated live in a portion of memory called the heap. An object allocated from the heap is freed (eligible for garbage collection) when nothing points to it, or when the application terminates. When nothing points to an object, it is considered to be dead. When an object is pointed to by another object, it is live.
- Isolates - Dart supports concurrent execution by way of isolates, which you can think of as processes without the overhead. Each isolate has its own memory and code, which can’t be affected by any other isolate. For more information, see The Event Loop and Dart.
- Memory leak - A memory leak occurs when an object is live (meaning that another object points to it) but it is not being used (so it shouldn’t have any references from other objects). Such an object can’t be garbage collected, so it takes up space in the heap and contributes to memory fragmentation. Memory leaks put unnecessary pressure on the VM and can be difficult to debug.
- Virtual machine (VM) - The Dart virtual machine is a piece of software that can directly execute Dart code.