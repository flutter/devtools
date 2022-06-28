# Memory Leaks Tracking with Dart DevTools

This page and functionality are under construction. See https://github.com/flutter/devtools/issues/3951.

## Concepts

## Detect Leaks in Demo App

1. Run devtools/packages/devtools_app/test/fixtures/leaking_app in debug or profile mode
2. [Connect](https://docs.flutter.dev/development/tools/devtools/cli#open-devtools-and-connect-to-the-target-app) DevTools to the app 
3. Open Memory > Leaks
4. Notice message that reports 1 not disposed and 2 not GCed objects.

## Detect Leaks with Instrumented Flutter

### With GitHub Flutter Branch

### With G3 Flutter CL

See go/detect-leaks-with-instrumented-g3-flutter.

## Detect Leaks with Custom Instrumentation 
