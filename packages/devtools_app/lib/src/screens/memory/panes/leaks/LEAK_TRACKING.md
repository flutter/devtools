# Memory leaks tracking with Dart DevTools

This page and functionality are under construction. See https://github.com/flutter/devtools/issues/3951.

[self-link](https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/screens/memory/panes/leaks/LEAK_TRACKING.md)

## Understand concepts


## Configure environment

For Google3 applications, follow http://go/detect-memory-leaks-in-g3-flutter-app.

Follow [standard Flutter installation process](https://docs.flutter.dev/get-started/install), but,
instead of downloading or cloning official Flutter, clone `git@github.com:polina-c/flutter.git`,
then chackout the branch `leak-tracking2`
and then never run `flutter upgrade` or `flutter channel`.

## Detect leaks in demo app

TODO: move the example to test/fixtures when it compiles with stable flutter.

1. Run https://github.com/polina-c/spikes/tree/master/leaking_app in debug or profile mode.
2. [Connect](https://docs.flutter.dev/development/tools/devtools/cli#open-devtools-and-connect-to-the-target-app) DevTools to the app 
3. Open Memory > Leaks
4. Notice message that reports not-disposed and not-GCed objects. If there are no not-GCed leaks,
resize the app window, to trigger GC events, and the message should show up:
   
```
flutter: 1 memory leaks: not disposed: 1, not GCed: 0, GCed late: 0
flutter: 3 memory leaks: not disposed: 1, not GCed: 2, GCed late: 0
```

## Detect leaks in your Flutter app



## Add instrumentation to your classes
