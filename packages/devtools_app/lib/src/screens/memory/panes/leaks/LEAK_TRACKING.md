# Dart DevTools memory leak tracker

This page and functionality are under construction. See https://github.com/flutter/devtools/issues/3951.

[self-link](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/screens/memory/panes/leaks/LEAK_TRACKING.md)


## Understand concepts

### Glossary

**GC**: garbage collection.

**Memory Leak**: progressive usage of more and more memory by an application, for example repetedly creating and not disposing a listener.

**Memory Bloat**: use of more memory than is necessary for optimal performance, for example using too large images or not canceling a stream.

**Object's Retaining Path**: path from the object to a root object that prevents the object from being GCed.


### Leak Types

To detect memory leaks, the tool uses the fact that, with proper memory management, a dart object disposal and GC events should happen sequentially, close to each other.

By disposal and GC events, the tool detects different types of leaks:

**Not disposed, but GCed (not-disposed)**: a disposable object was GCed, without being disposed first. This means that the object's disposable content was allocating memory, after the object became not needed. To fix the leak, invoke `dispose()` when the object is not needed.

**Disposed, but not GCed (not-GCed)**: an object was disposed, but not GCed after certain number of GC events. This means there is a retaining path that holds the object from being garbage collected, after the object became not needed. To fix the leak, after disposal assign to null all reachable references to the object:

```
myField.dispose();
myField = null;
```

**Disposed and GCed late (GCed-late)**: an object was disposed and then GCed, but GC happened later than expected. This means the retaining path was holding the object in memory for some period, but then disappeared.

**Disposed, but not GCed, without path (not-GCed-without-path)**: an object was disposed and not GCed when expected, but retaining path is not detected, that means that the object will be most likely GCed in the next GC cycle, and the leak will convert to **GCed-late** leak. 

### Culprits and Victims

If you have a set of not-GCed objects, some of them (victims) may be not GC-ed because they are held by others (culprits). Normally, to fix the leaks, you need to fix just culprits.

**Victim**: a leaked object, for which the tool could find another leaked object, that, if fixed, would fix the first leak too.

**Culprit**: a leaked object that is not detected to be the victim of another object.

The tool detects which leaked objects are culprits, so you know where to focus.

For example, out of four not-GCed leaks on this diagram, only one is the culprit, because, when the object is fixed and gets GCed, the victims it referenced, will be also GCed:


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

The tool detects leaks for disposable and instrumented classes only (with note that the fixed leak can fix other objects too). 

Some classes in Flutter framework are already instrumented. If you want your classes to be tracked, you need to make them disposable and [instrument them](#instrument).

## Use the Leak Tracker

### Configure environment

NOTE: For Google3 applications, follow http://go/detect-memory-leaks-in-g3-flutter-app.

While the leak detection functionality is under construction, you will need the forked version of the Flutter framework.

Follow [standard Flutter installation process](https://docs.flutter.dev/get-started/install), but,
instead of downloading or cloning official Flutter, clone `git@github.com:polina-c/flutter.git`,
then checkout the branch `leak-tracking2`
and then never run `flutter upgrade` or `flutter channel`.

### Detect leaks in demo Flutter app <a id='demo_flutter'></a>

TODO: move the example to test/fixtures when it compiles with stable flutter.

1. Run https://github.com/polina-c/spikes/tree/master/leaking_app in profile or debug mode.
2. [Connect](https://docs.flutter.dev/development/tools/devtools/cli#open-devtools-and-connect-to-the-target-app) DevTools to the app 
3. Open Memory > Leaks <a id='memory-leaks-page'></a>
4. Notice message that reports not-disposed and not-GCed objects. If there are no not-GCed leaks,
resize the app window, to trigger GC events, and the message should show up:
   
```
flutter: 1 memory leaks: not disposed: 1, not GCed: 0, GCed late: 0
flutter: 3 memory leaks: not disposed: 1, not GCed: 2, GCed late: 0
```

5. Click "Analyze and Download"
6. Find two files in the folder "Download": '.yaml' and '.raw.json'. Open '.yaml' to review the leaks. You will need '.raw.json' 
if only you want to report an issue.

### Detect leaks in your Flutter app

As Flutter widgets are instrumented, you just need to turn on the leak tracking.

Invoke `ensureInitialized` and `startAppLeakTracking` before `runApp` like [the example app does](https://github.com/polina-c/spikes/blob/master/leaking_app/lib/main.dart#L7) and then follow the steps for demo app.

### Add instrumentation to your classes <a id='instrument'></a>

The tool needs to know which objects to track and it needs to know when disposal for these objects happened.

To provide this information for objects of a certain class to the tool, invoke `startObjectLeakTracking` in constructor or initializer (that is invoked only once), and invoke `registerDisposal` in the method `dispose`
like [the example app does](https://github.com/polina-c/spikes/blob/master/leaking_app/lib/tracked_class.dart).

You can pass information, that will help you troubleshoot the leak, to the optional parameter `details`.

TODO(polina-c): explain how to choose which classes to instrument.

### Detect leaks in your Dart app

For Dart appliocations: 

1. Reference [memory_leak_tracker](https://github.com/polina-c/spikes/blob/master/memory_leak_tracker/README.md) in your pubspec.yaml:

TODO(polina-c): productize the library `memory_leak_tracker`.

```
dependencies:
  ...
  memory_leak_tracker:
    git:
      url: git://github.com/polina-c/spikes.git
      path: memory_leak_tracker
```

2. [Instrument](#instrument) your classes.

3. Run your app with additional flags: `dart --observe:8181 main.dart`, find the line `The Dart VM service is listening on` in console and copy URL like `http://127.0.0.1:8181/etNluJDHZwE=/`.

4. Start [DevTools](https://github.com/flutter/devtools) at master: `flutter run -d macos` and connect to the app with the copyed URL. 
 
TODO(polina-c): update this step to use released version. 

5. Follow [the guidance for the demo Flutter app](demo_flutter), starting at [the step to open the memory screen](memory-leaks-page).


### Troubleshoot the detected leaks

The challenging question of the leak troubleshooting is how to find the detected leak in the code. Here are some tips that may help.

#### Give additional details to the tool

It helps to provide the object's details, which you want to be included into the analysis, to the tool. Be careful doing this, because storing additional information for each instance of a class may impact the performance of the application (if leak tracking is enabled).

For example, for not disposed objects, you can provide creation call stack to `startObjectLeakTracking`:

```
startObjectLeakTracking(
   this,
   details: StackTrace.current.toString(),
);
```

or, provide some other details in a separate invocation:

```
addLeakTrackingDetails(this, 'Serves the stream $streamName.');
```
#### Evaluate the leaked objects with DevTools Memory Evaluator

TODO(polina-c): add content

### Detect leaks in regression testing

TODO(polina-c): add content

### Understand performance impact

TODO(polina-c): add content
