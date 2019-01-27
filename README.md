# DevTools
[![Build Status](https://travis-ci.org/flutter/devtools.svg?branch=master)](https://travis-ci.org/flutter/devtools)

Performance tools for Flutter.

## What is this?

This repo is a companion repo to the main [flutter repo](https://github.com/flutter/flutter).
It contains the source code for a suite of Flutter performance tools.

## But there's not much here?

It's still very early in development - stay tuned.

## Development

- `git clone https://github.com/flutter/devtools`
- `cd devtools`
- `pub get`

From a separate terminal:
- `cd <path/to/flutter-sdk>/examples/flutter_gallery`
- ensure the iOS Simulator is open (or a physical device is connected)
- `flutter run`

From the devtools directory:
- `pub run webdev serve web`

Then, open a browser window to the local url specified by webdev. After the page has loaded, append
`?port=xxx` to the url, where xxx is the port number of the service protocol port, as specified by 
the `flutter run` output.

For more productive development, launch your flutter application specifying
`--observatory-port` so the observatory is available on a fixed port. This
lets you avoid manually entering the observatory port parameter each time
you launch the application.

- `flutter run --observatory-port=8888`
- `open http://localhost:8080/?port=8888`

`pub run webdev` provides a fast development server that incrementally
rebuilds the portion of the application that was edited each time you reload
the page in the browser. If initial app load times become slow as this tool
grows, we can integrate with the hot restart support in `webdev`.

## Testing

### Running tests that depend on the Flutter SDK
Make sure your flutter SDK matches the tip of trunk before
running these tests.

```
pub run test --tags useFlutterSdk
```

### Run all other tests

```
pub run test --exclude-tags useFlutterSdk
pub run test --exclude-tags useFlutterSdk --platform chrome-no-sandbox
```

### Updating golden files:
Some of the golden file tests will fail if Flutter changes the implementation or diagnostic
properties of widgets used by the inspector tests. If this happens, make sure the golden
file output still looks reasonable and execute the following command to update the golden files.

```
tool/update_goldens.sh
```

## Deployment

The general deployment strategy for this tool has not yet been finalized.

Currently the application is built using [dartdevc](https://webdev.dartlang.org/tools/dartdevc),
which provides a productive development experience. The application, however, will be deployed
using the Dart2Js compiler, which generates significantly faster JS. Before optimizing slow code,
make sure there is still a performance issue when running the application with Dart2js.
