# Dart DevTools Allocation Profile

Note: This page is currently under construction.

## Description

The allocation profile tab displays information about currently allocated objects in the Dart heap of the currently selected isolate. An allocation profile is broken down into five columns:

- **Class**, which contains the name of each Dart class included in the program.
- **Instances**, which contains the number of live instances of each class.
- **Total Size**, which displays the total shallow memory consumption of all instances of each class. The value in this column is the sum of the `Dart Heap` and `External` columns.
- **Dart Heap**, which displays the portion of allocated memory which resides directly in the Dart heap. The value in this column is the shallow size of all instances of a given class, which is the size of an object not including the size of its children.
- **External**, which displays the portion of allocated memory that is held on to by instances of the class but does not reside in the Dart heap (e.g., Flutter images, instances of `ExternalTypedData`, etc).

### Refresh on GC

Enabling the "Refresh on GC" button will result in the profile automatically refreshing once the Dart VM notifies DevTools that it has completed a garbage collection on the current isolate. Garbage collection happens regularly as more objects are allocated and can potentially result in a significant amount of memory being reclaimed by the VM. Objects that survive a GC are likely to be alive immediately after the GC completes, so the allocation profile is most accurate when collected after a GC event.
