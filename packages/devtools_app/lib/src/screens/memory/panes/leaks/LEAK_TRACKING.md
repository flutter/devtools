# Dart DevTools memory leak tracker

This page and functionality are under construction.
See https://github.com/flutter/devtools/issues/3951.

[self-link](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/screens/memory/panes/leaks/LEAK_TRACKING.md)


## Understand concepts

### Glossary

**GC**: garbage collection. The process of reclaiming memory that is no
longer being used.

**Memory Leak**: Progressive use of more and more memory by an application,
for example, by repeatedly creating (but not disposing of) a listener.

**Memory Bloat**: Using more memory than is necessary for optimal performance,
for example, by using overly large images or not closing a stream.

**Object's Retaining Path**: Sequence of references from the root object
that prevents the object from being GCed.


### Leak types

To detect memory leaks, the tool assumes that, with proper memory management,
an object's disposal and garbage collection should happen sequentially,
close to each other.

By monitoring disposal and GC events, the tool detects different types of leaks:

**Not disposed, but GCed (not-disposed)**: a disposable object was GCed,
without being disposed first. This means that the object's disposable content
is using memory after the object is no longer needed.
To fix the leak, invoke `dispose()` to free up the memory.

**Disposed, but not GCed (not-GCed)**: an object was disposed,
but not GCed after certain number of GC events. This means that
a reference to the object is preventing it from being
garbage collected after it's no longer needed.
To fix the leak, after disposal assign all references
to the object to null:

```
myField.dispose();
myField = null;
```

**Disposed and GCed late (GCed-late)**: an object disposed and then GCed,
but GC happened later than expected. This means the retaining path was
holding the object in memory for some period, but then disappeared.

### Culprits and victims

If you have a set of not-GCed objects, some of them (victims)
might not be GC-ed because they are held by others (culprits).
Normally, to fix the leaks, you need to only fix the culprits.

**Victim**: a leaked object, for which the tool could find another
leaked object that, if fixed, would also fix the first leak.

**Culprit**: a leaked object that is not detected to be the victim
of another object.

The tool detects which leaked objects are culprits, so you know where to focus.

For example, out of four not-GCed leaks on the following diagram,
only one is the culprit, because, when the object is fixed
and GCed, the victims it referenced will be also GCed:


```mermaid
   
   flowchart TD;
      l1[leak1\nculprit]
      l2[leak2\nvictim]
      l3[leak3\nvictim]
      l4[leak4\nvictim]
      l1-->l2;
      l1-->l3;
      l2-->l4;
      l3-->l4;
```



### Limitations

The tool detects leaks for disposable and instrumented classes only
(noting that the fixed leak can also fix other objects). 

Some classes in Flutter framework are already instrumented.
If you want your classes to be tracked, you need to make them
disposable and [instrument](#instrument) them.

## Use the Leak Tracker

### Configure environment

NOTE: For Google3 applications,
follow http://go/detect-memory-leaks-in-g3-flutter-app.

While the leak detection functionality is under construction,
you will need the forked version of the Flutter framework.

Follow the [standard Flutter installation process](https://docs.flutter.dev/get-started/install),
but, instead of downloading or cloning official Flutter,
clone `git@github.com:polina-c/flutter.git`,
then checkout the branch `leak-tracking2`,
and then never run `flutter upgrade` or `flutter channel`.

### Detect leaks in demo app

TODO: move the example to test/fixtures when it compiles with stable flutter.

1. Run https://github.com/polina-c/spikes/tree/master/leaking_app
   in profile mode (with flag `-profile`).
3. [Connect](https://docs.flutter.dev/development/tools/devtools/cli#open-devtools-and-connect-to-the-target-app)
   DevTools to the app 
4. Open Memory > Leaks
5. Notice messages that report not-disposed and not-GCed objects.
   If there aren't any not-GCed leaks, resize the app window
   to trigger GC events, and the following message should show up:
   
```
flutter: 1 memory leaks: not disposed: 1, not GCed: 0, GCed late: 0
flutter: 3 memory leaks: not disposed: 1, not GCed: 2, GCed late: 0
```

5. Click "Analyze and Download"
6. Find two files in the folder "Download": '.yaml' and '.raw.json'.
   Open '.yaml' to review the leaks. You'll only need '.raw.json'
   if you report an issue.

### Detect leaks in your Flutter app

As Flutter widgets are instrumented, you just need to turn on the leak tracking.

Invoke `ensureInitialized` and `startAppLeakTracking` before
`runApp`, as shown in
[the example app,](https://github.com/polina-c/spikes/blob/master/leaking_app/lib/main.dart#L7)
and then follow the steps for the demo app.

### Add instrumentation to your classes <a id='instrument'></a>

The tool needs to know which objects to track and it needs
to know when disposal for these objects happened.

To provide this information for objects of a specific class to the tool,
invoke `startObjectLeakTracking` in the constructor or initializer
(that is invoked only once), and invoke `registerDisposal` in the `dispose` method,
as shown in
[the example app.](https://github.com/polina-c/spikes/blob/master/leaking_app/lib/tracked_class.dart)

To help you troubleshoot the leak, you can pass information
to the optional `details` parameter.

### Troubleshoot the detected leaks

The challenging question when troubleshooting leaks is
how to find the detected leak in the code.
The following tips might help.

#### Give additional details to the tool

It helps to provide the object's details, which you want to be
included into the analysis, to the tool. Be careful doing this,
because storing additional information for each instance of a class
might impact debug/profile performance of the application and therefore
make the user experience different from the released app.

For example, for not-disposed objects, you can
provide the creation call stack to `startObjectLeakTracking`:

```
startObjectLeakTracking(
   this,
   details: StackTrace.current.toString(),
);
```

or, you can provide other details in a separate invocation:

```
addLeakTrackingDetails(this, 'Serves the stream $streamName.');
```
#### Evaluate the leaked objects with DevTools Memory Evaluator

This feature is under construction.

